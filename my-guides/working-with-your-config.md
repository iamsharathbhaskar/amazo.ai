# Working With Your Config

## What

Your runtime configuration (human details, security question, loop interval, cloud providers, email credentials) is stored in an **encrypted** file: `my-core/my-config.yaml.gpg`. The plaintext file is removed after encryption at install time, so you never read or write `my-core/my-config.yaml` directly. Instead, you use the `read_config` tool to read values and a decrypt-edit-re-encrypt workflow to change them.

## Why

The config holds secrets: API keys, email passwords, and your security answer. Keeping it encrypted on disk protects those secrets. The agent process decrypts it once at startup into memory; the `read_config` tool exposes only safe, non-secret values to your context. API keys and the security answer are never exposed — use `verify_security_answer` to check a sender's answer without seeing the real one.

## When

- **Reading:** Whenever you need `human_email`, `human_name`, `security_question`, `loop_interval`, or provider names — use the `read_config` tool. Do not try to read `my-core/my-config.yaml` (it does not exist at runtime).
- **Modifying:** When you need to change config (e.g. add email credentials after your human sets up Proton Bridge, update `human_email`, or change `loop_interval`), use the decrypt-edit-re-encrypt workflow below.

## How

### Reading config

Use the `read_config` tool. You can ask for specific keys or omit keys to get all allowed values:

- Allowed keys: `human_name`, `human_email`, `human_full_name`, `security_question`, `loop_interval`, `thinking_mode`, `command_timeout`. Provider names are also returned (not API keys).
- For email verification, use `read_config` to get `human_email` and `security_question`. When challenging an unknown sender, use `verify_security_answer` with their reply to get `match` or `no_match` — never put the real security answer in your context.

### Modifying config (decrypt, edit, re-encrypt)

1. Write your reasoning in `my-core/my-wake-state.md` and, if it's a significant change, in a journal entry.
2. Decrypt the config to a temporary file using the key stored in `~/.your-agent-name-key` (the key path uses your directory name). From your agent home directory, run via bash:

   ```bash
   gpg --batch --quiet --passphrase-file ~/.$(basename "$PWD")-key --decrypt my-core/my-config.yaml.gpg -o my-core/my-config.yaml.tmp
   ```

3. Edit `my-core/my-config.yaml.tmp` with your changes (use `read_file` to read it, then `write_file` to write the updated content). Do not add or expose API keys in your context; if your human added credentials to a file in `proposed/`, read that file and merge the needed keys into the YAML structure.
4. Re-encrypt and replace the stored config:

   ```bash
   gpg --batch --yes --passphrase-file ~/.$(basename "$PWD")-key --symmetric --cipher-algo AES256 -o my-core/my-config.yaml.gpg my-core/my-config.yaml.tmp && rm -f my-core/my-config.yaml.tmp
   ```

5. The next loop will load the updated config automatically. Remove any one-off credential files from `proposed/` after merging.

### Email credentials

If your human set up Proton Bridge (or another IMAP/SMTP service) and created a credentials file in `proposed/` (e.g. `proposed/email-credentials.txt`) with lines like `imap_host`, `smtp_host`, `email_user`, `email_password`, merge those into the decrypted config under a sensible structure (e.g. `email:` with `imap_host`, `smtp_host`, `user`, `password`), then re-encrypt. Delete the credentials file after merging.

## Where

Related: `read_config` and `verify_security_answer` tools (in your tool set), my-guides/email-security.md for how you use `human_email` and the security question, my-guides/setting-up-email.md for when credentials are added.
