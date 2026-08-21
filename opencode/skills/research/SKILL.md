---
name: research
description: Use when a question needs open-ended investigation against primary sources and the findings written to a cited Markdown file — not when verifying a single, specific API against its docs before coding (that's verify-with-docs). Triggers include "research X", "look into this topic", "gather docs and facts", or delegating reading legwork to a background agent.
---

# Research

Deep, open-ended investigation against primary sources, producing a cited
Markdown report. Unlike `verify-with-docs` (single API check before coding),
research answers broad questions whose scope is still unfolding.

## When to use

- "Research how X works" / "What are the options for Y?"
- Gathering evidence before a design decision
- The question spans multiple sources and the answer is not a single fact
- Background reading legwork: spin up a subagent, keep working while it reads

## Process

### 1. Scope the question

Restate the question in one sentence. Identify what shape the answer should
take: a comparison table, a narrative report, a pros/cons list, a timeline.

### 2. Gather primary sources

Prefer, in order: official docs → source code → first-party specs → reputable
secondary sources. For each claim, follow it to the source that owns it — never
cite a secondary source that itself cites another.

Parallelize independent lookups: fetch multiple sources at once, then synthesize.

### 3. Synthesize and cite

Write findings to one Markdown file. Every factual claim carries an inline
citation: `[source](URL)` or `file:line`. Distinguish between:

- **Verified** — backed by a primary source you read
- **Reported** — from a secondary source, not independently verified
- **Inferred** — your synthesis; label it clearly

### 4. Deliver

Save the report where the repo keeps such notes; match the existing convention,
or put it somewhere sensible and say where. Report the path and a one-paragraph
summary to the caller.

## Report format

```markdown
# <Topic> — Research Notes

**Date:** YYYY-MM-DD
**Scope:** <one-sentence question>

## Key findings
- <finding> — [source](URL)
- <finding> — [source](URL)

## Detailed analysis
### <Sub-topic>
...

## Sources
1. [Title](URL) — <why authoritative>
2. [Title](URL)
```

## Rules

- Primary sources first; secondary only when primary is unreachable.
- Every claim carries a citation. Unattributed claims are guesses — label them.
- If the question grows beyond the initial scope, note it in "Out of scope"
  rather than silently expanding the report.
- Prefer a short, cited report over a long, uncited one.

Source: mattpocock/skills (MIT) — adapted and expanded.
