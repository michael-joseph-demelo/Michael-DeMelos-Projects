"""
ai.py - Sends your project and questions to Claude, and hands back the answers.

The key idea: the AI has no access to your computer and no memory between
requests. It only knows what we put in each request:
  1. Instructions   - who the AI is and how it should answer (the "system prompt")
  2. Your project   - every .gd script, your design docs, and a list of other files
  3. Tools          - descriptions of tools it may ask us to run (see tools.py)
  4. The conversation so far - every earlier question and answer, plus the new question

Part 4 is how "chat" works: the AI seems to remember earlier questions only
because we resend the whole conversation every time.
"""

from collections.abc import Iterator
from pathlib import Path

import anthropic

from assistant.planner import build_plan_prompt, save_plan
from assistant.scanner import Project
from assistant.tools import TOOLS, describe_tool_call, run_tool
from assistant.transcript import Transcript

MODEL = "claude-opus-5-5"

# Safety limit: the most rounds of tool use for one question, so a confused
# AI can't loop forever. After this it must answer with what it has.
MAX_TOOL_ROUNDS = 10

# Prices in US dollars per 1 million tokens, used to estimate what a question costs.
# A token is roughly 3-4 characters of text (code tends to use more tokens per character).
PRICE_INPUT = 4.00
PRICE_CACHE_WRITE = 5.00   # first time something is stored in the cache (1.25x input)
PRICE_CACHE_READ = 0.20    # later requests that reuse the cached part (much cheaper)
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
    """Turn a technical API error into a plain-English message."""
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
    """Everything about the project the AI gets up front, as one block of labeled text."""
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
    """
    One conversation with the AI about your project.

    It keeps a list of every message so far. Each new question is sent along
    with that whole list, which is what lets you ask follow-up questions.
    """

    def __init__(self, project: Project, transcript: Transcript | None = None):
        # Anthropic() finds your API key automatically in the ANTHROPIC_API_KEY variable.
        self.client = anthropic.Anthropic()
        self.project = project
        self.system = [
            {"type": "text", "text": SYSTEM_INSTRUCTIONS},
            {
                "type": "text",
                "text": build_project_text(project),
                # Cache the project so it doesn't cost full price on every request.
                "cache_control": {"type": "ephemeral"},
            },
        ]
        self.transcript = transcript  # Where to save the chat (None = don't save)
        self.messages = []            # The conversation history: alternating user / assistant
        self.total_cost = 0.0         # Running cost estimate for this session
        self.last_usage = ""          # Token/cost summary of the most recent answer
        self.last_plan_path: Path | None = None  # Where the most recent plan was saved

    # ---------- The two things you can do: ask a question, or plan a feature ----------

    def ask(self, question: str) -> Iterator[str]:
        """
        Send a question and hand back the answer piece by piece as it arrives.

        This is a "generator": instead of returning one finished value, it
        `yield`s many small ones. The caller decides what to do with each piece,
        so the terminal can print them and the web page can display them.
        """
        answer = yield from self._run_turn(question, effort="medium", max_tokens=16000)
        if self.transcript and answer:
            self.transcript.add(question, answer)

    def plan(self, feature: str) -> Iterator[str]:
        """Write an implementation plan for a feature, and save it to the plans folder."""
        # Planning is harder than answering, so the AI is told to think harder ("high" effort).
        answer = yield from self._run_turn(build_plan_prompt(feature), effort="high", max_tokens=32000)
        if answer:
            self.last_plan_path = save_plan(feature, answer, self.project.name)
            if self.transcript:
                self.transcript.add(f"Plan: {feature}", answer)

    # ---------- How a turn works: the tool-use loop ----------

    def _run_turn(self, prompt: str, effort: str, max_tokens: int) -> Iterator[str]:
        """
        Send one user message, then keep going until the AI gives a final answer:
          ask -> (AI requests a tool -> we run it -> send the result back) x N -> answer
        Returns the answer text once finished.
        """
        # This turn's new messages. They're only added to the real history at the
        # end, so a failure partway through leaves the conversation clean.
        turn = [{"role": "user", "content": prompt}]
        answer_parts: list[str] = []
        usages = []

        for round_number in range(MAX_TOOL_ROUNDS + 1):
            # On the last round, tools are switched off so the AI has to answer.
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
                    # A half-finished tool request can't be kept in the history
                    # (every request needs a result), so drop this turn entirely.
                    yield "\n[This exchange wasn't added to the conversation; try asking again.]"
                    self._record_usage(usages)
                    return ""
                break

            if not tool_requests:
                break  # No tools requested: this is the final answer.

            # The AI asked for tools. Run each one and send all results back together.
            results = []
            for block in tool_requests:
                spacing = "\n\n" if answer_parts else ""
                yield f"{spacing}_({describe_tool_call(block)})_\n\n"
                results.append(run_tool(block, self.project))
            turn.append({"role": "user", "content": results})
            if answer_parts:
                answer_parts.append("\n\n")  # keep text from before and after the tools apart

        # Finished: save the whole turn (question, tool calls, results, answer) to the history.
        # We store the AI's full response content, not just its text, because the API
        # expects its tool requests and hidden reasoning blocks back unchanged.
        self.messages.extend(turn)
        self._record_usage(usages)
        return "".join(answer_parts)

    def _stream_response(self, turn, effort, max_tokens, tools_allowed, answer_parts) -> Iterator[str]:
        """Make one request, yielding the answer text as it streams in. Returns the full response."""
        for attempt in range(3):
            parts_before = len(answer_parts)
            try:
                with self.client.beta.messages.stream(
                    model=MODEL,
                    max_tokens=max_tokens,  # upper limit on the answer's length
                    # "effort" controls how hard the model thinks before answering.
                    # Options: low, medium, high, xhigh, max. Higher = slower and pricier.
                    output_config={"effort": effort},
                    # If the model's safety filter wrongly declines a question, retry it on
                    # another model automatically instead of returning nothing.
                    betas=["server-side-fallback-2026-07-01"],
                    fallbacks="default",
                    system=self.system,
                    tools=TOOLS,
                    # "auto" = the AI decides whether to use a tool. "none" = it can't.
                    tool_choice={"type": "auto" if tools_allowed else "none"},
                    messages=self.messages + turn,
                    # Also cache the conversation so far, so long chats stay cheap.
                    cache_control={"type": "ephemeral"},
                ) as stream:
                    for text in stream.text_stream:
                        answer_parts.append(text)
                        yield text
                    return stream.get_final_message()
            except ValueError:
                # Rare: the AI's tool request arrived garbled and couldn't be read.
                # Throw away this attempt's partial text and ask again.
                del answer_parts[parts_before:]
                if attempt == 2:
                    raise
                yield "\n\n_(retrying...)_\n\n"

    def _record_usage(self, usages) -> None:
        """Add up the tokens used across every request in this turn, and estimate the cost."""
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
