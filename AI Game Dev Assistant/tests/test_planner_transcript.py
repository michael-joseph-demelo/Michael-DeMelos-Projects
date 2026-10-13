import pytest

from assistant import planner, transcript
from assistant.planner import build_plan_prompt, save_plan, slugify
from assistant.transcript import Transcript


@pytest.mark.parametrize(
    ("text", "slug"),
    [
        ("Add a heavy punch!", "add-a-heavy-punch"),
        ("  --Grab & Throw--  ", "grab-throw"),
        ("???", "plan"),
        ("word " * 20, ("word-" * 10).rstrip("-")),
    ],
)
def test_slugify(text, slug):
    assert slugify(text) == slug


def test_plan_prompt_embeds_feature():
    prompt = build_plan_prompt("Add a dash")
    assert "<feature>\nAdd a dash\n</feature>" in prompt
    assert "## Risks" in prompt


def test_save_plan(tmp_path, monkeypatch):
    monkeypatch.setattr(planner, "PLANS_FOLDER", tmp_path / "plans")
    path = save_plan("Add a dash", "## Summary\nDash.", "my-game")
    assert path.parent == tmp_path / "plans"
    assert path.name.endswith("_add-a-dash.md")
    text = path.read_text(encoding="utf-8")
    assert text.startswith("# Plan: Add a dash\n\n_my-game, ")
    assert "## Summary\nDash." in text


def test_transcript_created_lazily_and_appends(tmp_path, monkeypatch):
    monkeypatch.setattr(transcript, "CHATS_FOLDER", tmp_path / "chats")
    t = Transcript("my-game")
    assert t.path.parent == tmp_path / "chats"
    assert not t.path.exists()

    t.add("Q1", "A1")
    t.add("Q2", "A2")
    text = t.path.read_text(encoding="utf-8")
    assert text.startswith("# Chat about my-game")
    assert text.index("Q1") < text.index("A1") < text.index("Q2") < text.index("A2")
