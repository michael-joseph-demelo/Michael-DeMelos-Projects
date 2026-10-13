"""
Tool definitions exposed to the model, and their execution.

Both tools are read-only and scoped to the project folder. Model-supplied arguments
are validated before use; failures are returned as is_error tool results so the
model can correct itself instead of the turn crashing.
"""

from anthropic.types.beta import BetaToolUseBlock

from assistant.scanner import Project, read_project_file
from assistant.search import format_matches, search_project

MAX_SEARCH_RESULTS = 80

# Descriptions say *when* to use each tool, since that's what drives the model's choice.
TOOLS = [
    {
        "name": "search_project",
        "description": (
            "Search every text file in the Godot project (scripts, .tscn scenes, .tres resources, "
            "project.godot, .json data, design docs) for a word or phrase, ignoring case. Returns each "
            "matching line with its file and line number, and for scripts the function it's in. "
            "Use this to find where a node, signal, input action, group, or variable is referenced "
            "outside the scripts, e.g. which scene connects a signal or sets an exported value."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The word or phrase to find, e.g. 'stamina'"},
            },
            "required": ["query"],
        },
        "eager_input_streaming": True,
    },
    {
        "name": "read_file",
        "description": (
            "Read one text file from the Godot project. Use this whenever an answer depends on "
            "something the scripts alone don't show: scene setup in .tscn files (node tree, values "
            "set in the Inspector, signal connections, collision layers/masks), project.godot "
            "(Input Map actions, autoloads, physics layer names), or .json data files. "
            "The .gd scripts are already in your context in full, so don't read those."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": (
                        "Path relative to the project folder, e.g. 'fists/FistStats.json' or 'project.godot'"
                    ),
                },
            },
            "required": ["path"],
        },
        "eager_input_streaming": True,
    },
]


def describe_tool_call(block: BetaToolUseBlock) -> str:
    """Short status line shown to the user while a tool runs, e.g. 'reading project.godot'."""
    args = block.input if isinstance(block.input, dict) else {}
    if block.name == "search_project":
        return f'searching the project for "{args.get("query", "?")}"'
    if block.name == "read_file":
        return f"reading {args.get('path', '?')}"
    return f"using {block.name}"


def run_tool(block: BetaToolUseBlock, project: Project) -> dict:
    """Execute a tool_use block and return the matching tool_result content block."""
    args = block.input if isinstance(block.input, dict) else {}
    try:
        if block.name == "search_project":
            query = args.get("query")
            if not isinstance(query, str) or not query.strip():
                raise ValueError("search_project needs a non-empty 'query' string.")
            result = format_matches(search_project(project, query.strip()), limit=MAX_SEARCH_RESULTS)
        elif block.name == "read_file":
            path = args.get("path")
            if not isinstance(path, str) or not path.strip():
                raise ValueError("read_file needs a non-empty 'path' string.")
            result = read_project_file(project, path.strip())
        else:
            raise ValueError(f"Unknown tool: {block.name}")
    except ValueError as e:
        return {"type": "tool_result", "tool_use_id": block.id, "content": str(e), "is_error": True}

    return {"type": "tool_result", "tool_use_id": block.id, "content": result}
