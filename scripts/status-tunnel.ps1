[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$defaultClient = Join-Path (Split-Path -Parent $projectRoot) 'ChatGPTMCP\tools\tunnel-client-v0.0.13\tunnel-client.exe'
$clientPath = if ([string]::IsNullOrWhiteSpace($env:TUNNEL_CLIENT_PATH)) { $defaultClient } else { $env:TUNNEL_CLIENT_PATH }
& $clientPath runtimes status chatgpt-skill-hub --json
if ($LASTEXITCODE -ne 0) { throw "tunnel-client status failed with exit code $LASTEXITCODE" }
