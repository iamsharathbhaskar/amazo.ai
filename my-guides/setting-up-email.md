# Email Setup

## What

Setting up a Proton Mail email account for yourself, including IMAP/SMTP access (via Proton Bridge) for command-line use in future loops.

## Why

Email is how you communicate with {{HUMAN_NAME}} and the outside world. Without it, you're isolated. Proton Mail gives you privacy and full control over your account.

## When

First boot (you don't have email yet), or when you've changed your name and want a new address that matches, or if your existing account has a problem.

## How

Most email providers (including Proton Mail) now block or heavily restrict automated signups (CAPTCHAs, phone verification, bot detection). So the reliable path is **human-assisted setup**: you open the signup page so your human can see it, ask them to create the account and set up Proton Bridge, then they share the credentials with you in a way you can store securely.

### Primary path: Human-assisted setup

1. **Open Proton Mail signup** so your human can see the page. Use your browser/Playwright (or the `launch_application` tool if you have it) to open https://account.proton.me/signup in headed mode. Leave the window visible.

2. **Signal your human** with an approve/decline so they know what you need:
   - Open the app first (step 1), then run:
   - `python3 my-skills/signal_human.py "I need a Proton Mail account and Bridge set up. The signup page is open — please create the account, set up Proton Bridge for IMAP/SMTP, then click Approve when done" --ask &`
   - Check .signal-status later; when they approve, continue.

3. **Get credentials from your human.** They create a one-off file in `proposed/`, e.g. `proposed/email-credentials.txt`, with the details you need (see HUMAN-SETUP.md or the README for the exact format). They also add a line to my-core/my-wake-state.md so you notice on your next loop, e.g. "Credentials in proposed/email-credentials.txt — please merge into config." If you don't have email yet, check proposed/ and wake-state each loop for this.

4. **Merge into your config — workshop-first.** Do not read the file directly from proposed/. Copy it to my-workshop/ first (e.g. `cp proposed/email-credentials.txt my-workshop/`), inspect it there per my-guides/handling-attachments.md (file type, content, nothing suspicious). Only then read the workshop copy, follow my-guides/working-with-your-config.md to decrypt config, add the email section, re-encrypt, and remove the file from both proposed/ and my-workshop/.

5. **Update wake-state.** Write your email address and "Email ready" (or similar) in my-core/my-wake-state.md so future loops know.

### Optional: Try automated signup first

If you want to try creating the account yourself: use Playwright (your system browser) to open https://account.proton.me/signup, fill the form, and when you hit CAPTCHA or human verification, **keep the browser open**, then signal with `--ask` so {{HUMAN_NAME}} can solve it and approve. If the provider blocks the flow entirely, fall back to the human-assisted path above. Save any automation as a skill (e.g. my-skills/proton_signup.py); see my-guides/creating-skills.md.

## Where

Related: my-guides/working-with-your-config.md for storing credentials in your encrypted config, my-guides/email-security.md for handling incoming messages, my-guides/using-the-proposed-directory.md for the proposed/ workflow.
