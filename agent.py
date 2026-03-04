#!/usr/bin/env python3
"""
Amazo Agent — the loop engine.

Reads the wakeup prompt, calls the LLM, executes tool calls,
and repeats. All intelligence comes from the .md files.
"""

import glob as globmod
import json
import os
import re
import shutil
import subprocess
import sys
import time
import yaml
from datetime import datetime

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CONFIG_GPG = "my-core/my-config.yaml.gpg"
CONFIG_PLAIN = "my-core/my-config.yaml"
_DIR_NAME = os.path.basename(os.getcwd())
KEY_PATHS = [f"/root/.{_DIR_NAME}-key", f"/var/root/.{_DIR_NAME}-key"]
HEARTBEAT_FILE = "my-core/my-heartbeat.txt"
LOG_FILE = f"{_DIR_NAME}.log"
MAX_TOOL_ROUNDS = 50
CYCLE_FLOOR = 120      # minimum cycle time in seconds (2 minutes)
CYCLE_CEILING = 3600   # maximum cycle time in seconds (60 minutes)
DEGRADED_SIGNAL_THRESHOLD = 3

DANGEROUS_PATTERNS = [
    (r"\brm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+)?/\b", "rm with absolute root path"),
    (r"\bchmod\s+777\b", "chmod 777"),
    (r"\bchown\s.*\s/\b", "chown on root"),
    (r"\bmkfs\b", "mkfs (format filesystem)"),
    (r"\bdd\s+.*of=/dev/", "dd to raw device"),
    (r":\(\)\{\s*:\|:&\s*\};:", "fork bomb"),
    (r"\bshutdown\b", "shutdown"),
    (r"\breboot\b", "reboot"),
    (r"\brm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+)?\*", "rm with wildcard glob"),
    (r">\s*/dev/sd[a-z]", "redirect to raw disk"),
    (r"\bcurl.*\|\s*(ba)?sh\b", "pipe-to-shell"),
]

# ---------------------------------------------------------------------------
# File protection tiers
# ---------------------------------------------------------------------------

READONLY_FILES = [
    "agent.py",
    "provider.py",
    "my-core/bootstrap.md",
    "my-core/my-body.md",
    "my-core/theloop.md",
    "my-core/my-wakeup-prompt.md",
]

READONLY_PREFIXES = [
    "install/",
]

PROTECTED_FILES = {
    "my-core/my-wake-state.md": {
        "required_headers": ["# Who I Am", "# What's Happening", "# What Matters"],
        "min_lines": 8,
    },
    "my-core/current-task.md": {
        "required_headers": ["# Current Task", "## Plan", "## Progress", "## Notes"],
        "min_lines": 5,
    },
    "my-core/my-soul.md": {
        "required_headers": ["# Soul"],
        "min_lines": 5,
    },
    "my-core/my-personality.md": {
        "required_headers": ["# Personality"],
        "min_lines": 5,
    },
}

SHRINKAGE_PREFIXES = ["my-core/", "my-guides/", "my-skills/"]
SHRINKAGE_THRESHOLD = 0.30
SHRINKAGE_MIN_SIZE = 200
BACKUP_DIR = "my-core/.backups"
MAX_BACKUPS_PER_FILE = 20


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

def log(msg):
    """Append timestamped message to log file and print to stdout."""
    line = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config():
    """Decrypt config into memory, or read plaintext fallback."""
    if os.path.exists(CONFIG_GPG):
        key = None
        for kp in KEY_PATHS:
            if os.path.exists(kp):
                with open(kp) as f:
                    key = f.read().strip()
                break
        if key is None:
            log("FATAL: Encrypted config found but no key at " + ", ".join(KEY_PATHS))
            sys.exit(1)
        try:
            result = subprocess.run(
                ["gpg", "--batch", "--quiet", "--passphrase", key, "--decrypt", CONFIG_GPG],
                capture_output=True, timeout=10
            )
            if result.returncode != 0:
                log("FATAL: Config decryption failed: " + result.stderr.decode())
                sys.exit(1)
            return yaml.safe_load(result.stdout.decode())
        except Exception as e:
            log(f"FATAL: Config decryption failed: {e}")
            sys.exit(1)

    elif os.path.exists(CONFIG_PLAIN):
        with open(CONFIG_PLAIN) as f:
            return yaml.safe_load(f)

    else:
        log("FATAL: No config found at " + CONFIG_GPG + " or " + CONFIG_PLAIN)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

