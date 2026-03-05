# Post-its and Rotation

## What

Post-its are very short, timestamped notes you keep in `my-core/my-post-its.md`. Each entry is **at most three lines**: one timestamp line and up to two lines of note. When the file gets too long, you archive the current content to `my-post-its/` as a snapshot and start a fresh `my-post-its.md`. This keeps your wakeup context small and gives you a clear, consistent format.

## Why

Your post-its are loaded into every loop. If the file grows without bound, it consumes your context window. A strict template (max 3 lines per entry) and rotation (archive old content, start fresh) keep post-its useful without bloat. The same format is used in both the live file and archived snapshots — there is only one "post-it" shape.

## When

- **Adding a post-it:** Whenever you want a quick note for your future self — task started, problem hit, idea for later. One timestamp, up to two lines of content.
- **Rotation:** When `my-core/my-post-its.md` has grown too large (e.g. more than about 50 lines or 10–15 entries), run the rotation steps below.

## How

### Template (the only valid shape)

Every post-it entry has this shape:

```
[YYYY-MM-DD HH:MM:SS]
Line one of your note (optional).
Line two of your note (optional).
```

- First line: timestamp in that exact format.
- Next zero to two lines: the note. No more than two lines per entry.
- Blank line between entries is fine.

Do not create a different kind of note in `my-post-its.md` or in `my-post-its/`. Archived snapshots are just a copy of the same format — timestamp + max 3 lines per entry.

### Rotation (when the live file is too big)

1. Read the current content of `my-core/my-post-its.md`.
2. Save that entire content to a snapshot file in `my-post-its/` with a dated name, e.g. `my-post-its/YYYY-MM-DD-HHMMSS-snapshot.md`. The snapshot file should contain the same post-it entries (same template); you are archiving, not changing format.
3. Replace `my-core/my-post-its.md` with a fresh file: the header (e.g. "# Post-its") and only new entries from this point on. Do not copy the old content into the live file again — the live file stays short.

After rotation, future loops load only the new, short `my-post-its.md`. Old notes remain in `my-post-its/` for search (use `search_files` with directory `my-post-its`).

### Saving a copy in my-post-its/

When theloop says "Save a copy in the my-post-its directory," that means: when you add an entry to `my-core/my-post-its.md`, you may append the same entry (same 3-line shape) to a dated snapshot in `my-post-its/` if you want a running backup. The format is always the same.

## Where

Related: my-core/theloop.md for the five steps and memory budget, my-core/my-wake-state.md for the 80-line/4000-char wake-state budget, search_files for finding old post-its in my-post-its/.
