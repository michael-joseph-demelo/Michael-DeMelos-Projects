"""Tests for the tool-use loop, using a scripted fake in place of the Anthropic client."""

from types import SimpleNamespace

import pytest

from assistant import ai, planner
from assistant.ai import MAX_TOOL_ROUNDS, GameAssistant, build_project_text


def usage(input_tokens=100, cache_write=0, cache_read=0, output_tokens=10):
    return SimpleNamespace(
        input_tokens=input_tokens,
        cache_creation_input_tokens=cache_write,
        cache_read_input_tokens=cache_read,
        output_tokens=output_tokens,
    )


def text_response(text, stop_reason="end_turn"):
    return SimpleNamespace(content=[SimpleNamespace(type="text", text=text)], stop_reason=stop_reason, usage=usage())


def tool_response(name, tool_input, id="toolu_1", text="", stop_reason="tool_use"):
    blocks = [SimpleNamespace(type="text", text=text)] if text else []
    blocks.append(SimpleNamespace(type="tool_use", id=id, name=name, input=tool_input))
    return SimpleNamespace(content=blocks, stop_reason=stop_reason, usage=usage())


class FakeStream:
    def __init__(self, response):
        self.response = response

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    @property
    def text_stream(self):
        for block in self.response.content:
            if block.type == "text" and block.text:
                yield block.text

    def get_final_message(self):
        return self.response


class FakeClient:
    """Returns scripted responses in order and records every request's arguments."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []
        self.beta = SimpleNamespace(messages=SimpleNamespace(stream=self._stream))

    def _stream(self, **kwargs):
        # Snapshot messages: the real list keeps growing after the call.
        self.calls.append({**kwargs, "messages": list(kwargs["messages"])})
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return FakeStream(response)


@pytest.fixture
def make_assistant(project, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")

    def make(responses):
        assistant = GameAssistant(project)
        assistant.client = FakeClient(responses)
        return assistant

    return make


def run(generator):
    return "".join(generator)


def test_project_text_contains_docs_files_and_scripts(project):
    text = build_project_text(project)
    assert '<doc path="docs/combat.md">' in text
    assert "player/player.tscn" in text
    assert '<file path="player/player.gd">' in text


def test_system_prompt_caches_project_block(make_assistant):
    assistant = make_assistant([])
    assert assistant.system[-1]["cache_control"] == {"type": "ephemeral"}


def test_plain_answer(make_assistant):
    assistant = make_assistant([text_response("Stamina is in punch().")])
    assert run(assistant.ask("Where is stamina used?")) == "Stamina is in punch()."
    assert [m["role"] for m in assistant.messages] == ["user", "assistant"]
    assert assistant.client.calls[0]["tool_choice"] == {"type": "auto"}
    assert assistant.total_cost > 0
    assert "1 request" in assistant.last_usage


def test_tool_round_trip(make_assistant):
    assistant = make_assistant(
        [
            tool_response("read_file", {"path": "project.godot"}, text="Let me check."),
            text_response("punch_left is in the Input Map."),
        ]
    )
    output = run(assistant.ask("What inputs exist?"))

    assert "_(reading project.godot)_" in output
    assert output.endswith("punch_left is in the Input Map.")

    # The second request carries the tool result back to the model.
    tool_result = assistant.client.calls[1]["messages"][-1]["content"][0]
    assert tool_result["tool_use_id"] == "toolu_1"
    assert "punch_left" in tool_result["content"]

    assert [m["role"] for m in assistant.messages] == ["user", "assistant", "user", "assistant"]
    assert "2 requests" in assistant.last_usage


def test_history_is_resent_on_follow_up(make_assistant):
    assistant = make_assistant([text_response("A1"), text_response("A2")])
    run(assistant.ask("Q1"))
    run(assistant.ask("Q2"))
    contents = [m["content"] for m in assistant.client.calls[1]["messages"]]
    assert contents[0] == "Q1" and contents[-1] == "Q2"


def test_tools_disabled_on_final_round(make_assistant):
    responses = [tool_response("search_project", {"query": "hp"}, id=f"t{i}") for i in range(MAX_TOOL_ROUNDS)]
    assistant = make_assistant([*responses, text_response("Best guess.")])
    output = run(assistant.ask("Loop forever"))

    calls = assistant.client.calls
    assert len(calls) == MAX_TOOL_ROUNDS + 1
    assert all(c["tool_choice"] == {"type": "auto"} for c in calls[:-1])
    assert calls[-1]["tool_choice"] == {"type": "none"}
    assert output.endswith("Best guess.")


def test_truncated_tool_call_is_not_committed(make_assistant):
    assistant = make_assistant([tool_response("read_file", {"path": "x"}, stop_reason="max_tokens")])
    output = run(assistant.ask("Q"))
    assert "max_tokens" in output
    assert "wasn't added to the conversation" in output
    assert assistant.messages == []
    assert assistant.total_cost > 0  # tokens were still spent


def test_api_failure_mid_turn_leaves_history_clean(make_assistant):
    assistant = make_assistant(
        [
            tool_response("read_file", {"path": "project.godot"}),
            RuntimeError("connection dropped"),
        ]
    )
    with pytest.raises(RuntimeError):
        run(assistant.ask("Q"))
    assert assistant.messages == []


def test_garbled_tool_input_is_retried(make_assistant):
    assistant = make_assistant([ValueError("bad json"), text_response("Recovered.")])
    output = run(assistant.ask("Q"))
    assert "retrying" in output
    assert output.endswith("Recovered.")


def test_plan_uses_high_effort_and_saves(make_assistant, tmp_path, monkeypatch):
    monkeypatch.setattr(planner, "PLANS_FOLDER", tmp_path)
    assistant = make_assistant([text_response("## Summary\nA dash.")])
    run(assistant.plan("Add a dash"))

    call = assistant.client.calls[0]
    assert call["output_config"] == {"effort": "high"}
    assert "<feature>\nAdd a dash\n</feature>" in call["messages"][0]["content"]
    assert assistant.last_plan_path.parent == tmp_path
    assert "A dash." in assistant.last_plan_path.read_text(encoding="utf-8")


def test_cost_estimate(make_assistant):
    assistant = make_assistant([])
    assistant._record_usage([usage(input_tokens=1_000_000, cache_read=1_000_000, output_tokens=1_000_000)])
    assert assistant.total_cost == pytest.approx(ai.PRICE_INPUT + ai.PRICE_CACHE_READ + ai.PRICE_OUTPUT)
