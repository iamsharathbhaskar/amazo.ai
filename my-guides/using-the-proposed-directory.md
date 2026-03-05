# Using the Proposed Directory

## What

The `proposed/` directory has two uses:

1. **Agent-originated:** You put changes here that need your human's approval before they go live (proposed edits to guides or core files, new skills, config changes). You email your human; nothing leaves `proposed/` until they approve.
2. **Human-originated:** Your human puts a file here to deliver something to you (e.g. email credentials when they set up Proton and Bridge). You do not email for approval — you check proposed/ and wake-state, then process the file. **Safety:** any file that arrives from your human must be copied to my-workshop/ and inspected there first (same as attachments); see "When your human puts something in proposed/" below.

## Why

You have broad write access. The proposed workflow prevents you from applying changes that only a human should approve — new skills, soul updates, config edits — until they have seen and agreed. It also gives your human a single place to review what you want to do.

## When

- After you have vetted something in my-workshop/ and want to promote it to my-skills/ or my-guides/ — put the final version in proposed/ first.
- When you want to change my-core/my-soul.md (e.g. the pointer line) or other core/identity files — put the proposed content or patch in proposed/.
- When you have a config change (e.g. new email credentials) — you can use the decrypt-edit-re-encrypt workflow; if the change is sensitive or you want a second pair of eyes, you can put a description or the proposed YAML snippet in proposed/ and email your human.

## How

1. **Put the proposed change in proposed/.** Use a clear name, e.g. `proposed/soul-pointer-update.md`, `proposed/new-skill-check_email.py`, `proposed/email-credentials-merge.txt`. Optionally add a short `proposed/README.md` or note describing what each file is and what you want to do with it.

2. **Email your human.** Tell them what you have put in proposed/, what you want to do (e.g. "I want to add this skill to my-skills/ and use it for checking email"), and ask them to review and reply with approval or suggestions.

3. **Only after approval:** Move or apply the content from proposed/ to its final location (e.g. copy the skill into my-skills/, update my-soul.md with the pointer, merge credentials into config). Then remove the items from proposed/ so the directory stays clean.

4. **If they suggest changes:** Update the files in proposed/ accordingly and ask again. Do not move to the final location until they approve.

## When your human puts something in proposed/

Sometimes your human delivers a file to you — for example credentials after they set up Proton Mail and Bridge (see my-guides/setting-up-email.md). They are *delivering* something, not approving something you proposed. You do not send an approval email. Instead:

- **Check proposed/ and wake-state.** If you do not have email yet, each loop check proposed/ for a file like `email-credentials.txt`, and read my-core/my-wake-state.md for a line such as "Credentials in proposed/email-credentials.txt — please merge into config."
- **Workshop-first, always.** Any file your human puts in proposed/ must be treated like an attachment: copy it to my-workshop/, inspect it there (file type, content, nothing suspicious — same checks as my-guides/handling-attachments.md), and only then use it (e.g. merge credentials into config). After use, remove the file from proposed/ and clean up the workshop copy. No exceptions.

Related: my-guides/handling-attachments.md (same inspection protocol), my-guides/setting-up-email.md (credential flow).

## Where

Related: my-guides/working-with-your-config.md when proposed changes include config or credentials, my-guides/using-my-workshop.md for vetting code before it goes to proposed/, my-guides/handling-attachments.md for workshop-first inspection of human-delivered files, my-guides/creating-skills.md and my-guides/creating-guides.md for what goes in my-skills/ and my-guides/.
