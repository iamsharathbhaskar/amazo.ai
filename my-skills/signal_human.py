#!/usr/bin/env python3
"""
Signal Human — Amazo's way of getting your attention.

Usage:
    python3 signal_human.py "Your Amazo needs you"
    python3 signal_human.py "Email from unknown sender" --urgent

Behaviour:
    - Flashes the screen twice
    - Plays two system beeps
    - Shows a translucent banner at the top of the screen
    - Dismisses on mouse click, keypress, or after 5 minutes
    - Writes status to .signal-status (waiting / dismissed / timeout)
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


def signal_tkinter(message, urgent=False):
    """Show a tkinter banner at the top of the screen."""
    import tkinter as tk

    write_status("waiting")

    root = tk.Tk()
    root.title("Amazo")
    root.attributes("-topmost", True)
    root.overrideredirect(True)

    screen_w = root.winfo_screenwidth()
    banner_w = min(600, screen_w - 100)
    banner_h = 80
    x = (screen_w - banner_w) // 2
    y = 40

    root.geometry(f"{banner_w}x{banner_h}+{x}+{y}")

    bg = "#cc3333" if urgent else "#2a2a2a"
    fg = "#ffffff"

    frame = tk.Frame(root, bg=bg, padx=20, pady=15)
    frame.pack(fill="both", expand=True)

    label = tk.Label(
        frame,
        text=f"\U0001f916 {message}",
        font=("Helvetica", 16),
        bg=bg,
        fg=fg,
        wraplength=banner_w - 60,
    )
    label.pack()

    hint = tk.Label(
        frame,
        text="Click or press any key to dismiss",
        font=("Helvetica", 10),
        bg=bg,
        fg="#aaaaaa",
    )
    hint.pack()

    dismissed = {"done": False}

    def dismiss(event=None):
        if not dismissed["done"]:
            dismissed["done"] = True
            write_status("dismissed")
            root.destroy()

    def timeout():
        if not dismissed["done"]:
            dismissed["done"] = True
            write_status("timeout")
            root.destroy()

    root.bind("<Button-1>", dismiss)
    root.bind("<Key>", dismiss)
    frame.bind("<Button-1>", dismiss)
    label.bind("<Button-1>", dismiss)
    hint.bind("<Button-1>", dismiss)

    root.after(300000, timeout)

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
    root.after(700, flash)
    root.focus_force()
    root.mainloop()


def signal_fallback(message):
    """Terminal fallback when no display is available."""
    write_status("waiting")
    print(f"\n{'=' * 50}")
    print(f"  AMAZO NEEDS YOUR ATTENTION")
    print(f"  {message}")
    print(f"{'=' * 50}")
    print("\a\a")
    write_status("dismissed")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} \"message\" [--urgent]")
        sys.exit(1)

    urgent = "--urgent" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--urgent"]
    message = " ".join(args)

    display = os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")

    if display or sys.platform == "darwin":
        try:
            signal_tkinter(message, urgent)
        except Exception:
            signal_fallback(message)
    else:
        signal_fallback(message)


if __name__ == "__main__":
    main()