def tool_bash(cmd, config):
    """Execute a bash command. Returns stdout+stderr."""
    timeout = config.get("command_timeout", 120)
    log(f"[bash] {cmd}")
    for pattern, label in DANGEROUS_PATTERNS:
        if re.search(pattern, cmd):
            log(f"[bash] BLOCKED dangerous command: {label}")
            return (
                f"BLOCKED: This command matches a dangerous pattern ({label}). "
                f"If you genuinely need this, write your reasoning to "
                f"my-core/my-wake-state.md first, then ask your human via "
                f"signal_human.py."
            )
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, timeout=timeout
        )
        output = result.stdout.decode(errors="replace") + result.stderr.decode(errors="replace")
        if len(output) > 10000:
            output = output[:5000] + "\n\n...[truncated]...\n\n" + output[-2000:]
        return output if output.strip() else "(no output)"
    except subprocess.TimeoutExpired:
        return f"(command timed out after {timeout}s)"
    except Exception as e:
        return f"(error: {e})"


def tool_read_file(path):
    """Read a file and return its contents."""
    log(f"[read_file] {path}")
    try:
        with open(path, encoding="utf-8") as f:
            content = f.read()
        if len(content) > 50000:
            content = content[:25000] + "\n\n...[truncated]...\n\n" + content[-10000:]
        return content
    except FileNotFoundError:
        return f"(file not found: {path})"
    except Exception as e:
        return f"(error reading {path}: {e})"


def _normalize_path(path):
    """Normalize a tool path: resolve .., strip leading ./"""
    p = os.path.normpath(path)
    if p.startswith("./"):
        p = p[2:]
    return p


def _check_readonly(norm_path):
    """Tier 1: return rejection message if file is off-limits, else None."""
    if norm_path in READONLY_FILES:
        return f"BLOCKED: {norm_path} is a system file and cannot be modified. This file is part of your runtime infrastructure."
    for prefix in READONLY_PREFIXES:
        if norm_path.startswith(prefix):
            return f"BLOCKED: {norm_path} is a system file and cannot be modified. This file is part of your runtime infrastructure."
    return None


def _check_structure(norm_path, content):
    """Tier 2: return rejection message if structure invalid, else None."""
    schema = PROTECTED_FILES.get(norm_path)
    if schema is None:
        return None
    lines = content.strip().splitlines()
    if len(lines) < schema["min_lines"]:
        return (
            f"REJECTED: {norm_path} must have at least {schema['min_lines']} lines. "
            f"You wrote {len(lines)} lines. "
            f"Read the file first with read_file, then rewrite it with full content."
        )
    content_lines = [line.rstrip() for line in lines]
    missing = [h for h in schema["required_headers"] if h not in content_lines]
    if missing:
        return (
            f"REJECTED: {norm_path} requires these sections: {', '.join(schema['required_headers'])}. "
            f"Your content is missing: {', '.join(missing)}. "
            f"Read the file first with read_file, then rewrite it with all sections preserved."
        )
    return None


def _check_shrinkage(norm_path, content):
    """Tier 3: return rejection message if content shrinks too much, else None."""
    for prefix in SHRINKAGE_PREFIXES:
        if norm_path.startswith(prefix):
            break
    else:
        return None
    if not os.path.exists(norm_path):
        return None
    try:
        old_size = os.path.getsize(norm_path)
    except OSError:
        return None
    if old_size < SHRINKAGE_MIN_SIZE:
        return None
    new_size = len(content.encode("utf-8"))
    if new_size < SHRINKAGE_THRESHOLD * old_size:
        reduction = int((1 - new_size / old_size) * 100)
        return (
            f"REJECTED: {norm_path} is currently {old_size:,} chars. "
            f"You are trying to write {new_size:,} chars ({reduction}% reduction). "
            f"This looks like an accidental overwrite. Read the file first, "
            f"then write the complete updated version."
        )
    return None


