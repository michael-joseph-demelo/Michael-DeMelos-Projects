"""
Project discovery and sandboxed file access. Has no dependency on the AI layer.
"""

from dataclasses import dataclass
from pathlib import Path

# .godot is Godot 4's generated import cache.
SKIPPED_FOLDERS = {".godot", ".git", ".import"}

# Text formats the assistant may read: .tscn scenes, .tres resources, project.godot settings, data and docs.
TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot", ".json", ".cfg", ".gdshader", ".md", ".txt", ".csv"}

DOC_EXTENSIONS = {".md", ".txt"}

# Per-file cap on what read_file returns, to bound context size.
MAX_FILE_CHARS = 60_000


@dataclass
class TextFile:
    path: Path
    relative_path: str  # POSIX-style, relative to the project root, e.g. "player/player.gd"
    line_count: int
    content: str


@dataclass
class Project:
    root: Path
    scripts: list[TextFile]  # every .gd file, sent to the model in full
    other_files: list[str]  # relative paths of other text files, read on demand via tools
    docs_dir: Path
    design_docs: list[TextFile]

    @property
    def name(self) -> str:
        return self.root.name


def is_godot_project(project_dir: Path) -> bool:
    return (project_dir / "project.godot").is_file()


def _is_skipped(relative: Path, include_addons: bool) -> bool:
    """True if any parent folder is excluded. addons/ holds third-party plugins, so it's opt-in."""
    skipped = SKIPPED_FOLDERS if include_addons else SKIPPED_FOLDERS | {"addons"}
    return any(part in skipped for part in relative.parts[:-1])


def read_text_file(path: Path, root: Path) -> TextFile:
    text = path.read_text(encoding="utf-8", errors="replace")
    return TextFile(path, path.relative_to(root).as_posix(), len(text.splitlines()), text)


def find_gd_files(project_dir: Path, include_addons: bool = False) -> list[TextFile]:
    return [
        read_text_file(path, project_dir)
        for path in sorted(project_dir.rglob("*.gd"))
        if not _is_skipped(path.relative_to(project_dir), include_addons)
    ]


def find_other_text_files(project_dir: Path, docs_dir: Path, include_addons: bool = False) -> list[str]:
    """Index non-script text files (scenes, resources, settings, data), excluding design docs."""
    found = []
    for path in sorted(project_dir.rglob("*")):
        relative = path.relative_to(project_dir)
        if (
            path.is_file()
            and path.suffix.lower() in TEXT_EXTENSIONS
            and path.suffix.lower() != ".gd"
            and not path.is_relative_to(docs_dir)
            and not _is_skipped(relative, include_addons)
        ):
            found.append(relative.as_posix())
    return found


def find_design_docs(docs_dir: Path, project_dir: Path) -> list[TextFile]:
    if not docs_dir.is_dir():
        return []
    # Docs inside the project get project-relative paths ("docs/combat.md"); external docs are docs-relative.
    base = project_dir if docs_dir.is_relative_to(project_dir) else docs_dir
    return [
        read_text_file(path, base)
        for path in sorted(docs_dir.rglob("*"))
        if path.is_file() and path.suffix.lower() in DOC_EXTENSIONS
    ]


def load_project(project_dir: Path, include_addons: bool = False, docs_dir: Path | None = None) -> Project:
    """
    Scan a Godot project. docs_dir defaults to <project>/docs.
    Raises ValueError with a user-facing message if the folder isn't a Godot project.
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
    Read a file on behalf of the model's read_file tool.

    The path is model-supplied and therefore untrusted: it's resolved (following symlinks
    and "..") and must stay inside the project root with an allowed text extension.
    This keeps files like .env and anything outside the project unreachable.
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
        text = (
            text[:MAX_FILE_CHARS]
            + f"\n\n[...cut off: the file is {len(text)} characters, showing the first {MAX_FILE_CHARS}]"
        )
    return text
