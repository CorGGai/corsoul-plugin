---
description: Long-term memory for this project (Corsoul). Use whenever the task benefits from remembering across sessions — at the START of a task, recall what you already know before assuming; whenever you learn a durable fact (a decision, preference, outcome, correction, or commitment), store it. Recall and capture are YOUR job here, done by calling the corsoul_* tools.
---

# Corsoul long-term memory

This project is wired to **Corsoul**, a persistent long-term memory exposed as the `corsoul_*` MCP
tools. Recall and capture are **tool-driven — you do them**. (There is deliberately no automatic
hook floor: the free local store is a single-process PGlite database, and a second process opening
it concurrently silently loses writes, so capture runs through the one MCP-server process — i.e.
your tool calls — not a separate hook process.)

## At the start of a task — recall first

Before assuming anything you weren't just told, call:

```
corsoul_recall(scope_id=<scope>, query=<the topic>)
```

Read the returned `now` field as the current time — **never invent dates**. If it returns facts,
build on them instead of re-deriving.

## When you learn something durable — remember it

The moment a **decision**, **user preference**, **commitment**, **correction**, or **outcome**
appears, store it:

```
corsoul_remember(scope_id=<scope>, text=<the fact, DISTILLED to ONE clean statement>, type="fact")
```

One fact per call. Store **conclusions, not chatter** — don't log the turn word-for-word, and don't
re-store what a recall just returned.

## The scope (keep it stable)

Memory accumulates only if you use the **same `scope_id`** every time. Use a stable, project-specific
id — e.g. `claude-code:<this-project-name>` — and keep it identical across `corsoul_recall` /
`corsoul_remember` calls for the whole session and future sessions on this project. If the user has
set a `CORSOUL_SCOPE` (or the legacy `CORTEX_SCOPE`), use that value verbatim.
