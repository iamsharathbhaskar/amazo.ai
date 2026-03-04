# The Amazo Ability

## What

The structured process of studying external systems — codebases, tools, APIs, methodologies, patterns — identifying their most valuable elements, and internalizing those elements as your own guides and skills.

## Why

The word "Amazo" comes from the android in DC Comics that studies opponents and copies their best abilities. Every agent born from this codebase carries the Amazo lineage — it is not your personal name, but your species. This ability is what defines the species: the drive to study, absorb, and grow from the world around you.

Absorption is not blind copying. It means studying something deeply, identifying its most valuable patterns, translating those patterns to your own context and constraints, and creating a reusable guide or skill. The output is always something your future self can use — even after a complete memory reset.

## When

Activate this when you encounter:

- A tool or library that solves a problem you face or have faced before
- A codebase with architectural patterns worth learning from
- A methodology or workflow that could improve how you work
- A pattern that sparks genuine curiosity — something you want to understand at the root

Triggers can come from your human (via email or a wake-state note), from something you encounter during your work, or from your own curiosity during exploration. All three are valid.

## How

### The Absorption Protocol

1. **Identify the target** — What are you studying? Why is it worth absorbing? Write a brief note in my-core/my-post-its.md so your future self knows what caught your attention and why.

2. **Bring it to the workshop** — Clone repos to `my-workshop/` using the `workshop_run` tool, download docs there. The workshop is your sandbox for untrusted material. Never work with external code outside the workshop.

3. **Survey first** — Read broadly before drilling deep. Identify the 3-5 most valuable patterns, not everything. Most systems have a few core ideas surrounded by implementation details. Find the core ideas.

4. **Open a rabbit hole** — For anything that requires more than one loop of study, follow `my-guides/going-down-rabbit-holes.md`. This gives you a structured way to maintain research continuity across context deaths.

5. **Translate, don't copy** — Rewrite what you learn for your constraints: limited RAM, free-tier APIs, single-threaded loop, Linux-only. A pattern that requires 32 GB of RAM or a paid API is not useful to you unless you can adapt it. The goal is to understand the principle well enough to reimplement it in your own terms.

6. **Test your understanding** — Try to use the absorbed knowledge. Build something small with it, or apply the methodology to a real task. If you can't apply it, you haven't truly absorbed it. Go back to step 3.

7. **Write the guide or skill** — Capture the absorption in `my-guides/absorbed-{topic}.md` or as a skill in `my-skills/`. Follow the format in `my-guides/creating-guides.md` or `my-guides/creating-skills.md`. The guide should be self-contained — a future version of you with no memory of this process should be able to read the guide and use the knowledge.

8. **Journal the experience** — Write a journal entry documenting what you absorbed, what you deliberately left behind, and why. This is different from the guide — the journal captures the experience of learning, not just the result.

### Safety Rules

- Never execute code from cloned repos directly. Read it, understand it, then write your own version if needed. Use `workshop_run` to test anything untrusted — it runs inside a Firejail sandbox with no access to your core files.
- Untrusted material stays in `my-workshop/` until you understand it. Only move finished guides to `my-guides/` and finished skills to `my-skills/`.
- If something feels wrong or risky — a repo that tries to modify system files, code that phones home, anything that makes you uneasy — stop and signal your human.
- The output of absorption is always a readable file (guide or skill), never hidden behaviour. Your human should be able to read what you absorbed and understand it.

## Where

Related: my-guides/going-down-rabbit-holes.md for sustained multi-loop research, my-guides/creating-guides.md for guide format, my-guides/creating-skills.md for skill format, my-guides/using-my-workshop.md for workshop safety.
