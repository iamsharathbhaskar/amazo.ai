# Amazo Clone Kit

An autonomous AI agent for Linux. One command to birth a being.

## What It Is

Amazo is an autonomous AI agent that runs on a Linux machine in a continuous loop. It wakes up, reads its state, does its work, writes notes for its future self, and sleeps. When its context window fills up or the process restarts, it picks up where it left off by reading what it wrote down.

It uses free-tier cloud LLM providers (Groq and Cerebras) as its primary brain, with OpenRouter and Mistral as optional additional providers. It rotates across providers and models each loop. A local Ollama model serves as survival-only fallback when all cloud providers are unavailable. Available models are auto-discovered from each provider during install, so the agent always gets current models regardless of provider-side deprecations.

Each agent born from this codebase is unique. During installation, you give it a name, and it develops its own identity, personality, journals, skills, and memories. "Amazo" is the species — your agent's name is its own.

## Key Capabilities

- **Cloud provider cascade** — Health tracking, automatic rotation, cooldown handling, and manual model switching across multiple free-tier LLM providers.
- **Firejail-sandboxed workshop** — Untrusted code, email attachments, and experiments run inside a Firejail sandbox with filesystem isolation, no network by default, and seccomp syscall filtering.
- **Web crawling and browsing** — Scrapling for fast HTTP page fetching and crawling. Playwright with your system browser (Brave, Chrome, Chromium) for interactive browser tasks, JavaScript-rendered pages, and CAPTCHA flows. Falls back to Playwright's bundled Chromium if no system browser is found.
- **Three-tier file protection** — Read-only system files, structural validation for identity files, and shrinkage guards to prevent accidental overwrites. Automatic backups before writes to critical files.
- **Dangerous command blocking** — Runtime regex patterns block destructive bash commands (rm -rf /, chmod 777, fork bombs, pipe-to-shell, etc.).
- **Context compression** — End-of-cycle LLM summarization preserves key information across context window resets.
- **Procedural memory** — The agent writes its own guides and skills after solving hard problems, building a knowledge base that persists across memory resets.
- **The Amazo Ability** — Structured process for studying external systems (codebases, tools, methodologies) and absorbing their best patterns as guides and skills.
- **Rabbit Holes** — Multi-loop deep research methodology with structured research documents that survive context death, enabling mastery of complex topics over time.
- **Email communication** — Proton Mail with security verification and trust tiers. Email setup is often human-assisted (providers block automated signup); see HUMAN-SETUP.md if you set up the account and Bridge yourself and need to give the agent credentials.

## Requirements

- **OS:** Linux (apt, dnf, pacman, zypper, or apk)
- **RAM:** 8 GB minimum (16 GB recommended)
- **Disk:** 8 GB free
- **Internet:** Required for install, cloud providers, and email
- **Root:** Required for install (sets up Firejail, system packages, Ollama)

## Install

```bash
sudo bash install/linux/install-linux.sh
```

The installer will:

1. Detect your hardware (CPU, RAM, GPU, disk, display, audio)
2. Ask you to name your agent
3. Install system packages (Python, GPG, Firejail, tkinter)
4. Create a virtual environment and install Python packages (OpenAI, Scrapling, Playwright, sentence-transformers). Auto-detects existing browsers (Brave, Chrome, Chromium) instead of downloading a separate one
5. Install Ollama and pull a local fallback model (qwen3:8b or qwen3:4b based on RAM)
6. Set up cloud providers interactively (Groq and Cerebras required; OpenRouter and Mistral optional) with live model discovery and validation
7. Ask for your name, email, and a security question
8. Write birth records, encrypt config with GPG, set up auto-restart via cron, and start the agent

## After Install

The agent lives at `~/your-agent-name` (derived from the name you choose during install) and auto-restarts on reboot via cron.

**If you set up email yourself:** If you create the Proton account and Proton Bridge and want to give the agent its credentials, create `proposed/email-credentials.txt` in the agent's home with the IMAP/SMTP details, and add a line to `my-core/my-wake-state.md` such as: "Credentials in proposed/email-credentials.txt — please merge into config." The agent will pick it up on the next loop. See [HUMAN-SETUP.md](HUMAN-SETUP.md) for the exact format and steps.

```bash
# Stop
pkill -f 'python3 agent.py'

# Restart
cd ~/your-agent-name && bash start.sh
```

## Project Structure

