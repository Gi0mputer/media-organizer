# ============================================================================
# Script Name: Rename-ServiceFoldersToUnderscore.ps1
# Project: Media Archive Management
# Purpose:
#   One-time normalization of service folder names across the archive:
#     - Mobile  -> _mobile
#     - Gallery -> _gallery
#     - Trash   -> _trash
#
# Notes:
#   - Case-insensitive match (Mobile/mobile/etc).
#   - If the canonical folder already exists, contents are merged and any
#     conflicts are moved to a sibling "_CONFLICTS_FROM_<name>_<timestamp>/".
#   - Default is PREVIEW. Use -Execute -Yes to apply.
# ============================================================================

param(
    [string[]]$RootPaths = @('D:\', 'E:\'),

    [switch]$WhatIf,
    [switch]$Execute,
    [switch]$Yes
)

$ErrorActionPreference = 'SilentlyContinue'
$IsPreview = $WhatIf -or (-not $Execute)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-RepoRoot {
    param([string]$Start)
    try { return (Resolve-Path -LiteralPath (Join-Path $Start '..\..')).Path.TrimEnd('\') } catch { return (Get-Location).Path.TrimEnd('\') }
}

function Delete-DirectoryToRecycleBin {
    param([string]$Path)
    try { Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null } catch {}
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
            [Microsoft.VisualBasic.FileIO.UICancelOption]::DoNothing
        )
        return $true
    } catch { return $false }
}

function Normalize-Root([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $p = $Path.Trim()
    if ($p.Length -eq 2 -and $p[1] -eq ':') { $p += '\' }
    if (-not $p.EndsWith('\')) { $p += '\' }
    return $p
}

function Is-MarkerName([string]$Name, [string[]]$Candidates) {
    if ([string]::IsNullOrWhiteSpace($Name) -or (-not $Candidates)) { return $false }
    foreach ($c in $Candidates) { if ($Name -ieq $c) { return $true } }
    return $false
}

$rules = @(
    [pscustomobject]@{ Old = @('Mobile');  New = '_mobile'  },
    [pscustomobject]@{ Old = @('Gallery'); New = '_gallery' },
    [pscustomobject]@{ Old = @('Trash');   New = '_trash'   }
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RENAME SERVICE FOLDERS -> UNDERSCORE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
Write-Host "Roots: $($RootPaths -join ', ')" -ForegroundColor Gray
Write-Host ""

$roots = @($RootPaths | ForEach-Object { Normalize-Root $_ } | Where-Object { $_ } | Sort-Object -Unique)
if ($roots.Count -eq 0) {
    Write-Fail "[ERROR] No valid roots provided."
    exit 1
}

foreach ($r in $roots) {
    if (-not (Test-Path -LiteralPath $r)) {
        Write-Warn "[SKIP] Root not found: $r"
    }
}
$roots = @($roots | Where-Object { Test-Path -LiteralPath $_ })
if ($roots.Count -eq 0) {
    Write-Fail "[ERROR] None of the roots exist on disk."
    exit 1
}

if (-not $IsPreview -and (-not $Yes)) {
    $ans = Read-Host "Type YES to normalize service folders under: $($roots -join ', ')"
    if ($ans -ne 'YES') { Write-Warn "Cancelled."; exit 0 }
}

# Report
$repoRoot = Get-RepoRoot -Start $PSScriptRoot
$analysisDir = Join-Path $repoRoot '1_LLM_Automation\Analysis'
New-Item -ItemType Directory -Path $analysisDir -Force | Out-Null
$reportPath = Join-Path $analysisDir ("RENAME_SERVICE_FOLDERS_REPORT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$report = @()
$report += "# Rename Service Folders Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
$report += "Roots: $($roots -join ', ')"
$report += ""

$candidates = @()
foreach ($root in $roots) {
    foreach ($rule in $rules) {
        foreach ($oldName in $rule.Old) {
            $found = @()
            try {
                $rootItem = Get-Item -LiteralPath $root -ErrorAction SilentlyContinue
                if ($rootItem -and $rootItem.PSIsContainer -and (Is-MarkerName $rootItem.Name @($oldName))) { $found += $rootItem }
            } catch {}
            $found += @(Get-ChildItem -LiteralPath $root -Directory -Recurse -Filter $oldName -ErrorAction SilentlyContinue |
                Where-Object { Is-MarkerName $_.Name @($oldName) })

            foreach ($d in $found) {
                $candidates += [pscustomobject]@{
                    FullName = $d.FullName
                    OldName  = $oldName
                    NewName  = $rule.New
                }
            }
        }
    }
}

# De-dup by FullName and process deepest-first (children before parents)
$candidates = $candidates | Sort-Object -Property FullName -Unique | Sort-Object { $_.FullName.Length } -Descending

Write-Host "Folders found (to normalize): $($candidates.Count)" -ForegroundColor Cyan
$report += "## Folders found: $($candidates.Count)"
foreach ($c in $candidates) { $report += "- $($c.FullName) -> $($c.NewName)" }
$report += ""

if ($candidates.Count -eq 0) {
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Ok "[OK] Nothing to do."
    Write-Host "Report: $reportPath" -ForegroundColor Gray
    exit 0
}

$renamed = 0
$merged = 0
$conflicts = 0
$deleted = 0
$failed = 0

foreach ($c in $candidates) {
    $src = $c.FullName
    $newName = $c.NewName

    $srcItem = $null
    try { $srcItem = Get-Item -LiteralPath $src -ErrorAction SilentlyContinue } catch { $srcItem = $null }
    if (-not $srcItem -or (-not $srcItem.PSIsContainer)) { continue }

    # Already normalized?
    if ($srcItem.Name -ieq $newName) { continue }

    $parent = Split-Path -Path $srcItem.FullName -Parent
    $dest = Join-Path $parent $newName

    if (-not (Test-Path -LiteralPath $dest)) {
        if ($IsPreview) {
            Write-Info "[PREVIEW] RENAME $($srcItem.FullName) -> $dest"
            $renamed++
            continue
        }
        try {
            Rename-Item -LiteralPath $srcItem.FullName -NewName $newName -Force
            $renamed++
            continue
        } catch {
            Write-Fail "[FAIL] Rename: $($srcItem.FullName) -> $dest"
            $failed++
            continue
        }
    }

    # Merge into existing canonical folder
    $conflictDir = Join-Path $parent ("_CONFLICTS_FROM_{0}_{1}" -f $srcItem.Name, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $moveList = @()
    try { $moveList = @(Get-ChildItem -LiteralPath $srcItem.FullName -Force -ErrorAction SilentlyContinue) } catch { $moveList = @() }

    foreach ($it in $moveList) {
        $target = Join-Path $dest $it.Name
        if (Test-Path -LiteralPath $target) {
            $conflicts++
            if ($IsPreview) {
                Write-Warn "[PREVIEW] CONFLICT $($it.FullName) -> $conflictDir\\$($it.Name)"
                continue
            }
            try {
                New-Item -ItemType Directory -Path $conflictDir -Force | Out-Null
                Move-Item -LiteralPath $it.FullName -Destination (Join-Path $conflictDir $it.Name) -Force
            } catch { $failed++ }
        }
        else {
            if ($IsPreview) {
                Write-Info "[PREVIEW] MOVE $($it.FullName) -> $target"
                continue
            }
            try {
                Move-Item -LiteralPath $it.FullName -Destination $target -Force
            } catch { $failed++ }
        }
    }

    $merged++

    # Remove source folder if empty
    if (-not $IsPreview) {
        try {
            $left = @(Get-ChildItem -LiteralPath $srcItem.FullName -Force -Recurse -ErrorAction SilentlyContinue)
            if (-not $left -or $left.Count -eq 0) {
                if (Delete-DirectoryToRecycleBin -Path $srcItem.FullName) { $deleted++ } else { $failed++ }
            }
        } catch { $failed++ }
    }
    else {
        $deleted++
    }
}

$report += "## Summary"
$report += "- Renamed: $renamed"
$report += "- Merged: $merged"
$report += "- Conflicts moved aside: $conflicts"
$report += "- Source folders removed (or would remove): $deleted"
$report += "- Failed ops: $failed"
$report += ""

$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DONE" -ForegroundColor Cyan
Write-Host "Renamed: $renamed   Merged: $merged   Conflicts: $conflicts" -ForegroundColor White
Write-Host "Removed source: $deleted   Failed: $failed" -ForegroundColor White
Write-Host "Report: $reportPath" -ForegroundColor Gray

