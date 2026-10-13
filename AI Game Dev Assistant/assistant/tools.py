"""
tools.py - Tools the AI can use to look things up in your project by itself.

How tool use works:
  1. We send the AI a description of each tool (TOOLS below) with every request.
  2. If the AI decides it needs one, instead of answering it replies with a
     "tool_use" request, e.g.  read_file(path="project.godot").
  3. OUR code runs the tool (run_tool below) and sends the result back.
  4. The AI reads the result and either asks for another tool or answers.

The AI never runs anything itself. It can only ask, and our code decides
what actually happens. That's why these tools are read-only and limited
to your project folder.
"""

from anthropic.types.beta import BetaToolUseBlock

from assistant.scanner import Project, read_project_file
from assistant.search import format_matches, search_project

# The most search results to send back at once (keeps answers fast and cheap).
MAX_SEARCH_RESULTS = 80

# What the AI sees. The descriptions matter a lot: the AI reads them to
# decide WHEN to use each tool, so they say when, not just what.
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
        # Stream the tool request as it's written (our code checks it before running).
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
                    "description": "Path relative to the project folder, e.g. 'fists/FistStats.json' or 'project.godot'",
                },
            },
            "required": ["path"],
        },
        "eager_input_streaming": True,
    },
]


def describe_tool_call(block: BetaToolUseBlock) -> str:
    """A short human-readable line saying what the AI is doing, e.g. 'reading project.godot'."""
    args = block.input if isinstance(block.input, dict) else {}
    if block.name == "search_project":
        return f'searching the project for "{args.get("query", "?")}"'
    if block.name == "read_file":
        return f"reading {args.get('path', '?')}"
    return f"using {block.name}"


def run_tool(block: BetaToolUseBlock, project: Project) -> dict:
    """Run the tool the AI asked for, and package the result to send back."""
    args = block.input if isinstance(block.input, dict) else {}
    try:
        if block.name == "search_project":
            query = args.get("query")
            # The AI's input is checked before use, like any input from outside our program.
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
        # Tell the AI what went wrong ("is_error") so it can try something else.
        return {"type": "tool_result", "tool_use_id": block.id, "content": str(e), "is_error": True}

    # tool_use_id links this result to the AI's request.
    return {"type": "tool_result", "tool_use_id": block.id, "content": result}
