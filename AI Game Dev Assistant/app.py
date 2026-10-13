"""
Streamlit web UI. Run with `streamlit run app.py` and open http://localhost:8501.

Streamlit re-executes this script on every interaction, so the GameAssistant and the
rendered chat history live in st.session_state (per browser tab).
"""

import os
from pathlib import Path

import anthropic
import streamlit as st
from dotenv import load_dotenv

from assistant.ai import GameAssistant, describe_api_error
from assistant.scanner import load_project
from assistant.search import format_matches, search_project
from assistant.transcript import Transcript

load_dotenv(Path(__file__).parent / ".env")
st.set_page_config(page_title="Game Dev Assistant", page_icon="🎮")

ASK, PLAN = "Ask a question", "Plan a feature"


def start_new_chat(project_dir: Path) -> None:
    """Rescan the project and start a fresh conversation and transcript."""
    docs_env = os.environ.get("DESIGN_DOCS_DIR")
    docs_dir = Path(docs_env).expanduser().resolve() if docs_env else None
    project = load_project(project_dir, docs_dir=docs_dir)
    st.session_state.assistant = GameAssistant(project, transcript=Transcript(project.name))
    st.session_state.chat = []  # rendered messages: {"role", "text", "note"}


# ---------- Sidebar: choose the project and mode ----------
with st.sidebar:
    st.header("Project")
    path_text = st.text_input("Godot project folder", value=os.environ.get("GODOT_PROJECT_DIR", ""))
    load_clicked = st.button(
        "Load project / New chat", width="stretch", help="Re-reads your files, so use this after editing code or docs."
    )
    mode = st.radio("Mode", [ASK, PLAN], horizontal=True)

# Load on button click, or automatically on first visit if a path is configured.
if load_clicked or ("assistant" not in st.session_state and path_text):
    try:
        start_new_chat(Path(path_text).expanduser().resolve())
    except ValueError as e:
        st.sidebar.error(str(e))

st.title("🎮 Game Dev Assistant")

if not os.environ.get("ANTHROPIC_API_KEY"):
    st.error("No API key found. Copy .env.example to .env and paste your key into it, then restart.")
    st.stop()
if "assistant" not in st.session_state:
    st.info("Enter your Godot project folder in the sidebar and click **Load project**.")
    st.stop()

assistant: GameAssistant = st.session_state.assistant
project = assistant.project

# ---------- Main area: the conversation ----------
for message in st.session_state.chat:
    with st.chat_message(message["role"]):
        st.markdown(message["text"])
        if message.get("note"):
            st.caption(message["note"])

placeholder = (
    "Describe a feature to plan, e.g. Add a heavy punch that costs more stamina"
    if mode == PLAN
    else "Ask about your code, e.g. Where is stamina modified?"
)
if prompt := st.chat_input(placeholder):
    shown_prompt = f"**📋 Plan:** {prompt}" if mode == PLAN else prompt
    with st.chat_message("user"):
        st.markdown(shown_prompt)

    with st.chat_message("assistant"):
        try:
            pieces = assistant.plan(prompt) if mode == PLAN else assistant.ask(prompt)
            answer = st.write_stream(pieces)
            note = assistant.last_usage
            if assistant.last_plan_path:
                note += f"  \nPlan saved to plans/{assistant.last_plan_path.name}"
                assistant.last_plan_path = None
            st.caption(note)
            st.session_state.chat.append({"role": "user", "text": shown_prompt})
            st.session_state.chat.append({"role": "assistant", "text": answer, "note": note})
        except anthropic.APIError as e:
            st.error(describe_api_error(e))

# ---------- Sidebar: project info, cost, docs and search ----------
# Drawn after the chat so the cost metric includes the answer that just finished.
with st.sidebar:
    total_lines = sum(s.line_count for s in project.scripts)
    st.caption(f"**{project.name}**: {len(project.scripts)} scripts, {total_lines} lines")
    with st.expander("Scripts"):
        for script in project.scripts:
            st.text(f"{script.relative_path} ({script.line_count})")
    with st.expander(f"Other files the AI can open ({len(project.other_files)})"):
        for path in project.other_files:
            st.text(path)

    st.metric("Session cost (estimate)", f"${assistant.total_cost:.4f}")
    if assistant.transcript.path.exists():
        st.caption(f"Chat saved to `chats/{assistant.transcript.path.name}`")

    st.header("Design docs")
    if project.design_docs:
        for doc in project.design_docs:
            st.text(f"{doc.relative_path} ({doc.line_count} lines)")
    else:
        st.caption("None yet.")
    st.caption(f"Add .md files to `{project.docs_dir}`, then click **Load project / New chat**.")

    st.header("Search project")
    word = st.text_input("Find a word (free, no AI)")
    if word:
        st.code(format_matches(search_project(project, word)), language=None)
