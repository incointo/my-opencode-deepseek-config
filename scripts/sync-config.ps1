# scripts/sync-config.ps1
#
# Publish the live global config (~/.config/opencode) into this repo's
# opencode/ directory. The live config is the source of truth; the repo is a
# published mirror. Because the repo is public, opencode.json is REDACTED on
# publish: provider-level name/npm/options (apiKey, baseURL, setCacheKey) are
# stripped while models are kept. A leak guard aborts the publish if
# credential material survives redaction.
#
# Usage:
#   .\scripts\sync-config.ps1                          # live -> repo
#   .\scripts\sync-config.ps1 -WhatIf                  # preview, write nothing
#   .\scripts\sync-config.ps1 -Src "D:\path\to\opencode"              # override live dir
#   .\scripts\sync-config.ps1 -Destination "D:\path\to\repo\opencode" # override repo dir (testing)

param(
    [string]$Src = "",
    [string]$Destination = "",
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($Src)) {
    $Src = Join-Path $env:USERPROFILE ".config\opencode"
}
$Src = $Src.TrimEnd('\')

if ([string]::IsNullOrEmpty($Destination)) {
    $Destination = Join-Path (Split-Path -Parent $PSScriptRoot) "opencode"
}
$dst = $Destination.TrimEnd('\')

if (-not (Test-Path -LiteralPath $Src -PathType Container)) {
    Write-Error "Live config directory not found: $Src"
    exit 1
}
if (-not (Test-Path -LiteralPath $dst -PathType Container)) {
    Write-Error "Repo config directory not found: $dst"
    exit 1
}

# Never publish: plugin dependencies (they belong to the live install), editor
# backups, or a live opencode.jsonc -- a committed opencode.jsonc silently
# overrides opencode.json on opencode startup (config load order) and would
# resurrect the stale-override trap for anyone cloning this repo.
$excludePatterns = @(
    '(^|/)node_modules(/|$)',
    '(^|/)package(-lock)?\.json$',
    '\.bak$',
    '^opencode\.jsonc$',
    '(^|/)service\.json$'
)

$files = Get-ChildItem -Recurse -File -LiteralPath $Src | Where-Object {
    $rel = $_.FullName.Substring($Src.Length + 1) -replace '\\', '/'
    $keep = $true
    foreach ($pat in $excludePatterns) {
        if ($rel -match $pat) { $keep = $false; break }
    }
    $keep
}

$copied = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring($Src.Length + 1) -replace '\\', '/'
    $target = Join-Path $dst ($rel -replace '/', '\')

    if ($rel -eq 'opencode.json') {
        # Public repo: strip provider connection details before writing.
        $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $f.FullName | ConvertFrom-Json
        if ($json.provider) {
            foreach ($p in $json.provider.PSObject.Properties) {
                if ($p.Value -is [System.Management.Automation.PSCustomObject]) {
                    foreach ($field in @('name', 'npm', 'options')) {
                        if ($null -ne $p.Value.PSObject.Properties[$field]) {
                            $p.Value.PSObject.Properties.Remove($field)
                        }
                    }
                }
            }
        }
        $out = $json | ConvertTo-Json -Depth 100

        # Leak guard: abort rather than publish credential material. Catches
        # keys stored outside provider options by a future config revision.
        if ($out -match '"apiKey"' -or $out -match 'ark-[0-9a-f]{8}-') {
            Write-Error "Leak guard tripped: opencode.json still contains credential material after redaction. Aborting."
            exit 1
        }

        if ($WhatIf) {
            Write-Host "Would redact+write: $rel"
        } else {
            # UTF-8 without BOM: Set-Content -Encoding UTF8 emits a BOM on
            # Windows PowerShell 5.1, and JSON should not carry one.
            [IO.File]::WriteAllText($target, $out, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Redacted+written: $rel"
        }
        $copied++
        continue
    }

    if ($WhatIf) {
        Write-Host "Would copy: $rel"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
    }
    $copied++
}

# Resolve $dst to its canonical full path. Get-ChildItem reports the resolved
# long path, while a caller may pass an 8.3 short name (e.g. ADMINI~1) as
# -Destination; without this the substring arithmetic below would miscompute
# relative paths.
if (Test-Path -LiteralPath $dst -PathType Container) {
    $dst = (Get-Item -LiteralPath $dst).FullName
}

# Delete reconciliation (repo side): remove files git used to track under
# skills/agents/commands that no longer exist in the live config (e.g. a skill
# deleted from ~/.config/opencode). Only these three subdirectories are
# reconciled -- never the whole repo opencode/ dir -- so repo-only files
# outside them are left untouched.
$repoRoot = Split-Path -Parent $PSScriptRoot
$managed = @(
    git -C $repoRoot ls-files -- opencode/skills opencode/agents opencode/commands
    git -C $repoRoot log --all --diff-filter=D --name-only --pretty=format: -- opencode/skills opencode/agents opencode/commands
) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } |
    ForEach-Object { ($_ -replace '^opencode/', '') -replace '\\', '/' } |
    Sort-Object -Unique

$toDelete = @()
foreach ($dir in @('skills', 'agents', 'commands')) {
    $repoDir = Join-Path $dst $dir
    if (-not (Test-Path -LiteralPath $repoDir -PathType Container)) { continue }
    Get-ChildItem -Recurse -File -LiteralPath $repoDir | ForEach-Object {
        $rel = ($_.FullName.Substring($dst.Length + 1)) -replace '\\', '/'
        if ($managed -contains $rel) {
            $livePath = Join-Path $Src ($rel -replace '/', '\')
            if (-not (Test-Path -LiteralPath $livePath -PathType Leaf)) {
                $toDelete += $rel
            }
        }
    }
}

if ($toDelete.Count -eq 0) {
    Write-Host "No stale files to remove."
} else {
    Write-Host "Stale files to remove:"
    $toDelete | ForEach-Object { Write-Host "  $_" }
    foreach ($rel in $toDelete) {
        if ($WhatIf) {
            Write-Host "WhatIf: would remove stale: $rel"
        } else {
            Remove-Item -LiteralPath (Join-Path $dst ($rel -replace '/', '\')) -Force
            Write-Host "Removed stale: $rel"
        }
    }
}

# Validate what was published. validate-jsonc.js takes explicit file paths,
# so this also covers a -Destination override used for testing.
$validator = Join-Path $repoRoot "scripts\validate-jsonc.js"
$targets = @(Join-Path $dst "opencode.json")
if (Test-Path -LiteralPath (Join-Path $dst "dcp.jsonc") -PathType Leaf) {
    $targets += Join-Path $dst "dcp.jsonc"
}
if (Test-Path -LiteralPath $validator -PathType Leaf) {
    if ($WhatIf) {
        Write-Host "Would validate: $($targets -join ', ')"
    } else {
        & node $validator @targets
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Published config failed validation."
            exit 1
        }
    }
}

Write-Host ""
Write-Host "Published $copied file(s): $Src -> $dst"
if (-not $WhatIf) {
    Write-Host "Next: review 'git diff' in the repo, then commit and push manually."
}
