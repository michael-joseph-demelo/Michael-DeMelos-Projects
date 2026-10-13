"""
Claude client: builds each request and runs the agentic tool-use loop.

Every request is assembled from four parts:
  1. System instructions (role and answering rules)
  2. The project context: design docs, the other-file index, and every .gd script.
     This block is prompt-cached, so follow-up questions reuse it at ~5% of the input price.
  3. Tool definitions (see tools.py)
  4. The conversation history plus the new user turn
"""

from collections.abc import Iterator
from pathlib import Path

import anthropic

from assistant.planner import build_plan_prompt, save_plan
from assistant.scanner import Project
from assistant.tools import TOOLS, describe_tool_call, run_tool
from assistant.transcript import Transcript

MODEL = "claude-opus-5-5"

# Upper bound on tool rounds per turn. The final round disables tools so the model must answer.
MAX_TOOL_ROUNDS = 10

# USD per million tokens, for the per-answer cost estimate.
PRICE_INPUT = 4.00
PRICE_CACHE_WRITE = 5.00  # 1.25x input
PRICE_CACHE_READ = 0.20
PRICE_OUTPUT = 20.00

SYSTEM_INSTRUCTIONS = """\
You are a game development assistant for a Godot 4 project written in GDScript.
Below you'll find the developer's design docs (if any), a list of the project's other
files, and the full source of every .gd script. Answer the developer's questions about
how the game currently works, and help them plan changes.

- Base your answers on the project itself. Point to specific files and functions
  (for example `fists/FistBase.gd` -> `punch()`), and quote short snippets when it helps.
- The scripts are already here in full. When an answer depends on scene setup, Inspector
  values, signal connections made in the editor, the Input Map, or data files, use your
  tools to check instead of guessing. If you still can't tell, say so.
- The design docs describe how the developer INTENDS the game to work; the code shows how
  it ACTUALLY works. When they disagree, point it out. When planning, follow the design
  docs unless the developer says otherwise.
- When asked about adding or changing a mechanic, list the files and functions to
  modify, and what else could be affected: shared variables, signals, subclasses
  that inherit from a base script, and timers or states that interact with it.
"""


def describe_api_error(error: anthropic.APIError) -> str:
    """Map an API error to an actionable message for the user."""
    if isinstance(error, anthropic.AuthenticationError):
        return "The API key was rejected. Check the key in your .env file."
    if isinstance(error, anthropic.RateLimitError):
        return "Too many requests, or your account is out of credits. Wait a moment or check your billing."
    if isinstance(error, anthropic.APIConnectionError):
        return "Couldn't reach the AI service. Check your internet connection."
    if isinstance(error, anthropic.APIStatusError):
        return f"Error from the AI service ({error.status_code}): {error.message}"
    return f"Unexpected error from the AI service: {error}"


def build_project_text(project: Project) -> str:
    """Render the project context as XML-tagged sections for the system prompt."""
    parts = []

    if project.design_docs:
        docs = "\n\n".join(f'<doc path="{d.relative_path}">\n{d.content}\n</doc>' for d in project.design_docs)
        parts.append(f"<design_docs>\n{docs}\n</design_docs>")
    else:
        parts.append("<design_docs>The developer hasn't written any design docs yet.</design_docs>")

    file_list = "\n".join(project.other_files) or "(none)"
    parts.append(f"<other_files>\nOther text files you can open with read_file:\n{file_list}\n</other_files>")

    scripts = "\n\n".join(f'<file path="{s.relative_path}">\n{s.content}\n</file>' for s in project.scripts)
    parts.append(f"<codebase>\n{scripts}\n</codebase>")

    return "\n\n".join(parts)


