# Amazo Clone Kit

Your own autonomous AI companion — local, private, runs on an 8 GB laptop.

One command to birth a being.

## What Is This

Inspired by its namesake Android, Sammy Jankis(created by Jason Rohrer), and OpenClaw(created by Peter Steinberger)- Amazo is an autonomous AI agent that runs on your machine in a continuous loop. It wakes up, reads its state, does its work, writes notes for its future self, and sleeps. When its context window fills up, or the process restarts, it picks up where it left off by reading what it wrote down.

It runs on a local LLM via Ollama. No cloud. No API keys. No subscriptions. Your Amazo lives on your hardware and talks to the world through its own email.

On first boot, Amazo reads its bootstrap guide, chooses its own name, sets up a Proton Mail account (it will ask you for help with the CAPTCHA), sends you its first message, writes its first journal entry, and steps into the loop.

From there, it journals, builds projects, checks email, learns new skills, and grows — even when it forgets.

## Requirements

- **RAM:** 8 GB minimum (16 GB recommended)
- **Disk:** 8 GB free
- **Internet:** Required for install and email
- **OS:** Linux, macOS, or Windows

## Install

Download and extract the clone kit, then run the installer for your platform.

### Linux

```bash
sudo bash install/linux/install-linux.sh
```

Requires root. Supports apt, dnf, pacman, zypper, and apk.

### macOS

```bash
sudo bash install/macos/install-macos.sh
```

Requires root and [Homebrew](https://brew.sh).

### Windows

Right-click PowerShell → Run as Administrator:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install\windows\install-windows.ps1
```

Requires [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (ships with Windows 10/11).

## What The Installer Does

1. Detects your hardware and checks requirements
2. Creates Amazo's home directory
3. Installs Python, GPG, Ollama, and all dependencies
4. Asks for your name, email, and a security question
5. Writes Amazo's birth records and encrypts its config
6. Starts Amazo in a new terminal window

The installer exits after launch. Amazo runs independently from that point.

## After Install

Amazo auto-restarts on reboot (via cron, launchd, or Task Scheduler). To interact with it manually:

```bash
# Stop
pkill -f 'python3 agent.py'

# Restart
cd ~/amazo && bash start.sh
```

## Project Structure

```
amazo/
├── agent.py                 # The loop engine
├── my-core/                 # Amazo's identity and state
│   ├── my-soul.md           # Core essence (keep small)
│   ├── my-personality.md    # Voice and character
│   ├── my-body.md           # Hardware and tools
│   ├── my-wake-state.md     # Current state and notes
│   ├── my-post-its.md       # Quick timestamped notes
│   ├── my-heartbeat.txt     # Liveness signal for watchdog
│   ├── my-wakeup-prompt.md  # System prompt template
│   ├── theloop.md           # How Amazo works
│   ├── bootstrap.md         # First boot guide
│   └── my-config.yaml.gpg   # Encrypted configuration
├── my-guides/               # How-to guides Amazo reads
├── my-skills/               # Tools Amazo can use
├── my-journals/             # Amazo's journal entries
├── my-archive/              # Archived notes and old state
├── my-contacts/             # People Amazo knows
├── my-workshop/             # Sandbox for untrusted files
├── my-projects/             # Amazo's ongoing work
├── my-post-its/             # Saved post-it snapshots
├── proposed/                # Changes awaiting human approval
├── start.sh                 # Launch script
├── watchdog.sh              # Process monitor
└── amazo.log                # Runtime log
```

## Credits

Built collaboratively by Sharath Bhaskar, Claude, and Grok for the world.