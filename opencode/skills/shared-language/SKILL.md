---
name: shared-language
description: Use when the task mentions domain language, CONTEXT.md, terminology, shared vocabulary, or when the same concepts are being explained repeatedly in different sessions. Builds and maintains a shared language document.
---

# Shared Language

Build and maintain `.opencode/CONTEXT.md` — a glossary of project-specific
terms, each defined in ONE sentence. It is a glossary and nothing else: no
design docs, no ADRs, no examples. If an entry grows beyond one sentence, move
it to a design doc and keep a one-sentence pointer here. Every conversation
that re-explains the same concept wastes tokens; the glossary replaces those
explanations with a single reference.

## When to Create or Update

1. You find yourself explaining the same concept (>2 sentences) across
   multiple messages or sessions.
2. You encounter a term the user uses that has project-specific meaning.
3. After a design discussion — capture the decisions as shared language
   entries.

## Format

`.opencode/CONTEXT.md` uses this exact format:

```markdown
# Shared Language

- `<term>`: <one-sentence definition>
- `<term>`: <one-sentence definition>
```

Each entry is **one line**. No paragraphs, no examples, no "further reading".

## How Agents Use It

Before reasoning about the codebase, scan `.opencode/CONTEXT.md`:

1. If a term appears, use its one-sentence definition directly — do not
   re-explain or expand.
2. If a concept is missing but you needed 3+ sentences to convey it, add an
   entry after the session.

Each definition replaces 5-20 sentences of repeated explanation, so the agent
spends fewer tokens re-deriving concepts.

## ADR triage

Offer an ADR only when a decision is ALL of: hard-to-reverse, surprising (a
reader would not guess it), and a real trade-off (both options cost something).
Otherwise a `.opencode/CONTEXT.md` entry suffices — do not spawn an ADR.

## Maintenance

- Keep entries to one sentence; an overgrown entry belongs in a design doc.
- Delete entries that no longer apply (removed features, renamed concepts).
- Sort alphabetically.
