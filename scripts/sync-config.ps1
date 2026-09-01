# scripts/sync-config.ps1
#
# Copy the repo's opencode/ config files to the global config directory.
# The global ~/.config/opencode is an independent copy (not a symlink), so the
# repo is the source of truth: edits must be synced here to take effect.
#
# Usage:
#   .\scripts\sync-config.ps1                           # default: repo's opencode/ dir
#   .\scripts\sync-config.ps1 -Src "D:\path\to\opencode"

param(
    [string]$Src = ""
)

if ([string]::IsNullOrEmpty($Src)) {
    $Src = Join-Path (Split-Path -Parent $PSScriptRoot) "opencode"
}
$Src = $Src.TrimEnd('\')

$dst = Join-Path $env:USERPROFILE ".config\opencode"

if (-not (Test-Path -LiteralPath $Src -PathType Container)) {
    Write-Error "Source directory not found: $Src"
    exit 1
}

# Copy every file except node_modules and package manifests: plugin
# dependencies and lockfiles belong to the global install, not the repo.
Get-ChildItem -Recurse -File -LiteralPath $Src | Where-Object {
    $rel = $_.FullName.Substring($Src.Length + 1)
    $rel -notmatch 'node_modules' -and $rel -notmatch 'package(-lock)?\.json$'
} | ForEach-Object {
    $rel = $_.FullName.Substring($Src.Length + 1)
    $target = Join-Path $dst $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
}

Write-Host "Synced $Src -> $dst"
