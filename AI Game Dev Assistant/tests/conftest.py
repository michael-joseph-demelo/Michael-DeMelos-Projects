from pathlib import Path

import pytest

from assistant.scanner import Project, load_project
from tests.helpers import write

PLAYER_GD = """\
extends CharacterBody2D

var stamina = 100

func _ready():
\tpass

func punch():
\t# Punching costs stamina
\tstamina -= 10

static func make():
\treturn null
"""


@pytest.fixture
def project_dir(tmp_path: Path) -> Path:
    """A minimal Godot project with scripts, scenes, docs, cache and addons folders."""
    root = tmp_path / "game"
    write(root, "project.godot", '[input]\npunch_left={"events": []}\n')
    write(root, "player/player.gd", PLAYER_GD)
    write(root, "player/player.tscn", '[node name="Player" type="CharacterBody2D"]\nstamina = 50\n')
    write(root, "data/stats.json", '{"stamina": 100}')
    write(root, "docs/combat.md", "# Combat\nPunches cost 10 stamina.\n")
    write(root, "icon.png", "not really a png")
    write(root, ".godot/imported/cache.gd", "var cached = true\n")
    write(root, "addons/plugin/plugin.gd", "var stamina_plugin = 1\n")
    write(root, ".env", "ANTHROPIC_API_KEY=secret\n")
    return root


@pytest.fixture
def project(project_dir: Path) -> Project:
    return load_project(project_dir)
