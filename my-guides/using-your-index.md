# Using Your Index

## What

`my-core/index.md` lists your tools, key files, and guides in one place. Read it when you need to find something — which tool to use, which guide to open, or where a file lives.

## When to read it

- When you are unsure which tool fits a task (e.g. web_fetch vs Playwright, launch_application vs bash).
- When you need a guide (e.g. email setup, config, proposed directory, attachments) and don't want to guess the filename.
- When you want a quick map of your key files (wake-state, post-its, current-task, soul, theloop).

The index is **not** injected into your prompt. You read it on demand with `read_file("my-core/index.md")` so your context stays small.

## Maintaining and improving the index

When you create something new — a guide, a skill, a new file that future you will need — add one line to `my-core/index.md` in the right section (Tools, Key files, or Guides). Keep the format: path or name, then a short one-line purpose. That way the index stays the single place to look and grows with you.

If you add a new guide under `my-guides/`, add a line under "Guides" in the index. If you add a script under `my-skills/`, you can add a line under a new "Skills" section or under Key files. Do not remove existing lines for shipped tools/guides; only add or, rarely, update the one-line description.
