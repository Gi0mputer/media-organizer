# ============================================================================
# NOME: Flatten-NestedPc.ps1
# DESCRIZIONE: Collassa le cartelle _pc annidate dentro un'altra _pc.
#
# PROBLEMA:
#   E:\2025\Elba\_pc\Sub\_pc\file.mp4        <- _pc dentro _pc, ridondante
#
# SOLUZIONE (senza cambiare il significato semantico):
#   E:\2025\Elba\_pc\Sub\file.mp4            <- Sub rimane sotto _pc, ma senza _pc interna
#
# REGOLA: dato un path con _pc antenato, rimuovi il segmento _pc dal path
#         spostando i contenuti nella cartella padre (dentro la _pc esterna).
#
# ESEMPIO:
#   Prima: Evento\_pc\Sub\_pc\altro\_pc\file.mp4
#   Dopo:  Evento\_pc\Sub\altro\file.mp4
#
# ORDINE: bottom-up (figli prima dei padri) per evitare conflitti.
#
# USO:
#   .\Flatten-NestedPc.ps1 -Roots "E:\2025","E:\2026"          # Preview
#   .\Flatten-NestedPc.ps1 -Roots "E:\2025","E:\2026" -Execute # Esegui
#   .\Flatten-NestedPc.ps1 -Execute                            # Tutti i root default
# ============================================================================

param(
    [string[]]$Roots,
    [switch]$Execute,
    [switch]$WhatIf
)

$ErrorActionPreference = 'SilentlyContinue'
$IsPreview = $WhatIf -or (-not $Execute)

function Write-Info([string]$m)  { Write-Host $m -ForegroundColor Gray }
function Write-Ok([string]$m)    { Write-Host $m -ForegroundColor Green }
function Write-Warn([string]$m)  { Write-Host $m -ForegroundColor Yellow }
function Write-Fail([string]$m)  { Write-Host $m -ForegroundColor Red }
function Write-Head([string]$m)  { Write-Host $m -ForegroundColor Cyan }

# Root di default: tutti gli anni + tematiche su E:\ e D:\
$DefaultRoots = @(
    'F:\2024','F:\2025','F:\2026',
    'F:\Foto','F:\Me','F:\stikers','F:\_drone','F:\_utili',
    'F:\AmiciGenerale','F:\Particelle','F:\Giulia',
    'D:\2018','D:\2019','D:\2020','D:\2021','D:\2022','D:\2023',
    'D:\Family','D:\AmiciGenerale'
)

if (-not $Roots -or $Roots.Count -eq 0) { $Roots = $DefaultRoots }
$Roots = $Roots | Where-Object { Test-Path -LiteralPath $_ }

Write-Head "========================================"
Write-Head "  FLATTEN NESTED _pc FOLDERS"
Write-Head "========================================"
Write-Head "Modalita': $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
Write-Head "Root: $($Roots -join ', ')"
Write-Host ""

# ---- trova tutte le _pc annidate ------------------------------------------
# Una _pc e' "annidata" se nel suo FullName esiste almeno un segmento _pc* prima di lei

function Test-HasPcAncestor {
    param([string]$FullPath)
    $parts = $FullPath -split '\\'
    # Non contare l'ultimo segmento (che e' la cartella stessa)
    for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
        if ($parts[$i] -imatch '^_pc') { return $true }
    }
    return $false
}

$allNested = [System.Collections.Generic.List[string]]::new()
foreach ($root in $Roots) {
    $dirs = Get-ChildItem -LiteralPath $root -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -imatch '^_pc' -and (Test-HasPcAncestor $_.FullName) }
    foreach ($d in $dirs) { [void]$allNested.Add($d.FullName) }
}

# Ordina per lunghezza path DECRESCENTE (bottom-up: figli prima dei padri)
$allNested = $allNested | Sort-Object { $_.Length } -Descending

Write-Info "Cartelle _pc annidate trovate: $($allNested.Count)"
Write-Host ""

if ($allNested.Count -eq 0) {
    Write-Ok "Nessuna _pc annidata. Tutto pulito."
    exit 0
}

# ---- preview / execute -----------------------------------------------------
$moved   = 0
$removed = 0
$failed  = 0

