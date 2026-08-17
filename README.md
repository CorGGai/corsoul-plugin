# Corsoul Memory — Claude Code plugin

Persistent **local long-term memory** for Claude Code — the free, MIT L0/L1 objective-memory tier
of the Corsoul cognitive memory system (an embedded PGLite store under `~/.corsoul/db`). One
install gives Claude Code the `corsoul_*` memory tools; the model calls them to store and recall,
so what it saves persists across sessions (verify it: tell it a durable fact, start a new session,
then recall). The L2/L3 associative graph,
consolidation, and personality layers belong to the licensed engine and are not part of this
free plugin.

**One brain, many agents.** The store this plugin opens is *your* one brain — every other agent you
connect (Codex, Cursor, an HTTP gateway, more Claude Code windows) plugs into the same memory and
grows it. Concurrent sessions on one store are safe by design: since `corsoul@0.1.7` a single-owner
election makes the first session own the store and every later one bridge to it transparently — the
config says stdio, the semantics are a shared brain. Keep agents apart with different `scope_id`s
(logical isolation); a separate data dir is only for deliberately isolated brains.

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

## Versioning (plugin vs. engine)

This **plugin** (the marketplace wrapper: `.mcp.json` + skills) and the **`corsoul` engine** (the npm
package the MCP server runs) are two independent tracks — a plugin release does not imply a matching
engine release, or vice versa. The plugin keeps its own SemVer for shell/skill/config changes; each
plugin release **pins** the exact engine it ships (in `.mcp.json`), and that pinned version is also
shown in the plugin description Claude Code displays. Don't expect the two numbers to match.

| Plugin (this repo) | Pins engine (`corsoul` on npm) |
|---|---|
| **0.2.0** | `corsoul@0.1.12` (PM2 installers repaired — they had kept installing `corsoul@0.1.5` and looking for the server entrypoint under its pre-rename filename, and on Windows the launch line never reached PM2 at all. Node 22 is now the stated floor.) |
| 0.1.4 | `corsoul@0.1.7` (single-owner election — fixes multi-session WASM `Aborted()` crashes; scheduled-task memory wiring clause in claude-setup block v2) |
| 0.1.3 | `corsoul@0.1.5` |
| 0.1.2 | `corsoul@0.1.5` |
| 0.1.1 | floating latest (unpinned) |
| 0.1.0 | floating latest (unpinned) |

## What you get (two components)

| Component | File | What it does |
|---|---|---|
| **MCP server** | `.mcp.json` | Registers `corsoul` (stdio) → the `corsoul_*` tools: `remember` / `recall` / `forget` / `intend` / `due` / `resolve_intent` / `set_core` / `get_core`. |
| **Memory skill** | `skills/corsoul-memory/SKILL.md` | Tells the model to **recall on task entry** and **store durable facts** as it learns them — recall and capture are tool-driven. |
| **Connect skill** | `skills/corsoul-connect/SKILL.md` | Diagnoses a broken/missing connection, resolves duplicate servers, and guides the **shared HTTP owner** upgrade for concurrent sessions. |
| **PM2 helpers** | `scripts/install-corsoul-pm2.{ps1,sh}` | Opt-in, reviewed installers for a persistent loopback owner (`corsoul-mcp` on `127.0.0.1:3848`) with crash + reboot recovery. Never started automatically. |

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

**The same hazard applies to concurrent Claude Code sessions.** Each session spawns its own stdio
server; several sessions (windows, worktrees, background agents) against the same store are multiple
PGLite processes. If you work that way, switch to **one shared loopback HTTP owner**: run the opt-in
PM2 helper in `scripts/` (or a temporary foreground `corsoul --transport=http`), then point your
project `.mcp.json` at `http://127.0.0.1:3848/mcp` (`type: http`). The `corsoul-connect` skill walks
the model through diagnosing this and proposing the switch — it never changes your machine without
explicit consent.

**Roadmap (deterministic hooks, done safely):** with the shared HTTP owner as the sole DB owner,
hooks can talk to it **over HTTP** rather than opening PGLite themselves — restoring the
recall-before / capture-after floor without the multi-process hazard. Hook wiring not shipped yet.

> If you want a deterministic recall/capture floor **today**, drive the memory from your own code as
> a single in-process owner (the SDK integration) instead of the plugin — see the
> [CorSoul-AI project](https://github.com/CorGGai/CorSoul-AI).

## Scope (which memory namespace)

Memory is namespaced by `scope_id`. The skill resolves it deterministically: a user-pinned scope
wins; an existing scope with memories is kept as-is (continuity beats convention); otherwise
**`local:memory`** — one memory shared by every project and every agent, which is the whole point of
the product. Which project or tool a fact came from is recorded on the fact (`source`), so nothing
is lost by sharing the scope. Separate scopes cannot see each other at all and are a billed resource
(1 on the free plan, up to 30), so they are a deliberate choice — a domain under your memory, such as
`<account>:memory:work` — not something derived from a directory name.

Set `CORSOUL_SCOPE` in your environment if you want to pin one explicitly (the legacy `CORTEX_SCOPE`
is still honored); the skill tells the model to reuse it.

> Earlier versions derived `claude-code:project:<name>:v1` per directory. Those scopes keep working
> and the skill will not move them. `claude-code` is a reserved namespace, so no account can claim
> it — the same protection `local` has, and for the same reason: every plugin user's memories are
> already under it.

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

- **This repo is generated — do not edit it directly.** The plugin's source of truth is
  `corsoul-plugin/` in the engine repo, which is also what that repo's tests read; publish with
  `npm run sync:plugin` there, then commit and push here. The two copies were hand-edited in
  parallel once and drifted for weeks in both directions: the installers here went on installing
  a superseded engine while the tests over there stayed green on bytes nobody had installed.
- **Validate before publishing:** run `claude plugin validate` in this directory.
- **`npx` cold start:** the MCP server starts once per session (cached after first `npx` fetch). For
  lower latency, install `corsoul` globally.

## Alternative: MCP-only, no plugin

```
claude mcp add corsoul -- npx -y --package=corsoul corsoul
```

…or the one-command installer for any client:
`npx --package=corsoul corsoul connect claude-code --scope=<id>`.
