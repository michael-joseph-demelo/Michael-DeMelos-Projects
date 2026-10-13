"""
main.py - The terminal version of the assistant. This is the file you run.

Usage (the project folder can be left out if GODOT_PROJECT_DIR is set in .env):
    python main.py [project_dir]                                  # list what the assistant can see
    python main.py [project_dir] --search stamina                 # find lines (free, no AI)
    python main.py [project_dir] --ask "Where is stamina modified?"
    python main.py [project_dir] --plan "Add a heavy punch"       # implementation plan
    python main.py [project_dir] --chat                           # conversation
"""

import argparse
import os
import sys
from collections.abc import Iterator
from pathlib import Path

import anthropic
from dotenv import load_dotenv

from assistant.ai import GameAssistant, describe_api_error
from assistant.scanner import Project, load_project
from assistant.search import format_matches, search_project
from assistant.transcript import Transcript

EXIT_WORDS = {"exit", "quit", "bye"}


def print_stream(assistant: GameAssistant, pieces: Iterator[str]) -> None:
    """Print each piece of the answer as it arrives, then the cost line."""
    for piece in pieces:
        print(piece, end="", flush=True)
    print(f"\n\n--- {assistant.last_usage} ---")
    if assistant.last_plan_path:
        print(f"Plan saved to: {assistant.last_plan_path}")
        assistant.last_plan_path = None


def print_overview(project: Project) -> None:
    """Show everything the assistant can see."""
    print(f"Project: {project.root}\n")
    print("Scripts (sent to the AI in full):")
    for script in project.scripts:
        print(f"  {script.relative_path:<60} {script.line_count:>5} lines")

    print(f"\nOther files (the AI can open these with its read_file tool): {len(project.other_files)}")
    for path in project.other_files:
        print(f"  {path}")

    print(f"\nDesign docs in {project.docs_dir}:")
    if project.design_docs:
        for doc in project.design_docs:
            print(f"  {doc.relative_path:<60} {doc.line_count:>5} lines")
    else:
        print("  (none yet - add .md files to that folder)")


def run_chat(assistant: GameAssistant) -> None:
    """Keep asking for questions until the user types 'exit'."""
    print("Chat mode. Ask anything about your code.")
    print("  /plan <feature>   write an implementation plan (saved to plans/)")
    print("  /search <word>    find lines in your project (free, no AI)")
    print("  exit              quit (or press Ctrl+C)\n")

    while True:
        try:
            # "﻿" is an invisible marker PowerShell adds when text is piped in; drop it.
            question = input("You: ").strip().lstrip("﻿")
        except (KeyboardInterrupt, EOFError):
            break

        if not question:
            continue
        if question.lower() in EXIT_WORDS:
            break

        command, _, rest = question.partition(" ")
        command = command.lower()
        if command == "/search":
            print(format_matches(search_project(assistant.project, rest.strip())) if rest.strip() else "Usage: /search <word>")
            print()
            continue
        if command == "/plan" and not rest.strip():
            print("Usage: /plan <describe the feature>\n")
            continue

        print("\nAI: ", end="")
        try:
            if command == "/plan":
                print_stream(assistant, assistant.plan(rest.strip()))
            else:
                print_stream(assistant, assistant.ask(question))
        except anthropic.APIError as e:
            # Show the error but keep the chat going, so one failure doesn't end the session.
            print(f"\n[{describe_api_error(e)}]")
        except KeyboardInterrupt:
            print("\n[Answer stopped. That question wasn't saved, so you can ask it again.]")
        print()

    print(f"\nGoodbye! Estimated cost of this session: ${assistant.total_cost:.4f}")
    if assistant.transcript and assistant.transcript.path.exists():
        print(f"Chat saved to: {assistant.transcript.path}")


def main() -> None:
    # Windows terminals don't always handle symbols like arrows; UTF-8 avoids crashes.
    sys.stdout.reconfigure(encoding="utf-8")

    # Read the .env file next to this script and load its values (API key, project folder).
    load_dotenv(Path(__file__).parent / ".env")

    # argparse reads the options you type after "python main.py".
    parser = argparse.ArgumentParser(description="Ask questions about a Godot project's GDScript code.")
    parser.add_argument(
        "project_dir",
        nargs="?",  # optional: falls back to GODOT_PROJECT_DIR from .env
        default=os.environ.get("GODOT_PROJECT_DIR"),
        help="Path to your Godot project folder (default: GODOT_PROJECT_DIR in .env)",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--search", metavar="WORD", help="List every line that mentions WORD (no AI, free)")
    mode.add_argument("--ask", metavar="QUESTION", help="Ask one question and exit")
    mode.add_argument("--plan", metavar="FEATURE", help="Write an implementation plan for a feature")
    mode.add_argument("--chat", action="store_true", help="Start a conversation with follow-up questions")
    parser.add_argument(
        "--docs",
        default=os.environ.get("DESIGN_DOCS_DIR"),
        help="Folder with your design docs (default: DESIGN_DOCS_DIR in .env, or 'docs' inside the project)",
    )
    parser.add_argument(
        "--include-addons",
        action="store_true",
        help="Also scan the addons/ folder (third-party plugins)",
    )
    args = parser.parse_args()

    if not args.project_dir:
        sys.exit("Error: no project folder given. Pass it as an argument or set GODOT_PROJECT_DIR in .env.")
    project_dir = Path(args.project_dir).expanduser().resolve()
    docs_dir = Path(args.docs).expanduser().resolve() if args.docs else None

    try:
        project = load_project(project_dir, include_addons=args.include_addons, docs_dir=docs_dir)
    except ValueError as e:
        sys.exit(f"Error: {e}")

    if args.search:
        print(format_matches(search_project(project, args.search)))
        return

    # Nothing to ask: just show what the assistant can see.
    if not (args.ask or args.plan or args.chat):
        print_overview(project)
        return

    if not project.scripts:
        sys.exit("Error: no .gd files found, so there's nothing to ask about.")
    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("Error: no API key found. Copy .env.example to .env and paste your key into it.")

    total_lines = sum(s.line_count for s in project.scripts)
    print(
        f"Loaded {len(project.scripts)} scripts ({total_lines} lines), "
        f"{len(project.design_docs)} design docs and {len(project.other_files)} other files "
        f"from {project.name}.\n"
    )
    assistant = GameAssistant(project, transcript=Transcript(project.name))

    if args.chat:
        run_chat(assistant)
        return

    try:
        print_stream(assistant, assistant.plan(args.plan) if args.plan else assistant.ask(args.ask))
    except anthropic.APIError as e:
        sys.exit(f"\nError: {describe_api_error(e)}")
    if assistant.transcript.path.exists():
        print(f"Chat saved to: {assistant.transcript.path}")


if __name__ == "__main__":
    main()
