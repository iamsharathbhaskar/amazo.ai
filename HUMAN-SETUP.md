# If You Set Up Email Yourself

If you create the Proton Mail account and set up Proton Bridge for your agent (instead of the agent trying automated signup), use this flow so the agent can receive the credentials and merge them into its encrypted config.

## 1. Create the credentials file

In the agent's home directory (e.g. `~/your-agent-name`), create a file:

```
proposed/email-credentials.txt
```

Put one field per line. The agent will read this and merge into its config. Example format:

```
email_address: your-proton-address@proton.me
imap_host: 127.0.0.1
imap_port: 1143
smtp_host: 127.0.0.1
smtp_port: 1025
password: your-bridge-password-or-app-password
```

Get IMAP/SMTP host and port from the Proton Bridge app. Use the Bridge password or an app-specific password.

## 2. Tell the agent to look

So the agent notices on its next loop, add a line to:

```
my-core/my-wake-state.md
```

For example:

```
Credentials in proposed/email-credentials.txt — please merge into config.
```

The agent reads wake-state every loop. When it sees this line, it will copy the file to the workshop, inspect it (same safety as email attachments), then merge the values into its encrypted config and remove the credentials file.

## 3. After the agent processes

The agent will delete the credentials file from `proposed/` after merging. You do not need to email the agent or approve anything — this is a *delivery* from you to the agent, not an approval workflow.

## Security

- Do not commit `proposed/email-credentials.txt` or put it in version control.
- The agent is instructed to copy the file to `my-workshop/` and inspect it before use (same protocol as email attachments).
- After merging, the agent stores credentials in its encrypted config and removes the plaintext file.
