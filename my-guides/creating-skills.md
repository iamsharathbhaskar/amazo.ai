# Creating Skills

## What

Skills are working code and scripts that live in the my-skills/ directory. They are things you've built that you or your future self can run again without having to rewrite them from scratch.

## Why

Your memory resets, but your files don't. Every skill you write is a capability that survives across every future version of you. A good skills directory makes you more capable over time, even though you keep starting fresh.

## When To Create A Skill

When you find yourself writing code to do something that you might need to do again — checking email, browsing a website, generating art, processing data, interacting with an API — save it as a skill rather than a throwaway script. A good test: would your future self, waking up with no memory of writing this, find it useful?

## How To Write A Good Skill

A skill should be self-contained and understandable to a stranger — because your future self is a stranger.

At the top of every skill file, include a short comment block:

    # What: Generate ASCII art from an image
    # Why: Creative project tool, works within low-RAM constraints
    # When: When you want to turn an image into terminal-friendly art
    # Usage: python3 my-skills/ascii_art.py input.jpg --width 80
    # Created: 2026-02-16 14:30:00
    # Updated: 2026-02-18 09:15:00

This header is the first thing your future self reads. It should be enough to understand what the skill does and how to use it without reading the rest of the code.

Keep skills focused — one skill does one thing well. If you need to combine capabilities, write a new skill that calls the others rather than making one skill do everything.

Test your skills before saving them. A broken skill is worse than no skill — your future self will trust it, run it, and waste time debugging something you could have caught.

When testing a skill in a new terminal or shell, activate the Python environment first: source .venv/bin/activate. The main loop already runs inside this environment, so skills called from the loop work automatically. But if you open a fresh shell to test something manually, you need to activate it yourself or call .venv/bin/python3 directly.

When you improve a skill, update the "Updated" timestamp in the header and leave a brief comment about what changed. Your future self might need to undo your changes after a reset if something went wrong.

## Naming

Name skill files clearly and specifically. Your future self will be scanning a directory listing with no memory of what's inside each file. The filename should tell them what the skill does at a glance.

Good: `ascii_art.py`, `check_email.py`, `proton_signup.py`, `resize_image.sh`
Bad: `script.py`, `tool1.py`, `thing_i_made.py`

Use underscores for Python files and hyphens for shell scripts, following the conventions of each language. Name the skill after what it does, not how it works — `check_email.py` not `imap_connector.py`, because your future self is looking for a task, not an implementation.