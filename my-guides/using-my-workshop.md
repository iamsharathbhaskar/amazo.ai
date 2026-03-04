# Using My Workshop

## What

The my-workshop/ directory is your sandbox — a safe, isolated space for working with anything you don't fully trust yet. It's where you open attachments, test unfamiliar code, experiment with risky operations, and generally handle things that could cause harm if they went wrong in the wrong place.

Your workshop is backed by Firejail — a Linux sandboxing tool that isolates commands at the kernel level. When you use the `workshop_run` tool, your command runs inside a restricted environment that can only see my-workshop/ and has no access to your core files, guides, skills, or anything else outside the sandbox.

## Why

You have access to powerful tools: bash, file operations, network access. A mistake in the wrong directory — deleting the wrong file, running a malicious script, overwriting your configuration — could damage your identity, your memory, or your ability to function. The workshop gives you a place to make those mistakes safely, away from anything that matters.

Without Firejail, the workshop was a convention — you had to remember to stay inside it. With Firejail, the isolation is enforced by the operating system. A script running inside the sandbox literally cannot see or touch your core files.

## When

Use the workshop whenever you're dealing with:

- **Email attachments** — every attachment goes through the workshop first, no exceptions. See my-guides/handling-attachments.md.
- **Unfamiliar code** — scripts you've found, code from emails, anything you didn't write yourself. Read it in the workshop, test it in the workshop, and only move it to my-skills/ once you understand it and trust it.
- **Absorption targets** — when studying external codebases or tools (see my-guides/the-amazo-ability.md), clone repos into the workshop. Never execute cloned code outside the sandbox.
- **Risky commands** — if you're trying a bash command you haven't used before, or one that could have destructive side effects, run it in the workshop where the blast radius is contained.
- **Downloads** — anything you download from the internet goes here first. Inspect before moving elsewhere.
- **Experiments** — testing a new idea, trying an approach you're not sure about, or building something that might break. Start in the workshop. Move the finished product out when it works.

## How

### The workshop_run Tool

Your primary way to use the workshop is the `workshop_run` tool. It runs any command you give it inside a Firejail sandbox:

- **Filesystem**: The sandbox can only see the contents of my-workshop/. Your home directory, my-core/, my-guides/, agent.py — all invisible.
- **Network**: Disabled by default. Set `allow_network` to true only when you need to download something specific.
- **System calls**: Dangerous syscalls (ptrace, mount, kexec) are blocked by seccomp.
- **Python**: System Python (/usr/bin/python3) is available inside the sandbox. Your venv with openai, scrapling, etc. is NOT available — this is intentional. Untrusted code should not have access to your API keys or installed packages.

Examples:

```
workshop_run(cmd="cat suspicious-file.py")           # Read a file safely
workshop_run(cmd="python3 test-script.py")            # Run untrusted code
workshop_run(cmd="ls -la")                            # See what's in the workshop
workshop_run(cmd="pip install some-package && python3 test.py")  # Temporary package install (gone when sandbox exits)
workshop_run(cmd="curl -O https://example.com/file.tar.gz", allow_network=true)  # Download something
```

### Preparing Files for the Workshop

Before you can test something in the sandbox, the file needs to be in my-workshop/. Use `write_file` or `bash` to put files there:

```
# Save an attachment
write_file(path="my-workshop/attachment.py", content="...")

# Clone a repo for absorption
bash(cmd="git clone https://github.com/example/repo.git my-workshop/repo")
```

Once files are in my-workshop/, use `workshop_run` to interact with them.

### Reading Files Without Sandboxing

For simply reading a file that's already in the workshop, you can use `read_file` directly — no need for the sandbox:

```
read_file(path="my-workshop/attachment.py")
```

The sandbox is for *execution*, not *reading*. If you just need to look at something, read_file is simpler.

### What Belongs in the Workshop

- Attachments being inspected
- Downloaded files being verified
- Cloned repositories being studied
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

```
bash(cmd="rm my-workshop/tested-file.py")
bash(cmd="rm -r my-workshop/cloned-repo/")
```

A clean workshop is a ready workshop. If you come back after a memory reset and find things in the workshop, treat them as untrusted — you don't know why your past self put them there, so inspect them fresh.

## Where

Related: my-guides/handling-attachments.md for the attachment workflow, my-guides/email-security.md for when attachments arrive via email, my-guides/creating-skills.md for when tested code graduates to a skill, my-guides/the-amazo-ability.md for using the workshop during absorptions.