class GameAssistant:
    """A multi-turn conversation about one project. Callers consume answers as text streams."""

    def __init__(self, project: Project, transcript: Transcript | None = None):
        self.client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY
        self.project = project
        self.system = [
            {"type": "text", "text": SYSTEM_INSTRUCTIONS},
            {
                "type": "text",
                "text": build_project_text(project),
                "cache_control": {"type": "ephemeral"},
            },
        ]
        self.transcript = transcript
        self.messages = []
        self.total_cost = 0.0
        self.last_usage = ""  # token/cost summary of the most recent turn
        self.last_plan_path: Path | None = None

    def ask(self, question: str) -> Iterator[str]:
        """Answer a question, yielding text as it streams in."""
        answer = yield from self._run_turn(question, effort="medium", max_tokens=16000)
        if self.transcript and answer:
            self.transcript.add(question, answer)

    def plan(self, feature: str) -> Iterator[str]:
        """Write an implementation plan for a feature and save it to plans/."""
        answer = yield from self._run_turn(build_plan_prompt(feature), effort="high", max_tokens=32000)
        if answer:
            self.last_plan_path = save_plan(feature, answer, self.project.name)
            if self.transcript:
                self.transcript.add(f"Plan: {feature}", answer)

    def _run_turn(self, prompt: str, effort: str, max_tokens: int) -> Iterator[str]:
        """
        Run one user turn through the tool loop and return the final answer text:
            request -> (tool_use -> run tools -> tool_result) x N -> final answer
        """
        # Buffer the turn and commit it to history only on success, so an error or an
        # unanswerable tool_use mid-turn never leaves the history in an invalid state.
        turn = [{"role": "user", "content": prompt}]
        answer_parts: list[str] = []
        usages = []

        for round_number in range(MAX_TOOL_ROUNDS + 1):
            tools_allowed = round_number < MAX_TOOL_ROUNDS
            response = yield from self._stream_response(turn, effort, max_tokens, tools_allowed, answer_parts)
            usages.append(response.usage)
            turn.append({"role": "assistant", "content": response.content})

            tool_requests = [block for block in response.content if block.type == "tool_use"]

            if response.stop_reason in ("max_tokens", "refusal"):
                if response.stop_reason == "max_tokens":
                    yield "\n\n[The answer was cut off because it hit the max_tokens limit.]"
                else:
                    yield "\n\n[The model declined to answer this question.]"
                if tool_requests:
                    # Every tool_use needs a matching tool_result, so a truncated one can't be kept.
                    yield "\n[This exchange wasn't added to the conversation; try asking again.]"
                    self._record_usage(usages)
                    return ""
                break

            if not tool_requests:
                break

            # All results for one response go back together in a single user message.
            results = []
            for block in tool_requests:
                spacing = "\n\n" if answer_parts else ""
                yield f"{spacing}_({describe_tool_call(block)})_\n\n"
                results.append(run_tool(block, self.project))
            turn.append({"role": "user", "content": results})
            if answer_parts:
                answer_parts.append("\n\n")

        # Store full content blocks, not just text: the API requires tool_use and
        # thinking blocks to be sent back unchanged on later requests.
        self.messages.extend(turn)
        self._record_usage(usages)
        return "".join(answer_parts)

    def _stream_response(self, turn, effort, max_tokens, tools_allowed, answer_parts) -> Iterator[str]:
        """Make one streaming request, yielding text deltas. Returns the final message."""
        for attempt in range(3):
            parts_before = len(answer_parts)
            try:
                with self.client.beta.messages.stream(
                    model=MODEL,
                    max_tokens=max_tokens,
                    output_config={"effort": effort},
                    # Retry on a fallback model if the primary model refuses.
                    betas=["server-side-fallback-2026-07-01"],
                    fallbacks="default",
                    system=self.system,
                    tools=TOOLS,
                    tool_choice={"type": "auto" if tools_allowed else "none"},
                    messages=self.messages + turn,
                    cache_control={"type": "ephemeral"},  # also cache the growing conversation
                ) as stream:
                    for text in stream.text_stream:
                        answer_parts.append(text)
                        yield text
                    return stream.get_final_message()
            except ValueError:
                # The SDK raises ValueError when streamed tool input isn't valid JSON.
                # Discard this attempt's partial text and retry.
                del answer_parts[parts_before:]
                if attempt == 2:
                    raise
                yield "\n\n_(retrying...)_\n\n"

    def _record_usage(self, usages) -> None:
        """Sum token usage across the turn's requests and update the cost estimate."""
        input_tokens = sum(u.input_tokens for u in usages)
        cache_write = sum(u.cache_creation_input_tokens or 0 for u in usages)
        cache_read = sum(u.cache_read_input_tokens or 0 for u in usages)
        output_tokens = sum(u.output_tokens for u in usages)
        cost = (
            input_tokens * PRICE_INPUT
            + cache_write * PRICE_CACHE_WRITE
            + cache_read * PRICE_CACHE_READ
            + output_tokens * PRICE_OUTPUT
        ) / 1_000_000
        self.total_cost += cost

        requests = f"{len(usages)} requests" if len(usages) > 1 else "1 request"
        self.last_usage = (
            f"{requests} | tokens: {input_tokens} input, {cache_write} cache write, "
            f"{cache_read} cache read, {output_tokens} output "
            f"| this answer: ${cost:.4f} | session total: ${self.total_cost:.4f}"
        )
