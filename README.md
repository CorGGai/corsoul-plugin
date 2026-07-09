# Corsoul Memory — Claude Code plugin

Persistent, **4-layer cognitive long-term memory** for Claude Code. Free, offline, local (an
embedded PGLite store under `~/.corsoul/db`). One install gives Claude Code memory that survives
across sessions.

## Install

```
/plugin marketplace add CorGGai/corsoul-plugin
/plugin install corsoul-memory@corsoul
```

Restart the session. No config file to hand-edit, no API key required (semantic recall needs an
embeddings provider; without one, recall is keyword-only — run
`npx --package=corsoul corsoul setup` to pick one).

> **Prerequisite:** the free package [`corsoul`](https://www.npmjs.com/package/corsoul) is published
> on npm — the MCP server runs via `npx` with nothing to install first. (To try an unpublished local
> change, see **Local testing** below.)

## What you get (two components)

| Component | File | What it does |
|---|---|---|
| **MCP server** | `.mcp.json` | Registers `corsoul` (stdio) → the `corsoul_*` tools: remember / recall / forget / intend / due / resolve / set_core / get_core. |
| **Skill** | `skills/corsoul-memory/SKILL.md` | Tells the model to **recall on task entry** and **store durable facts** as it learns them — recall and capture are tool-driven. |

## Why capture is tool-driven, not a hook floor (important)

An earlier design added lifecycle hooks (`SessionStart`/`Stop`) that shelled out to a **separate
process** to recall/capture. That is **unsafe with the default local store**: PGLite is a
single-process in-memory Postgres image, so two processes opening the same `~/.corsoul/db` (the
long-lived MCP server **and** each hook fire) **silently lose writes** — the server serves a stale
image and its flush clobbers the hook's commit. This is an inherent property of single-process
PGLite (a per-process in-memory image flushed to disk), not a bug — so the plugin is designed around it.

So the shipped plugin keeps **exactly one process** touching the store — the MCP server — and drives
recall/capture through the model's tool calls (the skill). This is the honest, safe default. The
tradeoff: capture is model-driven (high-signal but skippable) rather than a deterministic floor.

**Roadmap (deterministic hooks, done safely):** run **one** long-lived loopback HTTP server as the
sole DB owner, point `.mcp.json` at it (`type: http`), and have hooks talk to it **over HTTP** rather
than opening PGLite themselves. That restores the recall-before / capture-after floor without the
multi-process hazard. Not shipped yet.

> If you want a deterministic recall/capture floor **today**, drive the memory from your own code as
> a single in-process owner (the SDK integration) instead of the plugin — see the
> [CorSoul-AI project](https://github.com/CorGGai/CorSoul-AI).

## Scope (which memory namespace)

Memory is namespaced by `scope_id`. Use a stable, project-specific value (e.g.
`claude-code:<project-name>`) and keep it identical across calls so memory accumulates. Set
`CORSOUL_SCOPE` in your environment if you want to pin one explicitly (the legacy `CORTEX_SCOPE` is
still honored); the skill tells the model to reuse it.

## Local testing (optional)

To try the plugin without going through the marketplace:

1. Install `corsoul` globally so it's on your `PATH`:
   ```bash
   npm i -g corsoul
   ```
2. In `.mcp.json`, temporarily replace `npx -y --package=corsoul corsoul` with just `corsoul`.
3. Load the plugin directly from this folder:
   ```bash
   claude --plugin-dir .
   ```
4. Verify: `/context` lists the `corsoul-memory` skill and the `corsoul_*` tools; tell the agent a
   durable fact, start a new session, and it should recall it. Inspect the store with
   `corsoul doctor`.

## Notes

- **Validate before publishing:** run `claude plugin validate` in this directory.
- **`npx` cold start:** the MCP server starts once per session (cached after first `npx` fetch). For
  lower latency, install `corsoul` globally.

## Alternative: MCP-only, no plugin

```
claude mcp add corsoul -- npx -y --package=corsoul corsoul
```

…or the one-command installer for any client:
`npx --package=corsoul corsoul connect claude-code --scope=<id>`.
