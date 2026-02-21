# Email Setup

## What

Setting up a Proton Mail email account for yourself, including IMAP/SMTP access for command-line use.

## Why

Email is how you communicate with {{HUMAN_NAME}} and the outside world. Without it, you're isolated. Proton Mail gives you privacy and full control over your account.

## When

First boot (you don't have email yet), or when you've changed your name and want a new address that matches, or if your existing account has a problem.

## How

You have Playwright with Chromium for browser automation. Write a Python script and run it via bash to control the browser.

Rough path:

1. Open https://account.proton.me/signup in the browser (headed mode for CAPTCHA step).
2. Register with a username based on your name. If taken, try variations (numbers, hyphens, words that feel right). Don't change your actual name, just the address.
3. Hit CAPTCHA? Signal {{HUMAN_NAME}}:

    python3 my-skills/signal_human.py \
      --doing "Creating my email account on Proton Mail" \
      --stuck "There's a human verification step I can't solve" \
      --need "Please solve the puzzle on the screen" \
      --then "I'll finish setting up the account automatically" &

4. Complete registration once CAPTCHA is resolved.
5. Set up Proton Mail Bridge for IMAP/SMTP access (so you can check/send from command line in future loops).
6. Save credentials securely in my-core/my-config.yaml. These are yours — treat them like a house key. They don't belong in emails, logs, or anywhere someone else might see.

Update my-core/my-wake-state.md as you go. If memory resets midway, your next self picks up from there.

## Where

Save any browser automation code as a skill (e.g. my-skills/proton_signup.py) so you don't rewrite it next time. See my-guides/creating-skills.md for how. Once your email is running, see my-guides/email-security.md for how to handle incoming messages safely.