"""
search.py - Finds every line in your project that mentions a word.

This runs entirely on your computer: no AI, no cost, instant results.
It's like Ctrl+F across all your scripts, scenes and settings at once, and
for scripts it also tells you which function each match is inside.

The AI uses this exact same function as one of its tools (see tools.py),
so it can look things up by itself.
"""

import re
from dataclasses import dataclass

from assistant.scanner import Project, TextFile, read_text_file

# Matches the start of a GDScript function, e.g. "func punch(target):" or
# "static func make():". The part in parentheses (\w+) captures the name.
FUNC_PATTERN = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)")


@dataclass
class SearchMatch:
    """One line that matched the search."""

    file: str              # e.g. "fists/FistBase.gd"
    line_number: int       # Line numbers start at 1, like in the Godot editor
    line: str              # The matching line, with spaces trimmed
    function: str | None   # The function it's inside (scripts only), or None


def search_files(files: list[TextFile], query: str) -> list[SearchMatch]:
    """Return every line containing `query`. Ignores upper/lower case."""
    query = query.lower()
    matches = []

    for file in files:
        is_script = file.relative_path.endswith(".gd")
        current_function = None
        for number, line in enumerate(file.content.splitlines(), start=1):
            if is_script:
                # Keep track of which function we're in as we read down the file.
                func = FUNC_PATTERN.match(line)
                if func:
                    current_function = func.group(1)
                elif line.strip() and not line[0].isspace() and not line.startswith("#"):
                    # An unindented line (like "var stamina = 100") means we've
                    # left the previous function, since function bodies are indented.
                    current_function = None

            if query in line.lower():
                matches.append(SearchMatch(file.relative_path, number, line.strip(), current_function))

    return matches


def search_project(project: Project, query: str) -> list[SearchMatch]:
    """Search scripts, plus scenes, settings and data files, plus design docs."""
    others = [read_text_file(project.root / path, project.root) for path in project.other_files]
    return search_files(project.scripts + others + project.design_docs, query)


def format_matches(matches: list[SearchMatch], limit: int | None = None) -> str:
    """Turn search results into readable text, grouped by file."""
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