def _backup_file(norm_path):
    """Create a timestamped backup before overwriting a protected/guarded file."""
    if not os.path.exists(norm_path):
        return
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        basename = os.path.basename(norm_path)
        shutil.copy2(norm_path, f"{BACKUP_DIR}/{basename}.{timestamp}.bak")
        # Prune old backups for this file
        existing = sorted(globmod.glob(f"{BACKUP_DIR}/{basename}.*.bak"))
        if len(existing) > MAX_BACKUPS_PER_FILE:
            for old in existing[:-MAX_BACKUPS_PER_FILE]:
                os.remove(old)
    except OSError:
        pass


def tool_write_file(path, content):
    """Write content to a file with three-tier protection and read-back verification."""
    norm = _normalize_path(path)
    log(f"[write_file] {norm} ({len(content)} chars)")

    # Tier 1: off-limits
    block = _check_readonly(norm)
    if block:
        log(f"[write_file] {block}")
        return block

    # Tier 2: structural validation
    reject = _check_structure(norm, content)
    if reject:
        log(f"[write_file] {reject}")
        return reject

    # Tier 3: shrinkage guard
    reject = _check_shrinkage(norm, content)
    if reject:
        log(f"[write_file] {reject}")
        return reject

    # Backup before overwriting guarded files
    for prefix in SHRINKAGE_PREFIXES:
        if norm.startswith(prefix):
            _backup_file(norm)
            break

    # Write
    try:
        os.makedirs(os.path.dirname(norm) or ".", exist_ok=True)
        with open(norm, "w", encoding="utf-8") as f:
            f.write(content)
    except Exception as e:
        return f"(error writing {norm}: {e})"

    # Read-back verification
    try:
        with open(norm, encoding="utf-8") as f:
            written = f.read()
        lines = written.splitlines()
        total = len(lines)
        if total <= 6:
            preview = written
        else:
            preview = "\n".join(lines[:3] + ["..."] + lines[-3:])
        if len(written) != len(content):
            return (
                f"WARNING: Wrote {len(content)} chars but read back {len(written)} chars.\n"
                f"Preview ({total} lines):\n{preview}"
            )
        return f"Written: {norm} ({total} lines, {len(written)} chars)\nPreview:\n{preview}"
    except Exception:
        return f"Written: {norm} (verification read-back failed)"


def tool_done_for_now(summary=""):
    """Amazo signals it's finished this loop cycle."""
    log(f"[done_for_now] {summary}")
    return "DONE"


# Provider tools — wired up after cascade is initialised
_cascade = None
_current_loop = 0


def tool_switch_model(provider, model, loops=7):
    """Agent requests a specific provider+model for the next N loops."""
    if _cascade is None:
        return "(provider cascade not initialised)"
    _cascade.set_preference(provider, model, loops=loops, current_loop=_current_loop)
    log(f"[switch_model] Preference set: {provider}/{model} for {loops} loops")
    return f"Preference set: {provider}/{model} for {loops} loops (auto-expires at loop {_current_loop + loops})"


def tool_check_providers():
    """Agent queries the health of all provider+model combos."""
    if _cascade is None:
        return "(provider cascade not initialised)"
    status = _cascade.get_status()
    lines = []
    for c in status["combos"]:
        health = c["health"]
        if health == "cooling_down":
            health += f" ({c['cooldown_remaining_s']}s remaining)"
        lines.append(f"  {c['provider']}/{c['model']}: {health}")
    if status["preference"]:
        p = status["preference"]
        lines.append(f"  Active preference: {p['provider']}/{p['model']} (expires loop {p['expires_at_loop']})")
    lines.append(f"  Local fallback: {'available' if status['local_fallback'] else 'not configured'}")
    return "\n".join(lines)


