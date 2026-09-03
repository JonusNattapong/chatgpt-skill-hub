# ChatGPT Web integration

ChatGPT apps use MCP as the tool/data boundary. `chatgpt-skill-hub` already exposes the MCP tool surface; the remaining production step is making the HTTP transport reachable over authenticated HTTPS.

## Local development

```powershell
$env:SKILLS_ROOT = 'D:\Projects\Github\chatgpt-skills'
npm run start:http
```

Local endpoints:

- MCP: `http://127.0.0.1:8787/mcp`
- Health: `http://127.0.0.1:8787/health`

The built-in server intentionally refuses non-loopback binding. Do not expose it directly to the internet.

## Production shape

```text
ChatGPT Web
    | HTTPS + auth
    v
Reverse proxy / secure tunnel
    | loopback
    v
chatgpt-skill-hub :8787/mcp
    |
    v
chatgpt-skills checkout / mounted volume
```

The proxy/tunnel layer should provide TLS, authentication, rate limits, request size limits, logging and origin/host policy.

## ChatGPT Developer Mode

Once a stable HTTPS MCP URL exists, add it as a custom app/connector in ChatGPT Developer Mode and test these tools first:

1. `skill_stats`
2. `skill_search` with `accessibility`
3. `skill_read` with `a11y-debugging`
4. `skill_resolve` with a natural-language task

## Next production milestone

Add a dedicated authenticated deployment profile rather than weakening the loopback guard in `src/index.ts`. That profile can target the existing worker/tunnel infrastructure and keep the registry process private.
