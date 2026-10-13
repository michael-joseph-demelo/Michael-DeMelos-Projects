"""
Persists each conversation as a Markdown file in chats/.
"""

from datetime import datetime
from pathlib import Path

CHATS_FOLDER = Path(__file__).parent.parent / "chats"


class Transcript:
    def __init__(self, project_name: str):
        self.project_name = project_name
        self.started = datetime.now()
        self.path = CHATS_FOLDER / f"{self.started:%Y-%m-%d_%H-%M-%S}.md"

    def add(self, question: str, answer: str) -> None:
        # Created lazily so sessions with no answers don't leave empty files.
        if not self.path.exists():
            CHATS_FOLDER.mkdir(exist_ok=True)
            header = f"# Chat about {self.project_name}\n\n_Started {self.started:%Y-%m-%d %H:%M}_\n\n"
            self.path.write_text(header, encoding="utf-8")

        with self.path.open("a", encoding="utf-8") as f:
            f.write(f"---\n\n## You\n\n{question}\n\n## Assistant\n\n{answer}\n\n")
