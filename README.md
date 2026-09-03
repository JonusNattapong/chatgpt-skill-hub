# ChatGPT Skill Hub

MCP registry/gateway that lets ChatGPT and other MCP hosts discover, rank and read reusable skills without stuffing every `SKILL.md` into model context.

The source of truth stays in [`JonusNattapong/chatgpt-skills`](https://github.com/JonusNattapong/chatgpt-skills). This repository is the runtime layer.

## MVP tools

| Tool | Purpose |
|---|---|
| `skill_list` | Paginated skill catalog |
| `skill_search` | Search name + description |
| `skill_resolve` | Recommend skills for a natural-language task |
| `skill_read` | Read `SKILL.md` or a referenced text file within one skill |
| `skill_sync` | Rescan the source repository |
| `skill_stats` | Registry health/count/source root |

## Requirements

- Node.js 20+
- A local checkout of `chatgpt-skills`, or set `SKILLS_ROOT` to another compatible directory

## Setup

```powershell
npm install
$env:SKILLS_ROOT = 'D:\Projects\Github\chatgpt-skills'
npm run verify
```

## Run over stdio

```powershell
npm run start:stdio
```

The default source path is `../chatgpt-skills`, so sibling checkouts work without configuration.

## Run local Streamable HTTP

```powershell
npm run start:http
# MCP:    http://127.0.0.1:8787/mcp
# Health: http://127.0.0.1:8787/health
```

The built-in HTTP server intentionally accepts loopback only. ChatGPT Web needs a remotely reachable HTTPS MCP endpoint, so production deployment should put authenticated HTTPS/tunnel infrastructure in front rather than exposing this process directly.

## Example flow

```text
User: ตรวจ accessibility เว็บนี้
  -> skill_resolve("ตรวจ accessibility เว็บนี้")
  -> a11y-debugging
  -> skill_read("a11y-debugging")
  -> model follows the loaded workflow
```

## Design

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Status

`v0.1.0` is the local registry + MCP transport baseline. GitHub source sync, version pinning, dependencies and remote auth are intentionally separate milestones.
