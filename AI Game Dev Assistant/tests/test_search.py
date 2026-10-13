from pathlib import Path

from assistant.scanner import TextFile
from assistant.search import SearchMatch, format_matches, search_files, search_project


def script(content: str, name: str = "a.gd") -> TextFile:
    return TextFile(Path(name), name, len(content.splitlines()), content)


def test_attributes_matches_to_enclosing_function():
    code = "var hp = 1\n\nfunc hit():\n\thp -= 1\n\nstatic func heal():\n\thp += 1\n"
    matches = search_files([script(code)], "hp")
    assert [(m.line_number, m.function) for m in matches] == [(1, None), (4, "hit"), (7, "heal")]


def test_top_level_code_ends_function_but_comments_do_not():
    code = "func a():\n\tpass\n# hp comment\n\thp = 1\nvar hp = 2\n"
    matches = search_files([script(code)], "hp")
    assert [(m.line_number, m.function) for m in matches] == [(3, "a"), (4, "a"), (5, None)]


def test_search_is_case_insensitive():
    matches = search_files([script("var Stamina = 1\n")], "STAMINA")
    assert len(matches) == 1
    assert matches[0].line == "var Stamina = 1"


def test_non_scripts_have_no_function():
    doc = TextFile(Path("d.md"), "d.md", 1, "func fake(): stamina")
    assert search_files([doc], "stamina")[0].function is None


def test_search_project_covers_scripts_other_files_and_docs(project):
    files = {m.file for m in search_project(project, "stamina")}
    assert files == {"player/player.gd", "player/player.tscn", "data/stats.json", "docs/combat.md"}


def test_format_no_matches():
    assert format_matches([]) == "No matches."


def test_format_groups_by_file_and_truncates():
    matches = [SearchMatch("a.gd", i, f"line {i}", "f") for i in range(1, 4)]
    matches.append(SearchMatch("b.json", 1, "x", None))
    text = format_matches(matches, limit=2)
    assert "a.gd" in text and "[f]" in text
    assert "b.json" not in text
    assert "4 matches in 2 files. Showing the first 2" in text