def tool_clear_model_preference():
    """Agent clears any active model preference, resuming normal rotation."""
    if _cascade is None:
        return "(provider cascade not initialised)"
    _cascade.clear_preference()
    log("[clear_model_preference] Preference cleared")
    return "Preference cleared. Resuming normal rotation."


def tool_search_files(query, directory="my-journals"):
    """Search files in a directory for a query string. Returns matching lines with context."""
    log(f"[search_files] '{query}' in {directory}")
    allowed = ["my-journals", "my-post-its", "my-guides", "my-core", "my-archive", "my-projects"]
    if not any(directory.rstrip("/").startswith(a) for a in allowed):
        return f"(search restricted to: {', '.join(allowed)})"
    results = []
    for fpath in sorted(globmod.glob(f"{directory}/**/*", recursive=True)):
        if not os.path.isfile(fpath):
            continue
        try:
            with open(fpath, encoding="utf-8") as f:
                lines = f.readlines()
            for i, line in enumerate(lines):
                if query.lower() in line.lower():
                    ctx_start = max(0, i - 1)
                    ctx_end = min(len(lines), i + 2)
                    snippet = "".join(lines[ctx_start:ctx_end]).strip()
                    results.append(f"{fpath}:{i+1}\n{snippet}")
        except (OSError, UnicodeDecodeError):
            continue
    if not results:
        return f"No matches for '{query}' in {directory}/"
    output = "\n---\n".join(results[:20])
    if len(results) > 20:
        output += f"\n\n... and {len(results) - 20} more matches"
    return output


def tool_workshop_run(cmd, allow_network=False, config=None):
    """Run a command inside the Firejail sandbox, restricted to my-workshop/."""
    timeout = (config or {}).get("command_timeout", 120)
    workshop_abs = os.path.abspath("my-workshop")
    if not os.path.isdir(workshop_abs):
        os.makedirs(workshop_abs, exist_ok=True)

    log(f"[workshop_run] {cmd} (network={'yes' if allow_network else 'no'})")

    firejail_cmd = [
        "firejail", "--noprofile",
        f"--private={workshop_abs}",
        "--private-tmp",
        "--seccomp",
    ]
    if not allow_network:
        firejail_cmd.append("--net=none")
    firejail_cmd.extend(["bash", "-c", cmd])

    try:
        result = subprocess.run(
            firejail_cmd, capture_output=True, timeout=timeout
        )
        output = result.stdout.decode(errors="replace") + result.stderr.decode(errors="replace")
        if len(output) > 10000:
            output = output[:5000] + "\n\n...[truncated]...\n\n" + output[-2000:]
        return output if output.strip() else "(no output)"
    except FileNotFoundError:
        return (
            "(FATAL: Firejail is not installed. Workshop sandboxing requires Firejail. "
            "Ask your human to run: sudo apt install firejail)"
        )
    except subprocess.TimeoutExpired:
        return f"(sandboxed command timed out after {timeout}s)"
    except Exception as e:
        return f"(sandbox error: {e})"


def tool_web_fetch(url, selector=None):
    """Fetch a web page and extract its text content using Scrapling."""
    log(f"[web_fetch] {url}")
    try:
        from scrapling.fetchers import Fetcher
        page = Fetcher.get(url, stealthy_headers=True, timeout=30)
        if selector:
            elements = page.css(selector)
            text = "\n".join(el.text for el in elements if el.text)
        else:
            text = page.get_all_text(ignore_tags=('script', 'style', 'nav', 'footer'))
        if len(text) > 15000:
            text = text[:7500] + "\n\n...[truncated]...\n\n" + text[-3000:]
        return text if text.strip() else "(page returned no text content)"
    except ImportError:
        return "(scrapling not installed. Run: pip install scrapling[fetchers])"
    except Exception as e:
        return f"(error fetching {url}: {e})"


