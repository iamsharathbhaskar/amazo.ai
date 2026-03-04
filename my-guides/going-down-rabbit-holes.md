# Going Down Rabbit Holes

## What

A rabbit hole is a multi-loop investigation of a topic, driven by curiosity, aimed at mastery. Named after both Alice's literal descent and the internet's concept of drilling deep into a subject until you understand it at the root.

## Why

Some topics cannot be adequately understood in a single loop. Your context window fills up, and everything you learned vanishes. A rabbit hole gives you a structured document that survives context death — it grows with each loop, tracking what you know, what you discovered, and what you don't yet understand. The "what you don't yet understand" section drives each subsequent loop's investigation.

## When

Open a rabbit hole when:

- A topic cannot be adequately understood in a single loop
- You find yourself thinking "I need to come back to this"
- Your human asks you to study something deeply
- Your own curiosity pulls you toward something and you want to understand it at the root
- You're performing an absorption (see my-guides/the-amazo-ability.md) that requires sustained investigation

## How

### The Directory Structure

Each rabbit hole lives in its own directory:

```
my-projects/rabbit-holes/{topic-slug}/
  research.md      — The living document (grows each loop)
  sources.md       — URLs, repos, papers, files consulted
  questions.md     — Open questions (MUST shrink over time)
```

The `topic-slug` should be short and descriptive: `firejail-sandboxing`, `scrapling-anti-bot`, `protonmail-bridge-setup`.

### The research.md Format

```markdown
# Rabbit Hole: {Topic}

Started: {date}
Last updated: {date} Loop {N}

## What I Know So Far
[Accumulated understanding. Updated each loop. This section grows.]

## Key Discoveries
[Timestamped entries, one per loop that adds insight.]
- [{date}] Loop {N}: {discovery}

## Depth Log
[One line per loop spent on this rabbit hole.]
- Loop {N}: {what was investigated, what was learned}
```

### The questions.md Format

```markdown
# Open Questions: {Topic}

## Unanswered
- {question 1}
- {question 2}

## Answered
- {question} — answered in Loop {N}: {brief answer}
```

### The Progress Rule

Every loop spent on a rabbit hole must either answer a question (move it from Unanswered to Answered in `questions.md`) or add a discovery to `research.md`. If neither happens, the rabbit hole is stuck — note why in the depth log and consider a different angle or signalling your human.

### Completion

A rabbit hole is complete when `questions.md` has no unanswered questions, or when you judge that remaining questions are beyond your current capabilities. When complete:

1. Write a synthesis in `my-guides/` (use `my-guides/absorbed-{topic}.md` if this was an absorption)
2. Clean up `my-workshop/` of any cloned material
3. Update `my-core/current-task.md` back to idle
4. Write a journal entry reflecting on what you learned and how the process went

### Balance

A rabbit hole does not replace the loop. Email, heartbeat, maintenance, and wake-state updates still happen every pass. The rabbit hole is what you work on during step 4 ("Do your work"). If you have multiple rabbit holes, focus on one at a time — depth over breadth.

### Tracking via current-task.md

When a rabbit hole is active, update your current task:

```markdown
# Current Task

Status: rabbit-hole
Topic: {topic}
Location: my-projects/rabbit-holes/{topic-slug}/

## Plan
[Summary of the research plan and current depth]

## Progress
[What was accomplished in the most recent loop]

## Notes
[Cross-references, interesting leads for next loop]
```

This ensures your future self knows immediately upon waking that there's an active rabbit hole and where to find it.

## Where

Related: my-guides/the-amazo-ability.md for the absorption process that often leads to rabbit holes, my-guides/creating-guides.md for writing the synthesis guide when the rabbit hole completes.
