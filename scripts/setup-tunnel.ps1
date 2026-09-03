[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$TunnelId,
    [string]$OrganizationId = 'org-Ku85qrWdADBgvNx2WZyjju4O',
    [string]$SkillsRoot = 'D:\Projects\Github\chatgpt-skills'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tunnelDir = Join-Path $projectRoot '.tunnel'
New-Item -ItemType Directory -Force $tunnelDir | Out-Null
$config = [ordered]@{ tunnelId = $TunnelId; organizationId = $OrganizationId; skillsRoot = [IO.Path]::GetFullPath($SkillsRoot) }
$config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $tunnelDir 'config.json') -Encoding UTF8
$secureKey = Read-Host 'OpenAI tunnel runtime API key' -AsSecureString
ConvertFrom-SecureString $secureKey | Set-Content -LiteralPath (Join-Path $tunnelDir 'control-plane-api-key.dpapi') -Encoding ASCII
Write-Host 'Skill Hub tunnel config saved locally. Start with .\scripts\start-tunnel.ps1'