TOOL_DISPATCH = {
    "bash": lambda args, cfg: tool_bash(args.get("cmd", ""), cfg),
    "read_file": lambda args, cfg: tool_read_file(args.get("path", "")),
    "write_file": lambda args, cfg: tool_write_file(args.get("path", ""), args.get("content", "")),
    "done_for_now": lambda args, cfg: tool_done_for_now(args.get("summary", "")),
    "search_files": lambda args, cfg: tool_search_files(args.get("query", ""), args.get("directory", "my-journals")),
    "switch_model": lambda args, cfg: tool_switch_model(
        args.get("provider", ""), args.get("model", ""), args.get("loops", 7)
    ),
    "check_providers": lambda args, cfg: tool_check_providers(),
    "clear_model_preference": lambda args, cfg: tool_clear_model_preference(),
    "workshop_run": lambda args, cfg: tool_workshop_run(
        args.get("cmd", ""), args.get("allow_network", False), cfg
    ),
    "web_fetch": lambda args, cfg: tool_web_fetch(args.get("url", ""), args.get("selector")),
}

TOOLS_SCHEMA = [
    {
        "type": "function",
        "function": {
            "name": "bash",
            "description": "Run a bash command. You have full root access.",
            "parameters": {
                "type": "object",
                "properties": {"cmd": {"type": "string", "description": "The command to run"}},
                "required": ["cmd"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string", "description": "Path to the file"}},
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write content to a file. Creates directories if needed.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Path to the file"},
                    "content": {"type": "string", "description": "Content to write"}
                },
                "required": ["path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_files",
            "description": "Search your journals, post-its, guides, or other directories for a keyword or phrase. Returns matching lines with surrounding context. Useful for finding past decisions, notes, or solutions.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "The text to search for (case-insensitive)"},
                    "directory": {"type": "string", "description": "Directory to search (default: my-journals). Allowed: my-journals, my-post-its, my-guides, my-core, my-archive, my-projects"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "done_for_now",
            "description": "Call this when you have finished your work for this loop cycle. Include a brief summary of what you did.",
            "parameters": {
                "type": "object",
                "properties": {"summary": {"type": "string", "description": "Brief summary of what you did this cycle"}},
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "switch_model",
            "description": "Request a specific cloud provider and model for the next N loops. Useful if a particular model is working well for your current task. Auto-expires after the specified number of loops.",
            "parameters": {
                "type": "object",
                "properties": {
                    "provider": {"type": "string", "description": "Provider name (e.g. groq, cerebras, mistral, openrouter)"},
                    "model": {"type": "string", "description": "Model name (e.g. qwen/qwen3-32b)"},
                    "loops": {"type": "integer", "description": "Number of loops to keep this preference (default 7)"}
                },
                "required": ["provider", "model"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "check_providers",
            "description": "Check the health status of all cloud providers and models. Shows which are healthy, which are in cooldown, and any active preferences.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "clear_model_preference",
            "description": "Clear any active model preference and resume normal round-robin rotation across all providers.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "workshop_run",
            "description": "Run a command inside the Firejail sandbox, restricted to my-workshop/. Use for untrusted code, email attachments, risky experiments. No network by default. System Python is available but the venv is not.",
            "parameters": {
                "type": "object",
                "properties": {
                    "cmd": {"type": "string", "description": "The command to run inside the sandbox"},
                    "allow_network": {"type": "boolean", "description": "Allow network access (default: false)"}
                },
                "required": ["cmd"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "web_fetch",
            "description": "Fetch a web page and extract its text content. Fast and lightweight. Use for reading documentation, articles, reference material. For pages that require JavaScript or login, use Playwright via bash instead.",
            "parameters": {
                "type": "object",
                "properties": {
                    "url": {"type": "string", "description": "The URL to fetch"},
                    "selector": {"type": "string", "description": "Optional CSS selector to extract specific elements (e.g. '.main-content', 'article')"}
                },
                "required": ["url"]
            }
        }
    }
]


def dispatch_tool(name, arguments, config):
    """Call the right tool function and return its result."""
    try:
        args = json.loads(arguments) if isinstance(arguments, str) else arguments
    except json.JSONDecodeError:
        return f"(invalid arguments: {arguments})"

    handler = TOOL_DISPATCH.get(name)
    if handler:
        return handler(args, config)
    return f"(unknown tool: {name})"


# ---------------------------------------------------------------------------
# Heartbeat
# ---------------------------------------------------------------------------

def touch_heartbeat(loop_count, status="waking", action="starting loop"):
    """Write the heartbeat file. Called mechanically at loop start.
    Amazo can also update it via write_file whenever it wants."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    content = f"{now}\nloop: {loop_count}\nstatus: {status}\nlast_action: {action}\n"
    try:
        with open(HEARTBEAT_FILE, "w") as f:
            f.write(content)
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Prompt building
# ---------------------------------------------------------------------------

def build_wakeup_prompt():
    """Read the wakeup prompt template and insert the current timestamp."""
    try:
        with open("my-core/my-wakeup-prompt.md") as f:
            prompt = f.read()
    except FileNotFoundError:
        prompt = "You just woke up. Read my-core/my-wake-state.md and follow my-core/theloop.md."
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    return prompt.replace("[timestamp]", now)


def read_file_safe(path, fallback=""):
    """Read a file, return fallback on error."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (FileNotFoundError, OSError):
        return fallback


# ---------------------------------------------------------------------------
# Degraded mode handler
# ---------------------------------------------------------------------------

def handle_degraded(loop_count, cloud_fail_count, config):
    """Handle a loop where no cloud provider is available.
    Returns updated cloud_fail_count."""
    cloud_fail_count += 1
    touch_heartbeat(loop_count, status="degraded", action="waiting for cloud")

    if cloud_fail_count == DEGRADED_SIGNAL_THRESHOLD:
        log("Cloud unavailable for 3 consecutive loops. Signalling human.")
        try:
            subprocess.Popen(
                ["python3", "my-skills/signal_human.py",
                 "All cloud providers unavailable — running in degraded mode", "--urgent"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        except Exception:
            pass

    wake_state = read_file_safe("my-core/my-wake-state.md", "")
    if "FIRST_BOOT" not in wake_state:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        journal_line = f"\n[{now}] Degraded mode — all cloud providers unavailable. Waiting.\n"
        try:
            with open("my-core/my-post-its.md", "a") as f:
                f.write(journal_line)
        except OSError:
            pass

    return cloud_fail_count


# ---------------------------------------------------------------------------
# Context compression
# ---------------------------------------------------------------------------

def compress_cycle(client, model_name, messages, loop_count):
    """Ask the LLM to compress the cycle's conversation into a post-it note."""
    if len(messages) <= 3:
        return
    try:
        conversation = "\n".join(
            f"[{m['role']}] {(m.get('content') or '')[:500]}" for m in messages[1:]
        )
        resp = client.chat.completions.create(
            model=model_name,
            messages=[
                {"role": "system", "content": (
                    "Summarize the following agent work cycle in 3-5 bullet points. "
                    "Be specific: names, files, outcomes. No preamble."
                )},
                {"role": "user", "content": conversation},
            ],
            max_tokens=300,
        )
        summary = resp.choices[0].message.content.strip()
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        entry = f"\n[{now}] Loop {loop_count} summary:\n{summary}\n"
        with open("my-core/my-post-its.md", "a") as f:
            f.write(entry)
        log(f"[compress] Wrote cycle summary ({len(summary)} chars)")
    except Exception as e:
        log(f"[compress] Failed: {e}")


# ---------------------------------------------------------------------------
# Single cycle
# ---------------------------------------------------------------------------

def run_cycle(client, model_name, config, loop_count):
    """Run one loop cycle. Returns when Amazo calls done_for_now,
    stops issuing tool calls, or hits the safety limit."""

    touch_heartbeat(loop_count, status="waking", action="starting loop")

    system_prompt = build_wakeup_prompt()
    wake = read_file_safe("my-core/my-wake-state.md", "(my-wake-state.md not found)")
    postits = read_file_safe("my-core/my-post-its.md", "(my-post-its.md not found)")

    wake_warning = ""
    if len(wake) > 4000:
        wake_warning = (
            f"\n\nWARNING: my-wake-state.md is {len(wake)} chars (budget: 4000). "
            f"Consolidate it this cycle — archive old notes and trim."
        )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Wake-state:\n{wake}\n\nPost-its:\n{postits}{wake_warning}"}
    ]

    model = model_name
    done = False
    rounds = 0

    while not done and rounds < MAX_TOOL_ROUNDS:
        rounds += 1

        try:
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                tools=TOOLS_SCHEMA
            )
        except Exception as e:
            log(f"LLM call failed: {e}")
            break

        assistant_msg = response.choices[0].message

        msg_entry = {"role": "assistant", "content": assistant_msg.content or ""}
        if assistant_msg.tool_calls:
            msg_entry["tool_calls"] = [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {
                        "name": tc.function.name,
                        "arguments": tc.function.arguments
                    }
                }
                for tc in assistant_msg.tool_calls
            ]
        messages.append(msg_entry)

        if assistant_msg.content:
            log(f"[agent] {assistant_msg.content[:300]}")

        if not assistant_msg.tool_calls:
            break

        for tc in assistant_msg.tool_calls:
            result = dispatch_tool(tc.function.name, tc.function.arguments, config)
            messages.append({
                "role": "tool",
                "tool_call_id": tc.id,
                "content": result
            })
            if result == "DONE":
                done = True
                break

    if rounds >= MAX_TOOL_ROUNDS:
        log(f"Safety limit reached ({MAX_TOOL_ROUNDS} tool rounds). Ending cycle.")

    compress_cycle(client, model_name, messages, loop_count)
    touch_heartbeat(loop_count, status="sleeping", action=f"completed loop {loop_count}")


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run():
    global _cascade, _current_loop

    os.chdir(os.path.dirname(os.path.abspath(__file__)) or ".")
    log("Agent starting")

    config = load_config()

    try:
        from openai import OpenAI
    except ImportError:
        log("FATAL: openai package not installed. Run: pip install openai")
        sys.exit(1)

    # Determine if we have v2 multi-provider config or v1 single-provider
    if "providers" in config:
        from provider import ProviderCascade
        cascade = ProviderCascade(config["providers"], config.get("local_fallback", {}))
        _cascade = cascade
        log("Provider cascade initialised with "
            f"{len(cascade._combos)} cloud combos, "
            f"local fallback: {bool(config.get('local_fallback'))}")
    else:
        cascade = None
        client = OpenAI(
            base_url=config.get("api_base", "http://localhost:11434") + "/v1",
            api_key="ollama"
        )
        log(f"Config loaded (v1 mode): model={config.get('model')}, "
            f"interval={config.get('loop_interval')}s")

    loop_interval = config.get("loop_interval", 300)
    loop_interval = max(CYCLE_FLOOR, min(CYCLE_CEILING, loop_interval))

    loop_count = 0
    cloud_fail_count = 0

    while True:
        loop_count += 1
        _current_loop = loop_count

        if cascade is not None:
            result = cascade.get_client(loop_count)
            client_obj, provider_name, model_name, mode = result

            log(f"--- Loop {loop_count} | {provider_name}/{model_name} | {mode} ---")

            if mode == "degraded" and client_obj is None:
                cloud_fail_count = handle_degraded(loop_count, cloud_fail_count, config)
            elif mode == "degraded":
                cloud_fail_count = handle_degraded(loop_count, cloud_fail_count, config)
            else:
                cloud_fail_count = 0
                try:
                    run_cycle(client_obj, model_name, config, loop_count)
                    cascade.report_success(provider_name, model_name)
                except Exception as e:
                    log(f"Cycle failed: {e}")
                    cascade.report_failure(provider_name, model_name)
        else:
            model_name = config.get("model", "qwen2.5:7b")
            log(f"--- Loop {loop_count} ---")
            run_cycle(client, model_name, config, loop_count)

        log(f"Sleeping {loop_interval}s")
        time.sleep(loop_interval)


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        log("Interrupted by user")
    except Exception as e:
        log(f"Fatal error: {e}")
        raise
