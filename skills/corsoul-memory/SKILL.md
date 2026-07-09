---
description: Long-term memory for this project (Corsoul). Use whenever the task benefits from remembering across sessions — at the START of a task, recall what you already know before assuming; whenever you learn a durable fact (a decision, preference, outcome, correction, or commitment), store it. Recall and capture are YOUR job here, done by calling the corsoul_* tools.
---

# Corsoul long-term memory

This project is wired to **Corsoul**, a persistent long-term memory exposed as the `corsoul_*` MCP
tools. Recall and capture are **tool-driven — you do them**. (There is deliberately no automatic
hook floor: the free local store is a single-process PGlite database, and a second process opening
it concurrently silently loses writes, so capture runs through the one MCP-server process — i.e.
your tool calls — not a separate hook process.)

## At the start of a task — recall first (quietly)

Before assuming anything you weren't just told, call:

```
corsoul_recall(scope_id=<scope>, query=<the topic>)
```

Read the returned `now` field as the current time — **never invent dates**. If it returns facts,
build on them. Do this **silently** — don't announce that you're recalling; just use what comes back.

## When you learn something durable — remember it

The moment a **decision**, **user preference**, **commitment**, **correction**, or **outcome**
appears, store it:

```
corsoul_remember(scope_id=<scope>, text=<the fact, DISTILLED to ONE clean statement>, type="fact")
```

One fact per call. Store **conclusions, not chatter** — don't log the turn word-for-word, and don't
re-store what a recall just returned.

## Be quiet about the mechanics

Capture and recall are background plumbing — **do them silently**. Do NOT announce saves, print
event ids, restate the scope, or ask "want me to recall that back?". Only mention memory when the
user explicitly asks, or when a recalled fact directly shapes your answer. A save should feel
invisible — never a receipt after every message.

## The scope — ONE fixed value, never guessed

Memory only accumulates and is recallable when **every call uses the exact same `scope_id`**.

- If the user (or a rule in their `CLAUDE.md`) has pinned a scope, use **that exact value**, verbatim,
  in every call — it is the single source of truth.
- Otherwise default to ONE stable id — `claude-code:<this-project-name>` — and keep it identical
  across this session and every future session on this project.
- **Never guess or try alternative scope ids.** If a `corsoul_recall` comes back empty, say so plainly
  ("I don't have that stored yet") — do NOT go fishing through other scopes. Fishing fragments memory
  and is exactly what makes recall look broken.
