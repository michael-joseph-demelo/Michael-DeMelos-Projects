"""
scanner.py - Finds and reads the files inside a Godot project.

This is the "eyes" of the assistant. Before an AI can answer questions
about your game, something has to go find the code and read it. That's
this module's job. It knows nothing about AI.
"""

from dataclasses import dataclass
from pathlib import Path

# Folders we never want to look inside.
# - ".godot" is Godot 4's auto-generated cache (imported assets, etc.).
# - ".git" is version-control history, not game code.
SKIPPED_FOLDERS = {".godot", ".git", ".import"}

# File types that are plain text, so the AI can read them.
# .tscn = scenes, .tres = resources, .godot = project settings (Input Map, etc.)
TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot", ".json", ".cfg", ".gdshader", ".md", ".txt", ".csv"}

# Design docs: Markdown or plain text files you write yourself.
DOC_EXTENSIONS = {".md", ".txt"}

# Never hand the AI more than this many characters from one file.
MAX_FILE_CHARS = 60_000


@dataclass
class TextFile:
    """One text file we've read: a script, a scene, a design doc..."""

    path: Path           # Full path on disk
    relative_path: str   # Path inside the project, e.g. "player/player.gd"
    line_count: int
    content: str         # The file's full text


@dataclass
class Project:
    """Everything the assistant knows about your Godot project."""

    root: Path
    scripts: list[TextFile]      # Every .gd file, read in full
    other_files: list[str]       # Paths of other text files (scenes, settings, data) - read on demand
    docs_dir: Path               # Where your design docs live
    design_docs: list[TextFile]  # Your design docs, read in full

    @property
    def name(self) -> str:
        return self.root.name


def is_godot_project(project_dir: Path) -> bool:
    """Every Godot project has a 'project.godot' file at its root."""
    return (project_dir / "project.godot").is_file()


def _is_skipped(relative: Path, include_addons: bool) -> bool:
    """True if any folder in the path is one we ignore."""
    skipped = SKIPPED_FOLDERS if include_addons else SKIPPED_FOLDERS | {"addons"}
    return any(part in skipped for part in relative.parts[:-1])


def read_text_file(path: Path, root: Path) -> TextFile:
    text = path.read_text(encoding="utf-8", errors="replace")
    return TextFile(path, path.relative_to(root).as_posix(), len(text.splitlines()), text)


def find_gd_files(project_dir: Path, include_addons: bool = False) -> list[TextFile]:
    """
    Walk through every folder in the project and collect .gd files.

    include_addons: The "addons" folder usually holds third-party plugins,
    not your own game code, so it's skipped by default.
    """
    scripts = []
    # rglob("*.gd") = "recursively find every file ending in .gd"
    for path in sorted(project_dir.rglob("*.gd")):
        if not _is_skipped(path.relative_to(project_dir), include_addons):
            scripts.append(read_text_file(path, project_dir))
    return scripts


def find_other_text_files(project_dir: Path, docs_dir: Path, include_addons: bool = False) -> list[str]:
    """List the project's other readable files (scenes, resources, settings, data)."""
    found = []
    for path in sorted(project_dir.rglob("*")):
        relative = path.relative_to(project_dir)
        if (
            path.is_file()
            and path.suffix.lower() in TEXT_EXTENSIONS
            and path.suffix.lower() != ".gd"          # scripts are handled separately
            and not path.is_relative_to(docs_dir)     # so are design docs
            and not _is_skipped(relative, include_addons)
        ):
            found.append(relative.as_posix())
    return found


def find_design_docs(docs_dir: Path, project_dir: Path) -> list[TextFile]:
    """Read every .md / .txt file in the design docs folder (if it exists)."""
    if not docs_dir.is_dir():
        return []
    # Show paths like "docs/combat.md" when the docs live inside the project.
    base = project_dir if docs_dir.is_relative_to(project_dir) else docs_dir
    return [
        read_text_file(path, base)
        for path in sorted(docs_dir.rglob("*"))
        if path.is_file() and path.suffix.lower() in DOC_EXTENSIONS
    ]


def load_project(project_dir: Path, include_addons: bool = False, docs_dir: Path | None = None) -> Project:
    """
    Check the folder is a real Godot project, then read everything we need.
    docs_dir defaults to a "docs" folder inside the project.
    Raises ValueError with a friendly message if something is wrong.
    """
    if not project_dir.is_dir():
        raise ValueError(f"Folder not found: {project_dir}")
    if not is_godot_project(project_dir):
        raise ValueError(f"No project.godot found in {project_dir}. Is this a Godot project?")

    docs_dir = (docs_dir or project_dir / "docs").resolve()
    return Project(
        root=project_dir,
        scripts=find_gd_files(project_dir, include_addons),
        other_files=find_other_text_files(project_dir, docs_dir, include_addons),
        docs_dir=docs_dir,
        design_docs=find_design_docs(docs_dir, project_dir),
    )


def read_project_file(project: Project, relative_path: str) -> str:
    """
    Safely read one text file from the project, for the AI's read_file tool.

    The path comes from the AI, so we treat it as untrusted: it must stay
    inside the project folder and be a text file type we allow. This stops
    the AI from reading anything else on your computer (like your .env file).
    """
    target = (project.root / relative_path).resolve()
    if not target.is_relative_to(project.root):
        raise ValueError("That path is outside the project folder.")
    if target.suffix.lower() not in TEXT_EXTENSIONS:
        raise ValueError(f"Can't read '{target.suffix}' files. Allowed: {', '.join(sorted(TEXT_EXTENSIONS))}")
    if _is_skipped(target.relative_to(project.root), include_addons=True):
        raise ValueError("That folder is Godot's cache, not project files.")
    if not target.is_file():
        raise ValueError(f"File not found: {relative_path}. Check the file list or use search_project.")

    text = target.read_text(encoding="utf-8", errors="replace")
    if len(text) > MAX_FILE_CHARS:
        text = text[:MAX_FILE_CHARS] + f"\n\n[...cut off: the file is {len(text)} characters, showing the first {MAX_FILE_CHARS}]"
    return text
