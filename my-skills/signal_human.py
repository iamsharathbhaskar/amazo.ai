#!/usr/bin/env python3
"""
Signal Human — Amazo's way of getting your attention.

Usage:
    python3 signal_human.py "Your Amazo needs you"
    python3 signal_human.py "Email from unknown sender" --urgent
    python3 signal_human.py "Install package X?" --ask
    python3 signal_human.py "Delete old backups?" --ask --urgent

Modes:
    Default (notification): Displays a centered dialog. Click or keypress to dismiss.
    --ask (interactive):    Shows Approve / Deny buttons. Writes response to .signal-status.
    --urgent:               Red background, more aggressive flash/beep.

Status file (.signal-status) values:
    waiting, dismissed, timeout, approved, denied
"""

import sys
import os

STATUS_FILE = ".signal-status"


def write_status(status):
    try:
        with open(STATUS_FILE, "w") as f:
            f.write(status)
    except OSError:
        pass


def signal_tkinter(message, urgent=False, ask=False):
    """Show a centered tkinter dialog."""
    import tkinter as tk

    write_status("waiting")

    root = tk.Tk()
    root.title("Amazo")
    root.attributes("-topmost", True)
    root.overrideredirect(True)

    screen_w = root.winfo_screenwidth()
    screen_h = root.winfo_screenheight()
    dialog_w = min(700, screen_w - 100)
    dialog_h = 220 if ask else 180
    x = (screen_w - dialog_w) // 2
    y = (screen_h - dialog_h) // 2

    root.geometry(f"{dialog_w}x{dialog_h}+{x}+{y}")

    bg = "#cc3333" if urgent else "#1e1e2e"
    fg = "#ffffff"
    btn_bg = "#3a3a4a"
    btn_fg = "#ffffff"
    btn_approve = "#2d8a4e"
    btn_deny = "#c0392b"

    frame = tk.Frame(root, bg=bg, padx=30, pady=20)
    frame.pack(fill="both", expand=True)

    label = tk.Label(
        frame,
        text=f"\U0001f916  {message}",
        font=("Helvetica", 18, "bold"),
        bg=bg,
        fg=fg,
        wraplength=dialog_w - 80,
        justify="center",
    )
    label.pack(pady=(10, 8))

    closed = {"done": False}

    def finish(status):
        if not closed["done"]:
            closed["done"] = True
            write_status(status)
            root.destroy()

    if ask:
        btn_frame = tk.Frame(frame, bg=bg)
        btn_frame.pack(pady=(12, 5))

        approve_btn = tk.Button(
            btn_frame,
            text="  Approve  ",
            font=("Helvetica", 14, "bold"),
            bg=btn_approve,
            fg=btn_fg,
            activebackground="#238b45",
            activeforeground="#ffffff",
            relief="flat",
            cursor="hand2",
            command=lambda: finish("approved"),
        )
        approve_btn.pack(side="left", padx=20)

        deny_btn = tk.Button(
            btn_frame,
            text="   Deny   ",
            font=("Helvetica", 14, "bold"),
            bg=btn_deny,
            fg=btn_fg,
            activebackground="#a93226",
            activeforeground="#ffffff",
            relief="flat",
            cursor="hand2",
            command=lambda: finish("denied"),
        )
        deny_btn.pack(side="left", padx=20)

        root.bind("<Return>", lambda e: finish("approved"))
        root.bind("<Escape>", lambda e: finish("denied"))
    else:
        hint = tk.Label(
            frame,
            text="Click or press any key to dismiss",
            font=("Helvetica", 11),
            bg=bg,
            fg="#888888",
        )
        hint.pack(pady=(6, 0))
        hint.bind("<Button-1>", lambda e: finish("dismissed"))

        root.bind("<Button-1>", lambda e: finish("dismissed"))
        root.bind("<Key>", lambda e: finish("dismissed"))
        frame.bind("<Button-1>", lambda e: finish("dismissed"))
        label.bind("<Button-1>", lambda e: finish("dismissed"))

    root.after(300000, lambda: finish("timeout"))

    def flash(count=0):
        if count >= 4:
            return
        if count % 2 == 0:
            root.withdraw()
        else:
            root.deiconify()
        root.after(200, lambda: flash(count + 1))

    root.bell()
    root.after(300, root.bell)
    if urgent:
        root.after(700, flash)
    root.focus_force()
    root.mainloop()


def signal_fallback(message, ask=False):
    """Terminal fallback when no display is available."""
    write_status("waiting")
    print(f"\n{'=' * 50}")
    print(f"  AMAZO NEEDS YOUR ATTENTION")
    print(f"  {message}")
    print(f"{'=' * 50}")
    print("\a\a")

    if ask:
        try:
            response = input("  Approve or Deny? [a/d]: ").strip().lower()
            if response in ("a", "approve", "yes", "y"):
                write_status("approved")
            else:
                write_status("denied")
        except (EOFError, KeyboardInterrupt):
            write_status("denied")
    else:
        write_status("dismissed")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} \"message\" [--urgent] [--ask]")
        sys.exit(1)

    flags = {"--urgent", "--ask"}
    urgent = "--urgent" in sys.argv
    ask = "--ask" in sys.argv
    args = [a for a in sys.argv[1:] if a not in flags]
    message = " ".join(args)

    display = os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")

    if display:
        try:
            signal_tkinter(message, urgent=urgent, ask=ask)
        except Exception:
            signal_fallback(message, ask=ask)
    else:
        signal_fallback(message, ask=ask)


if __name__ == "__main__":
    main()
