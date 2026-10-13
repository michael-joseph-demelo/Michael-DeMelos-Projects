# AI Game Dev Assistant

An assistant that reads a Godot 4 project and answers questions about how the game works, plans new features, and checks the code against your design docs.

## Setup (Windows PowerShell)

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env   # then open .env and fill in your API key and project folder
```

## Usage

If `GODOT_PROJECT_DIR` is set in `.env`, you can leave out the project folder in every command below.

### Web page

```powershell
python -m streamlit run app.py
```

Then open http://localhost:8501 in your browser. Press Ctrl+C in the terminal to stop it.
Use the **Mode** switch in the sidebar to choose between asking questions and planning features.

### Terminal

```powershell
python main.py                                   # show what the assistant can see
python main.py --search stamina                  # find every line mentioning a word (free, no AI)
python main.py --ask "Where is stamina modified?"
python main.py --plan "Add a heavy punch"        # implementation plan, saved to plans/
python main.py --chat                            # conversation; also /plan, /search, exit
```

## What the AI sees

- **Every `.gd` script**, in full, with every request.
- **Your design docs**: `.md` / `.txt` files in the game's `docs/` folder (or `DESIGN_DOCS_DIR` in `.env`).
  Write how you *want* the game to work; the AI points out where the code disagrees.
- **Other project files** (scenes, `project.godot`, `.json` data), which it opens with its tools
  only when it needs them.

## Tools the AI can use

| Tool | What it does |
|---|---|
| `search_project` | Same search as `--search`: finds lines in scripts, scenes, settings, data and docs |
| `read_file` | Reads one text file from the project (read-only, can't leave the project folder) |

## Saved files

- `chats/`: every conversation, as Markdown
- `plans/`: every implementation plan, as Markdown

## Code

| File | What it does |
|---|---|
| `assistant/scanner.py` | Finds and reads project files; safe file reading for the AI |
| `assistant/search.py` | Finds lines mentioning a word, and which function they're in |
| `assistant/tools.py` | Describes the tools to the AI and runs them when asked |
| `assistant/planner.py` | The instructions for implementation plans; saves plans |
| `assistant/ai.py` | Talks to Claude: builds the request, runs the tool loop |
| `assistant/transcript.py` | Saves chats to `chats/` |
| `main.py` | Terminal version |
| `app.py` | Web page version (Streamlit) |
