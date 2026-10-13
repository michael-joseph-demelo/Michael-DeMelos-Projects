from types import SimpleNamespace

import pytest

from assistant.tools import TOOLS, describe_tool_call, run_tool


def tool_use(name: str, tool_input, id: str = "toolu_1"):
    return SimpleNamespace(type="tool_use", id=id, name=name, input=tool_input)


def test_tool_schemas_are_well_formed():
    for tool in TOOLS:
        assert tool["description"]
        schema = tool["input_schema"]
        assert set(schema["required"]) <= set(schema["properties"])


def test_search_project_tool(project):
    result = run_tool(tool_use("search_project", {"query": "  stamina "}), project)
    assert result["tool_use_id"] == "toolu_1"
    assert "is_error" not in result
    assert "player/player.gd" in result["content"]


def test_read_file_tool(project):
    result = run_tool(tool_use("read_file", {"path": "data/stats.json"}), project)
    assert result["content"] == '{"stamina": 100}'


@pytest.mark.parametrize(
    ("name", "tool_input", "error"),
    [
        ("search_project", {}, "non-empty 'query'"),
        ("search_project", {"query": "   "}, "non-empty 'query'"),
        ("read_file", {"path": 42}, "non-empty 'path'"),
        ("read_file", "not a dict", "non-empty 'path'"),
        ("read_file", {"path": "../../etc/passwd"}, "outside the project"),
        ("delete_everything", {}, "Unknown tool"),
    ],
)
def test_bad_input_returns_error_result(project, name, tool_input, error):
    result = run_tool(tool_use(name, tool_input), project)
    assert result["is_error"] is True
    assert error in result["content"]


def test_describe_tool_call():
    assert describe_tool_call(tool_use("read_file", {"path": "project.godot"})) == "reading project.godot"
    assert describe_tool_call(tool_use("search_project", {"query": "hp"})) == 'searching the project for "hp"'
    assert describe_tool_call(tool_use("other", None)) == "using other"
