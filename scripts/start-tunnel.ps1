[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot '.tunnel\config.json'
$keyPath = Join-Path $projectRoot '.tunnel\control-plane-api-key.dpapi'
$defaultClient = Join-Path (Split-Path -Parent $projectRoot) 'ChatGPTMCP\tools\tunnel-client-v0.0.13\tunnel-client.exe'
$clientPath = if ([string]::IsNullOrWhiteSpace($env:TUNNEL_CLIENT_PATH)) { $defaultClient } else { $env:TUNNEL_CLIENT_PATH }
$profileDir = Join-Path $env:APPDATA 'tunnel-client'

if (-not (Test-Path -LiteralPath $clientPath -PathType Leaf)) { throw "Tunnel client not found: $clientPath" }
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Missing tunnel config. Run .\scripts\setup-tunnel.ps1 first." }

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($config.tunnelId)) { throw 'Tunnel config requires tunnelId.' }

npm run build
if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }

$hadControlPlaneKey = Test-Path Env:CONTROL_PLANE_API_KEY
$previousControlPlaneKey = $env:CONTROL_PLANE_API_KEY
$runtimeKey = $previousControlPlaneKey

try {
    if ([string]::IsNullOrWhiteSpace($runtimeKey)) {
        if (-not (Test-Path -LiteralPath $keyPath -PathType Leaf)) {
            throw "Missing DPAPI runtime key. Run .\scripts\setup-tunnel.ps1 first."
        }

        $env:SKILL_HUB_RUNTIME_KEY_PATH = $keyPath
        $decoder = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($decoder)) { $decoder = 'powershell.exe' }
        $decodeCommand = '$cipherText = (Get-Content -LiteralPath $env:SKILL_HUB_RUNTIME_KEY_PATH -Raw).Trim(); $secureKey = ConvertTo-SecureString $cipherText; [Net.NetworkCredential]::new('''' , $secureKey).Password'
        $runtimeKey = (& $decoder -NoLogo -NoProfile -NonInteractive -Command $decodeCommand).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($runtimeKey) -or -not $runtimeKey.StartsWith('sk-')) {
        throw 'No valid tunnel runtime API key is available. Re-run .\scripts\setup-tunnel.ps1 with a Runtime API key that has Tunnels Read + Use.'
    }

    $env:CONTROL_PLANE_API_KEY = $runtimeKey
    $entry = (Join-Path $projectRoot 'dist\src\index.js').Replace('\','/')
    $skills = [string]$config.skillsRoot
    if ([string]::IsNullOrWhiteSpace($skills)) { $skills = Join-Path (Split-Path -Parent $projectRoot) 'chatgpt-skills' }
    $skills = ([IO.Path]::GetFullPath($skills)).Replace('\','/')
    $mcpCommand = "node `"$entry`" --stdio --skills-root `"$skills`""

    # --tunnel-id attaches directly to the existing tunnel. Do not force an
    # admin profile here: runtime lookup only needs the runtime key.
    & $clientPath runtimes connect `
        --alias chatgpt-skill-hub `
        --profile chatgpt-skill-hub-runtime `
        --profile-dir $profileDir `
        --tunnel-id $config.tunnelId `
        --runtime-api-key env:CONTROL_PLANE_API_KEY `
        --mcp-command $mcpCommand

    if ($LASTEXITCODE -ne 0) { throw "tunnel-client connect failed with exit code $LASTEXITCODE" }
    & (Join-Path $PSScriptRoot 'status-tunnel.ps1')
}
finally {
    if ($hadControlPlaneKey) {
        $env:CONTROL_PLANE_API_KEY = $previousControlPlaneKey
    } else {
        Remove-Item Env:CONTROL_PLANE_API_KEY -ErrorAction SilentlyContinue
    }
    Remove-Item Env:SKILL_HUB_RUNTIME_KEY_PATH -ErrorAction SilentlyContinue
    $runtimeKey = $null
    $previousControlPlaneKey = $null
}
