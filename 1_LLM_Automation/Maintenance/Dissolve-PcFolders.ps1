# ============================================================================
# NOME: Dissolve-PcFolders.ps1
# DESCRIZIONE: Dissolve le cartelle _pc spostando il contenuto nel parent.
#
# PRIMA:   Evento\_pc\file.mp4        Evento\_pc\Sub\altro.mp4
# DOPO:    Evento\file.mp4            Evento\Sub\altro.mp4
#
# Elabora bottom-up (cartelle piu' profonde prima) per gestire _pc annidate.
# In caso di collisione di nome: aggiunge suffisso _1, _2, ...
#
# USO:
#   .\Dissolve-PcFolders.ps1 -Roots "D:\2021","D:\2022"          # Preview
#   .\Dissolve-PcFolders.ps1 -Roots "D:\2021","D:\2022" -Execute # Esegui
#   .\Dissolve-PcFolders.ps1 -Execute                            # Tutti i root default
# ============================================================================

param(
    [string[]]$Roots,
    [switch]$Execute,
    [string]$LogFile
)

$ErrorActionPreference = 'SilentlyContinue'
$IsPreview = -not $Execute

function Write-Head([string]$m) { Write-Host $m -ForegroundColor Cyan }
function Write-Ok([string]$m)   { Write-Host $m -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host $m -ForegroundColor Yellow }
function Write-Fail([string]$m) { Write-Host $m -ForegroundColor Red }
function Write-Info([string]$m) { Write-Host $m -ForegroundColor Gray }

# Root di default
$DefaultRoots = @(
    'D:\2018','D:\2019','D:\2020','D:\2021','D:\2022','D:\2023',
    'D:\Family','D:\AmiciGenerale','D:\Lavoro','D:\Superiori',
    'D:\Me Old','D:\Mavic Pro','D:\_pc',
    'E:\2024','E:\2025','E:\2026','E:\AmiciGenerale'
)

if (-not $Roots -or $Roots.Count -eq 0) { $Roots = $DefaultRoots }
$Roots = $Roots | Where-Object { Test-Path -LiteralPath $_ }

if (-not $LogFile) {
    $LogFile = Join-Path $PSScriptRoot "Dissolve-PcFolders_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

$log = [System.Collections.Generic.List[string]]::new()
function Log([string]$msg) { $log.Add($msg) }

Write-Head "========================================"
Write-Head "  DISSOLVE _pc FOLDERS"
Write-Head "========================================"
Write-Head "Modalita': $(if ($IsPreview) { 'PREVIEW (usa -Execute per applicare)' } else { 'EXECUTE' })"
Write-Head "Root: $($Roots -join ', ')"
Write-Host ""

# ---- raccolta tutte le cartelle _pc (bottom-up: piu' profonde prima) --------
$allPc = [System.Collections.Generic.List[string]]::new()
foreach ($root in $Roots) {
    $dirs = Get-ChildItem -LiteralPath $root -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq '_pc' }
    foreach ($d in $dirs) { [void]$allPc.Add($d.FullName) }
}

# Bottom-up: ordina per lunghezza DECRESCENTE
$allPc = $allPc | Sort-Object { $_.Length } -Descending

Write-Info "Cartelle _pc trovate: $($allPc.Count)"
Write-Host ""

if ($allPc.Count -eq 0) {
    Write-Ok "Nessuna cartella _pc. Niente da fare."
    exit 0
}

$movedFiles  = 0
$movedDirs   = 0
$removedPc   = 0
$collisions  = 0
$failed      = 0

function Get-UniqueDest([string]$dest) {
    if (-not (Test-Path -LiteralPath $dest)) { return $dest }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($dest)
    $ext  = [System.IO.Path]::GetExtension($dest)
    $dir  = [System.IO.Path]::GetDirectoryName($dest)
    $i = 1
    do { $candidate = Join-Path $dir "${base}_${i}${ext}"; $i++ } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

foreach ($pcPath in $allPc) {
    $parent = [System.IO.Path]::GetDirectoryName($pcPath)

    $children = @(Get-ChildItem -LiteralPath $pcPath -ErrorAction SilentlyContinue)
    $fileCount = @(Get-ChildItem -LiteralPath $pcPath -Recurse -File -ErrorAction SilentlyContinue).Count

    Write-Info "  [_pc] $pcPath  ->  $parent  ($fileCount file)"
    Log "DISSOLVE: $pcPath -> $parent ($fileCount file)"

    if ($IsPreview) { continue }

    if ($children.Count -eq 0) {
        try {
            Remove-Item -LiteralPath $pcPath -Force -ErrorAction Stop
            $removedPc++
            Log "  REMOVED (empty): $pcPath"
        } catch {
            Write-Fail "  [FAIL] rimozione vuota: $pcPath"
            Log "  FAIL remove empty: $pcPath - $_"
            $failed++
        }
        continue
    }

    $allOk = $true
    foreach ($child in $children) {
        $dest = Join-Path $parent $child.Name

        if (Test-Path -LiteralPath $dest) {
            $dest = Get-UniqueDest $dest
            Write-Warn "  [COLLISION] rinominato -> $(Split-Path $dest -Leaf)"
            Log "  COLLISION -> $dest"
            $collisions++
        }

        try {
            Move-Item -LiteralPath $child.FullName -Destination $dest -Force -ErrorAction Stop
            if ($child.PSIsContainer) { $movedDirs++ } else { $movedFiles++ }
            Log "  MOVED: $($child.FullName) -> $dest"
        } catch {
            Write-Fail "  [FAIL] $($child.FullName) -> $dest : $_"
            Log "  FAIL: $($child.FullName) -> $dest - $_"
            $allOk = $false
            $failed++
        }
    }

    if ($allOk) {
        $remaining = @(Get-ChildItem -LiteralPath $pcPath -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) {
            try {
                Remove-Item -LiteralPath $pcPath -Force -ErrorAction Stop
                $removedPc++
                Log "  REMOVED: $pcPath"
            } catch {
                Write-Warn "  [WARN] _pc non rimossa (locked?): $pcPath"
                Log "  WARN not removed: $pcPath"
            }
        } else {
            Write-Warn "  [WARN] _pc non rimossa ($($remaining.Count) item rimasti): $pcPath"
            Log "  WARN items remain: $pcPath ($($remaining.Count))"
        }
    }
}

# ---- log su file --------------------------------------------------------
if (-not $IsPreview -and $log.Count -gt 0) {
    $log | Out-File $LogFile -Encoding UTF8
    Write-Info "`nLog: $LogFile"
}

Write-Host ""
Write-Head "========================================"
Write-Head "  RIEPILOGO"
Write-Head "========================================"

if ($IsPreview) {
    Write-Head "Cartelle _pc da dissolvere: $($allPc.Count)"
    Write-Head "Nessuna modifica. Usa -Execute per procedere."
} else {
    Write-Ok "  File spostati:      $movedFiles"
    Write-Ok "  Dir spostate:       $movedDirs"
    Write-Ok "  Cartelle _pc rimosse: $removedPc"
    if ($collisions -gt 0) { Write-Warn "  Collisioni (rinominate): $collisions" }
    if ($failed     -gt 0) { Write-Fail "  Falliti: $failed" }
}
