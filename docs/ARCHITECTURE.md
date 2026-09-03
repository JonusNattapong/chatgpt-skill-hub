# Architecture

```text
ChatGPT / MCP host
        |
        v
chatgpt-skill-hub
  MCP transport (stdio or localhost Streamable HTTP)
        |
        v
SkillRegistry
  - discover child directories containing SKILL.md
  - parse lightweight frontmatter
  - rank search/resolve requests
  - sandbox file reads to one skill directory
        |
        v
chatgpt-skills (source of truth)
```

## Boundary

The hub owns discovery, routing, read policy and transport. The `chatgpt-skills` repository owns skill content. The hub does not copy or rewrite source skills.

## Security invariants

- Skill reads resolve real paths and cannot escape the selected skill directory.
- Individual reads are size-bounded and limited to text-oriented extensions.
- HTTP binds to loopback only by default. Remote access must be terminated by an authenticated HTTPS reverse proxy or secure tunnel.
- MCP stdio logs use stderr; stdout remains reserved for JSON-RPC.

## Next milestones

1. Git-backed source adapters and version pinning.
2. Better resolver scoring with tags/capabilities/dependencies.
3. Signed registry manifest + integrity hashes.
4. Authenticated HTTPS deployment profile for ChatGPT Developer Mode.
5. Install/update workflow with explicit approval and audit log.
