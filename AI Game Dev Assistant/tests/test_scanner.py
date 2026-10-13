from pathlib import Path

import pytest

from assistant import scanner
from assistant.scanner import load_project, read_project_file
from tests.helpers import write


def test_rejects_missing_folder(tmp_path: Path):
    with pytest.raises(ValueError, match="Folder not found"):
        load_project(tmp_path / "nope")


def test_rejects_folder_without_project_godot(tmp_path: Path):
    with pytest.raises(ValueError, match="No project.godot"):
        load_project(tmp_path)


def test_finds_scripts_and_skips_cache_and_addons(project):
    assert [s.relative_path for s in project.scripts] == ["player/player.gd"]
    assert project.scripts[0].line_count == 13


def test_include_addons_adds_plugin_scripts(project_dir):
    project = load_project(project_dir, include_addons=True)
    assert "addons/plugin/plugin.gd" in [s.relative_path for s in project.scripts]
    assert ".godot/imported/cache.gd" not in [s.relative_path for s in project.scripts]


def test_other_files_exclude_scripts_docs_and_binaries(project):
    assert project.other_files == ["data/stats.json", "player/player.tscn", "project.godot"]


def test_design_docs_default_to_docs_folder(project):
    assert [d.relative_path for d in project.design_docs] == ["docs/combat.md"]


def test_external_docs_dir_uses_docs_relative_paths(project_dir, tmp_path):
    external = tmp_path / "design"
    write(external, "systems/stamina.md", "Stamina regenerates.")
    project = load_project(project_dir, docs_dir=external)
    assert [d.relative_path for d in project.design_docs] == ["systems/stamina.md"]
    # The in-project docs folder is no longer the docs dir, so it shows up as an ordinary file.
    assert "docs/combat.md" in project.other_files


class TestReadProjectFile:
    def test_reads_allowed_file(self, project):
        assert "punch_left" in read_project_file(project, "project.godot")

    @pytest.mark.parametrize("path", ["../outside.txt", "player/../../outside.txt"])
    def test_blocks_path_traversal(self, project, project_dir, path):
        write(project_dir.parent, "outside.txt", "secret")
        with pytest.raises(ValueError, match="outside the project"):
            read_project_file(project, path)

    def test_blocks_absolute_path_outside_project(self, project, tmp_path):
        write(tmp_path, "secret.txt", "secret")
        with pytest.raises(ValueError, match="outside the project"):
            read_project_file(project, str(tmp_path / "secret.txt"))

    @pytest.mark.parametrize("path", [".env", "icon.png"])
    def test_blocks_disallowed_extensions(self, project, path):
        with pytest.raises(ValueError, match="Can't read"):
            read_project_file(project, path)

    def test_blocks_godot_cache(self, project):
        with pytest.raises(ValueError, match="cache"):
            read_project_file(project, ".godot/imported/cache.gd")

    def test_missing_file(self, project):
        with pytest.raises(ValueError, match="File not found"):
            read_project_file(project, "player/enemy.gd")

    def test_truncates_large_files(self, project, project_dir, monkeypatch):
        monkeypatch.setattr(scanner, "MAX_FILE_CHARS", 10)
        write(project_dir, "data/big.json", "x" * 25)
        text = read_project_file(project, "data/big.json")
        assert text.startswith("x" * 10 + "\n")
        assert "the file is 25 characters" in text
