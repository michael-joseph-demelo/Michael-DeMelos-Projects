"""
Local, case-insensitive text search across the project, with GDScript function attribution.

Used directly by the CLI/web UI (no API cost) and as the model's search_project tool.
"""

import re
from dataclasses import dataclass

from assistant.scanner import Project, TextFile, read_text_file

FUNC_PATTERN = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)")


@dataclass
class SearchMatch:
    file: str
    line_number: int  # 1-based, matching the Godot editor
    line: str
    function: str | None  # enclosing function for .gd files, else None


def search_files(files: list[TextFile], query: str) -> list[SearchMatch]:
    query = query.lower()
    matches = []

    for file in files:
        is_script = file.relative_path.endswith(".gd")
        current_function = None
        for number, line in enumerate(file.content.splitlines(), start=1):
            if is_script:
                func = FUNC_PATTERN.match(line)
                if func:
                    current_function = func.group(1)
                elif line.strip() and not line[0].isspace() and not line.startswith("#"):
                    # GDScript bodies are indented, so non-comment code at column 0 ends the function.
                    current_function = None

            if query in line.lower():
                matches.append(SearchMatch(file.relative_path, number, line.strip(), current_function))

    return matches


def search_project(project: Project, query: str) -> list[SearchMatch]:
    """Search scripts, other text files (read fresh from disk) and design docs."""
    others = [read_text_file(project.root / path, project.root) for path in project.other_files]
    return search_files(project.scripts + others + project.design_docs, query)


def format_matches(matches: list[SearchMatch], limit: int | None = None) -> str:
    """Format matches grouped by file, optionally truncated to `limit` with a note."""
    if not matches:
        return "No matches."

    shown = matches[:limit] if limit else matches
    lines = []
    current_file = None
    for match in shown:
        if match.file != current_file:
            current_file = match.file
            lines.append(f"\n{match.file}")
        if match.file.endswith(".gd"):
            where = f"[{match.function}]" if match.function else "[top of file]"
            lines.append(f"  {match.line_number:>5}  {where:<28} {match.line}")
        else:
            lines.append(f"  {match.line_number:>5}  {match.line}")

    files = len({m.file for m in matches})
    summary = f"\n{len(matches)} matches in {files} files."
    if len(shown) < len(matches):
        summary += f" Showing the first {len(shown)}; search for something more specific to narrow it down."
    lines.append(summary)
    return "\n".join(lines)