foreach ($nestedPcPath in $allNested) {
    # Calcola la destinazione: rimuovi il segmento "_pc*" dal path
    # Es: E:\2024\_pc\Copenaghen\_pc  -> dest = E:\2024\_pc\Copenaghen
    #     E:\2024\_pc\Croazia\_pc_1\drone\_pc -> dest = E:\2024\_pc\Croazia\_pc_1\drone
    $destDir = [System.IO.Path]::GetDirectoryName($nestedPcPath)

    # Cosa c'e' dentro questa _pc annidata?
    $children = @(Get-ChildItem -LiteralPath $nestedPcPath -ErrorAction SilentlyContinue)
    $fileCount = @(Get-ChildItem -LiteralPath $nestedPcPath -Recurse -File -ErrorAction SilentlyContinue).Count

    if ($IsPreview) {
        Write-Host "  [FLATTEN] $nestedPcPath" -ForegroundColor Yellow
        Write-Host "         -> $destDir  ($fileCount file)" -ForegroundColor Gray
        continue
    }

    if ($children.Count -eq 0) {
        # Cartella vuota: rimuovi direttamente
        try {
            Remove-Item -LiteralPath $nestedPcPath -Force -ErrorAction Stop
            $removed++
        } catch {
            Write-Fail "  [FAIL] Remove vuota: $nestedPcPath - $_"
            $failed++
        }
        continue
    }

    # Sposta ogni figlio diretto nella cartella padre (destDir)
    $allOk = $true
    foreach ($child in $children) {
        $childDest = Join-Path $destDir $child.Name

        # Gestione collisione
        if (Test-Path -LiteralPath $childDest) {
            if ($child.PSIsContainer) {
                # Directory esistente: merge ricorsivo (sposta contenuto dentro)
                $subItems = @(Get-ChildItem -LiteralPath $child.FullName -ErrorAction SilentlyContinue)
                foreach ($sub in $subItems) {
                    $subDest = Join-Path $childDest $sub.Name
                    if (-not (Test-Path -LiteralPath $subDest)) {
                        try {
                            Move-Item -LiteralPath $sub.FullName -Destination $subDest -Force -ErrorAction Stop
                        } catch {
                            Write-Fail "  [FAIL] Move sub: $($sub.FullName) -> $subDest : $_"
                            $allOk = $false
                        }
                    } else {
                        Write-Warn "  [COLLISION] $subDest gia' esiste, skip: $($sub.FullName)"
                    }
                }
            } else {
                # File esistente: rinomina con suffisso
                $base = [System.IO.Path]::GetFileNameWithoutExtension($childDest)
                $ext  = [System.IO.Path]::GetExtension($childDest)
                $dir  = [System.IO.Path]::GetDirectoryName($childDest)
                $i    = 1
                do { $childDest = Join-Path $dir "${base}_$i${ext}"; $i++ } while (Test-Path -LiteralPath $childDest)
                Write-Warn "  [RENAME] Collisione -> $childDest"
                try {
                    Move-Item -LiteralPath $child.FullName -Destination $childDest -Force -ErrorAction Stop
                } catch {
                    Write-Fail "  [FAIL] Move: $($child.FullName) -> $childDest : $_"
                    $allOk = $false
                }
            }
        } else {
            try {
                Move-Item -LiteralPath $child.FullName -Destination $childDest -Force -ErrorAction Stop
            } catch {
                Write-Fail "  [FAIL] Move: $($child.FullName) -> $childDest : $_"
                $allOk = $false
            }
        }
        $moved++
    }

    # Rimuovi la cartella _pc annidata se ora e' vuota
    if ($allOk) {
        $stillHas = @(Get-ChildItem -LiteralPath $nestedPcPath -ErrorAction SilentlyContinue)
        if ($stillHas.Count -eq 0) {
            try {
                Remove-Item -LiteralPath $nestedPcPath -Force -ErrorAction Stop
                $removed++
            } catch {
                Write-Warn "  [WARN] Non rimossa (non vuota o locked): $nestedPcPath"
            }
        } else {
            Write-Warn "  [WARN] Non rimossa (rimasti $($stillHas.Count) item): $nestedPcPath"
        }
    } else {
        $failed++
    }
}

Write-Host ""
Write-Head "========================================"
Write-Head "  RIEPILOGO"
Write-Head "========================================"
if ($IsPreview) {
    Write-Head "Cartelle da collassare: $($allNested.Count)"
    Write-Head "Nessuna modifica (PREVIEW). Usa -Execute per procedere."
} else {
    Write-Ok   "  Item spostati:         $moved"
    Write-Ok   "  Cartelle _pc rimosse:  $removed"
    if ($failed -gt 0) { Write-Fail "  Falliti: $failed" }
}
