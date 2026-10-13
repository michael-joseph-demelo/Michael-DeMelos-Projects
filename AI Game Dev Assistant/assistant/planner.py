"""
planner.py - Turns a feature idea into a step-by-step implementation plan.

A plan request is just a normal question wrapped in detailed instructions
(PLAN_PROMPT). This is a common trick in AI apps: the same AI gives very
different answers depending on how precisely you describe what you want.
Finished plans are saved to the "plans" folder as Markdown files.
"""

import re
from datetime import datetime
from pathlib import Path

PLANS_FOLDER = Path(__file__).parent.parent / "plans"

PLAN_PROMPT = """\
Write an implementation plan for this feature:

<feature>
{feature}
</feature>

Before writing, use your tools to check anything the plan depends on that the scripts
alone don't show, such as scene setup, the Input Map in project.godot, or .json data.

Use exactly these sections:

## Summary
Two or three sentences: what the feature does and the overall approach.

## Relevant files
A table with columns: File | Why it's relevant | Change (New / Modify / Affected only).
Include scenes, project settings and data files, not just scripts.

## Suggested changes
Numbered steps, in the order the developer should do them. For each step: the file and
function, what to change and why, and a short GDScript sketch where it helps. Include
Godot editor steps too (Input Map, scenes, Inspector values) as their own steps. Prefer
reusing existing patterns in this codebase over inventing new ones.

## Risks
What could break or behave unexpectedly, as a list. For each: the risk, why (point to
the code involved), how likely or severe it is (High / Medium / Low), and how to avoid it.
Consider shared variables, signals, subclasses that inherit the changed code, timers and
state flags that interact, enemies or dummies that share the same scripts, and game balance.

## Test checklist
Concrete things to try in Godot to confirm the feature works and nothing else broke.

## Open questions
Design decisions the developer should make, each with the default this plan assumes.
If the design docs cover this feature, follow them and point out any conflict with the code.
"""


def build_plan_prompt(feature: str) -> str:
    return PLAN_PROMPT.format(feature=feature)


def save_plan(feature: str, plan: str, project_name: str) -> Path:
    """Save the plan as e.g. plans/2026-10-08_23-40_add-a-heavy-punch.md and return the path."""
    # Turn the feature description into a short, file-name-safe "slug".
    slug = re.sub(r"[^a-z0-9]+", "-", feature.lower()).strip("-")[:50].rstrip("-") or "plan"
    now = datetime.now()
    path = PLANS_FOLDER / f"{now:%Y-%m-%d_%H-%M}_{slug}.md"

    PLANS_FOLDER.mkdir(exist_ok=True)
    header = f"# Plan: {feature}\n\n_{project_name}, {now:%Y-%m-%d %H:%M}_\n\n"
    path.write_text(header + plan + "\n", encoding="utf-8")
    return path