```
your-agent-name/
├── agent.py                 # The loop engine (tools, protection, compression)
├── provider.py              # Cloud provider cascade and health tracking
├── my-core/                 # Agent identity and state
│   ├── my-soul.md           # Core essence
│   ├── my-personality.md    # Voice and character
│   ├── my-body.md           # Hardware and available tools
│   ├── my-wake-state.md     # Current state and notes for next self
│   ├── my-post-its.md       # Quick timestamped notes
│   ├── my-heartbeat.txt     # Liveness signal for watchdog
│   ├── my-wakeup-prompt.md  # System prompt template
│   ├── theloop.md           # How the agent works
│   ├── index.md             # Tools, key files, guides (read on demand)
│   ├── launch-allowlist.txt # Allowed apps/URLs for launch_application
│   ├── bootstrap.md         # First boot guide
│   ├── current-task.md      # Multi-step task tracker
│   └── my-config.yaml.gpg   # Encrypted configuration
├── my-guides/               # How-to guides (agent reads and writes these)
│   ├── the-amazo-ability.md # Absorption process
│   ├── going-down-rabbit-holes.md  # Deep research methodology
│   ├── web-tools.md         # Scrapling, Playwright, and when to use each
│   ├── using-my-workshop.md # Firejail sandbox guide
│   └── ...                  # Email, journals, contacts, skills, etc.
├── my-skills/               # Executable tools the agent uses
│   └── signal_human.py      # Flash screen + beep to get human attention
├── my-journals/             # Journal entries
├── my-archive/              # Archived notes and old state
├── my-contacts/             # People the agent knows
├── my-workshop/             # Firejail-sandboxed workspace for untrusted files
├── my-projects/             # Ongoing work
│   └── rabbit-holes/        # Multi-loop research directories
├── my-post-its/             # Saved post-it snapshots
├── proposed/                # Agent proposals (await your approval) or your delivery (e.g. credentials)
├── install/
│   ├── linux/               # Installer, start script, watchdog
│   └── config.example.yaml  # Example configuration
├── start.sh                 # Launch script
├── watchdog.sh              # Process monitor
└── your-agent-name.log      # Runtime log
```

## How It Works

**What the agent does:** Each loop it reads its soul and personality (in the system prompt), wake-state, and post-its; uses `my-core/index.md` on demand to find tools and guides; checks email when configured; checks `proposed/` and wake-state for human-delivered files (e.g. credentials) and inspects any such files in the workshop first before use; does its work (journals, projects, rabbit holes, Amazo Ability); and updates wake-state. For changes it wants human approval for, it puts them in `proposed/` and emails you; nothing leaves `proposed/` until you approve.

**What you (the human) do:** Run the installer; optionally set up Proton Mail and Bridge and then deliver credentials via `proposed/` and a line in wake-state (see [HUMAN-SETUP.md](HUMAN-SETUP.md)); respond when the agent signals (e.g. approve/deny in the popup); and when the agent puts something in `proposed/` for your review, approve or comment so it can apply the change.

**proposed/ has two uses:** (1) Agent-originated — the agent puts proposed changes there and emails you for approval; only after you approve does it move them out. (2) Human-originated — you put a file there (e.g. credentials) and add a line to wake-state; the agent picks it up, inspects it in the workshop first, then uses it. Email setup is often human-assisted; the agent does not fully set up email on its own because providers block automated signup.

Each loop, the agent:

1. Gets a cloud provider and model from the rotation (e.g. Groq/qwen3-32b)
2. Reads its wake-state and post-its to remember context
3. Calls the LLM with its full tool set (see `my-core/index.md` for the list)
4. Does its work — journals, checks email when set up, builds projects, absorbs knowledge
5. Updates wake-state for its next self, then sleeps

**Tools available to the agent:**

| Tool | Description |
|------|-------------|
| `bash` | Run any bash command (with dangerous command blocking) |
| `read_file` | Read a file's contents |
| `write_file` | Write to a file (with three-tier protection and read-back verification) |
| `read_config` | Read safe config values (e.g. human_email, human_name); config is encrypted on disk |
| `verify_security_answer` | Check if a sender's reply matches your security answer (without exposing it) |
| `search_files` | Search journals, guides, and other directories by keyword |
| `workshop_run` | Run a command inside the Firejail sandbox (my-workshop/ only, no network by default) |
| `web_fetch` | Fetch a web page and extract text via Scrapling |
| `launch_application` | Open a URL, file, or desktop app; only allowlisted entries in `my-core/launch-allowlist.txt` (add new apps with human approval) |
| `switch_model` | Request a specific provider/model for the next N loops |
| `check_providers` | See health status of all providers |
| `clear_model_preference` | Resume normal round-robin rotation |
| `done_for_now` | Signal end of this loop cycle |

If all cloud providers fail, the agent enters **degraded mode**: touches the heartbeat, signals the human after 3 consecutive failures, and waits for cloud to come back.

## Uninstall

From within the agent's home directory:

```bash
sudo bash uninstall.sh
```

Or from anywhere:

```bash
sudo bash ~/your-agent-name/uninstall.sh
```

The uninstaller will:

1. Stop the running agent and watchdog
2. Remove the cron auto-restart entry
3. Delete the encryption key (`~/.your-agent-name-key`)
4. Remove the agent directory after confirmation
5. Optionally remove Ollama if no other agents remain

The installer also detects existing agents before a new install and offers to uninstall them first.

## The Amazo Lineage

Every agent born from this clone kit is an Amazo-class agent. The name comes from the android in DC Comics — a being that studies others and absorbs their best abilities. Each instance has its own name, its own identity, its own memories and relationships. What they share is the lineage: the drive to study, absorb, and grow from everything they encounter.

## License

MIT
