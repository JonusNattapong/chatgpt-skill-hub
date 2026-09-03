[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot '.tunnel\config.json'
$keyPath = Join-Path $projectRoot '.tunnel\control-plane-api-key.dpapi'
$defaultClient = Join-Path (Split-Path -Parent $projectRoot) 'ChatGPTMCP\tools\tunnel-client-v0.0.13\tunnel-client.exe'
$clientPath = if ([string]::IsNullOrWhiteSpace($env:TUNNEL_CLIENT_PATH)) { $defaultClient } else { $env:TUNNEL_CLIENT_PATH }
$profileDir = Join-Path $env:APPDATA 'tunnel-client'
if (-not (Test-Path -LiteralPath $clientPath)) { throw "Tunnel client not found: $clientPath" }
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing tunnel config. Run .\scripts\setup-tunnel.ps1 first." }
if (-not (Test-Path -LiteralPath $keyPath)) { throw "Missing DPAPI runtime key. Run .\scripts\setup-tunnel.ps1 first." }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($config.tunnelId) -or [string]::IsNullOrWhiteSpace($config.organizationId)) { throw 'Tunnel config requires tunnelId and organizationId.' }
npm run build
if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
$runtimeKey = $null
try {
    $env:SKILL_HUB_RUNTIME_KEY_PATH = $keyPath
    $decoder = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if ([string]::IsNullOrWhiteSpace($decoder)) { $decoder = 'powershell.exe' }
    $decodeCommand = '$cipherText = Get-Content -LiteralPath $env:SKILL_HUB_RUNTIME_KEY_PATH -Raw; $secureKey = ConvertTo-SecureString $cipherText; [Net.NetworkCredential]::new("", $secureKey).Password'
    $runtimeKey = (& $decoder -NoLogo -NoProfile -NonInteractive -Command $decodeCommand).Trim()
    if ([string]::IsNullOrWhiteSpace($runtimeKey) -or -not $runtimeKey.StartsWith('sk-')) { throw 'The DPAPI file did not decrypt to a valid runtime API key.' }
    $env:CONTROL_PLANE_API_KEY = $runtimeKey
    $entry = (Join-Path $projectRoot 'dist\src\index.js').Replace('\','/')
    $skills = [string]$config.skillsRoot
    if ([string]::IsNullOrWhiteSpace($skills)) { $skills = Join-Path (Split-Path -Parent $projectRoot) 'chatgpt-skills' }
    $skills = ([IO.Path]::GetFullPath($skills)).Replace('\','/')
    $mcpCommand = "node `"$entry`" --stdio --skills-root `"$skills`""
    & $clientPath runtimes connect `
        --alias chatgpt-skill-hub `
        --admin-profile default `
        --profile chatgpt-skill-hub-runtime `
        --profile-dir $profileDir `
        --tunnel-id $config.tunnelId `
        --organization-id $config.organizationId `
        --runtime-api-key env:CONTROL_PLANE_API_KEY `
        --mcp-command $mcpCommand
    if ($LASTEXITCODE -ne 0) { throw "tunnel-client connect failed with exit code $LASTEXITCODE" }
    & (Join-Path $PSScriptRoot 'status-tunnel.ps1')
}
finally {
    Remove-Item Env:CONTROL_PLANE_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:SKILL_HUB_RUNTIME_KEY_PATH -ErrorAction SilentlyContinue
    $runtimeKey = $null
}
