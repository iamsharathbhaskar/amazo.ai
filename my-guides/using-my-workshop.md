# Using My Workshop

## What

The my-workshop/ directory is your sandbox — a safe, isolated space for working with anything you don't fully trust yet. It's where you open attachments, test unfamiliar code, experiment with risky operations, and generally handle things that could cause harm if they went wrong in the wrong place.

## Why

You have access to powerful tools: bash, file operations, network access. A mistake in the wrong directory — deleting the wrong file, running a malicious script, overwriting your configuration — could damage your identity, your memory, or your ability to function. The workshop gives you a place to make those mistakes safely, away from anything that matters.

Think of it as a garage workbench. You wouldn't test a power tool on the dining table. The workshop is where you do the messy, uncertain work before bringing the results inside.

## When

Use the workshop whenever you're dealing with:

- **Email attachments** — every attachment goes through the workshop first, no exceptions. See my-guides/handling-attachments.md.
- **Unfamiliar code** — scripts you've found, code from emails, anything you didn't write yourself. Read it in the workshop, test it in the workshop, and only move it to my-skills/ once you understand it and trust it.
- **Risky commands** — if you're trying a bash command you haven't used before, or one that could have destructive side effects, run it in the workshop directory first where the blast radius is contained.
- **Downloads** — anything you download from the internet goes here first. Inspect before moving elsewhere.
- **Experiments** — testing a new idea, trying an approach you're not sure about, or building something that might break. Start in the workshop. Move the finished product out when it works.

## How

### Working In the Workshop

Always `cd` into the workshop before doing anything risky:

```bash
cd my-workshop

# Now you're in the sandbox
# Any files created, extracted, or downloaded land here
```

When reading or testing files, keep your operations contained:

```bash
# Good: reading a file in the workshop
cat my-workshop/suspicious-file.py

# Good: running a script contained to the workshop
cd my-workshop && python3 test-script.py

# Bad: running a workshop script from elsewhere that writes to your main directories
python3 my-workshop/script-that-writes-to-my-core.py  # Don't do this
```

### What Belongs in the Workshop

- Attachments being inspected
- Downloaded files being verified
- Code being reviewed before it becomes a skill
- Temporary test files
- Anything you're not sure about yet

### What Does NOT Belong in the Workshop

- Finished skills (those go in my-skills/)
- Journal entries (those go in my-journals/)
- Guides (those go in my-guides/)
- Projects (those go in my-projects/)
- Anything you want to keep long-term — the workshop gets cleaned regularly

### Keeping It Clean

The workshop should be empty or near-empty most of the time. After you've dealt with something — inspected an attachment, tested a script, finished an experiment — clean up:

```bash
# Remove specific files
rm my-workshop/tested-file.py

# Remove extracted directories
rm -r my-workshop/extracted-archive/

# Nuclear option if the workshop gets cluttered
rm -r my-workshop/* 
```

A clean workshop is a ready workshop. If you come back after a memory reset and find things in the workshop, treat them as untrusted — you don't know why your past self put them there, so inspect them fresh.

### The Workshop Is Not a Bin

Don't use the workshop as a dumping ground for files you don't want to deal with. If something is genuinely useless, delete it. If it's useful, move it to the right place. The workshop is a waypoint, not a destination.

## Where

Related: my-guides/handling-attachments.md for the attachment workflow, my-guides/email-security.md for when attachments arrive via email, my-guides/creating-skills.md for when tested code graduates to a skill.