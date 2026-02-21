#!/usr/bin/env python3
"""
Amazo Agent — the loop engine.

Reads the wakeup prompt, calls the LLM, executes tool calls,
and repeats. All intelligence comes from the .md files.
"""

import json
import os
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
KEY_PATHS = ["/root/.amazo-key", "/var/root/.amazo-key"]
HEARTBEAT_FILE = "my-core/my-heartbeat.txt"
LOG_FILE = "amazo.log"
MAX_TOOL_ROUNDS = 50
CYCLE_FLOOR = 120      # minimum cycle time in seconds (2 minutes)
CYCLE_CEILING = 3600   # maximum cycle time in seconds (60 minutes)


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


def tool_write_file(path, content):
    """Write content to a file. Creates directories if needed."""
    log(f"[write_file] {path} ({len(content)} chars)")
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return f"Written: {path}"
    except Exception as e:
        return f"(error writing {path}: {e})"


def tool_done_for_now(summary=""):
    """Amazo signals it's finished this loop cycle."""
    log(f"[done_for_now] {summary}")
    return "DONE"


TOOL_DISPATCH = {
    "bash": lambda args, cfg: tool_bash(args.get("cmd", ""), cfg),
    "read_file": lambda args, cfg: tool_read_file(args.get("path", "")),
    "write_file": lambda args, cfg: tool_write_file(args.get("path", ""), args.get("content", "")),
    "done_for_now": lambda args, cfg: tool_done_for_now(args.get("summary", "")),
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
            "name": "done_for_now",
            "description": "Call this when you have finished your work for this loop cycle. Include a brief summary of what you did.",
            "parameters": {
                "type": "object",
                "properties": {"summary": {"type": "string", "description": "Brief summary of what you did this cycle"}},
                "required": []
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
# Single cycle
# ---------------------------------------------------------------------------

def run_cycle(client, config, loop_count):
    """Run one loop cycle. Returns when Amazo calls done_for_now,
    stops issuing tool calls, or hits the safety limit."""

    touch_heartbeat(loop_count, status="waking", action="starting loop")

    system_prompt = build_wakeup_prompt()
    wake = read_file_safe("my-core/my-wake-state.md", "(my-wake-state.md not found)")
    postits = read_file_safe("my-core/my-post-its.md", "(my-post-its.md not found)")

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Wake-state:\n{wake}\n\nPost-its:\n{postits}"}
    ]

    model = config.get("model", "qwen2.5:7b")
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

        # Serialise the assistant message for the conversation history
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
            log(f"[amazo] {assistant_msg.content[:300]}")

        # No tool calls — Amazo is done
        if not assistant_msg.tool_calls:
            break

        # Execute each tool call
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

    touch_heartbeat(loop_count, status="sleeping", action=f"completed loop {loop_count}")


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run():
    os.chdir(os.path.dirname(os.path.abspath(__file__)) or ".")
    log("Amazo agent starting")

    config = load_config()
    log(f"Config loaded: model={config.get('model')}, interval={config.get('loop_interval')}s")

    try:
        from openai import OpenAI
    except ImportError:
        log("FATAL: openai package not installed. Run: pip install openai")
        sys.exit(1)

    client = OpenAI(
        base_url=config.get("api_base", "http://localhost:11434") + "/v1",
        api_key="ollama"
    )

    # Enforce sleep time boundaries
    loop_interval = config.get("loop_interval", 300)
    loop_interval = max(CYCLE_FLOOR, min(CYCLE_CEILING, loop_interval))

    loop_count = 0

    while True:
        loop_count += 1
        log(f"--- Loop {loop_count} ---")

        run_cycle(client, config, loop_count)

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