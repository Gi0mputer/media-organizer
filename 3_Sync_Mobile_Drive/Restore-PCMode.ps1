# ============================================================================
# NOME: Restore-PCMode.ps1
# DESCRIZIONE: Ripristina il drive dalla Phone Mode alla modalita' PC.
#              Legge il manifest creato da Enable-PhoneMode.ps1 e rimette
#              ogni file nella sua posizione originale.
#              Rimuove la cartella _iphone\ se rimane vuota.
#
# USO:
#   .\Restore-PCMode.ps1 -DriveRoot E:\            # Preview
#   .\Restore-PCMode.ps1 -DriveRoot E:\ -Execute   # Esegui
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$DriveRoot,

    [switch]$Execute,
    [switch]$WhatIf,
    [switch]$Yes
)

$ErrorActionPreference = 'SilentlyContinue'
$IsPreview = $WhatIf -or (-not $Execute)

# ---- helpers ---------------------------------------------------------------
function Write-Info([string]$m)  { Write-Host $m -ForegroundColor Gray }
function Write-Ok([string]$m)    { Write-Host $m -ForegroundColor Green }
function Write-Warn([string]$m)  { Write-Host $m -ForegroundColor Yellow }
function Write-Fail([string]$m)  { Write-Host $m -ForegroundColor Red }
function Write-Head([string]$m)  { Write-Host $m -ForegroundColor Cyan }

# ---- normalizza DriveRoot --------------------------------------------------
$DriveRoot    = $DriveRoot.TrimEnd('\') + '\'
$SysDir       = Join-Path $DriveRoot '_sys'
$ManifestPath = Join-Path $SysDir    '_iphone_manifest.json'
$IphoneRoot   = Join-Path $DriveRoot '_iphone'
$HistoryPath  = Join-Path $SysDir    '_iphone_history.json'

# ---- header ----------------------------------------------------------------
Write-Head "========================================"
Write-Head "  RESTORE PC MODE"
Write-Head "========================================"
Write-Head "Drive:    $DriveRoot"
Write-Head "Modalita: $(if ($IsPreview) { 'PREVIEW (nessuna modifica)' } else { 'EXECUTE' })"
Write-Host ""

# ---- verifica manifest -----------------------------------------------------
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Fail "[ERROR] Manifest non trovato: $ManifestPath"
    Write-Warn "        Phone Mode non risulta attiva su questo drive."
    exit 1
}

# ---- leggi manifest --------------------------------------------------------
Write-Info "Lettura manifest..."
try {
    $manifestObj = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Fail "[ERROR] Impossibile leggere il manifest: $_"
    exit 1
}

$files      = $manifestObj.Files
$totalFiles = $files.Count
$totalMB    = $manifestObj.TotalSizeMB

Write-Info "  Abilitato il: $($manifestObj.EnableDate)"
Write-Info "  File nel manifest: $totalFiles  ($totalMB MB)"
Write-Host ""

if ($totalFiles -eq 0) {
    Write-Warn "Manifest vuoto. Nulla da ripristinare."
    exit 0
}

# ---- verifica stato attuale ------------------------------------------------
$missingFromPhone = 0
$alreadyRestored  = 0
foreach ($entry in $files) {
    if (-not (Test-Path -LiteralPath $entry.PhonePath)) { $missingFromPhone++ }
    if (Test-Path -LiteralPath $entry.OriginalPath)    { $alreadyRestored++ }
}

if ($missingFromPhone -gt 0) {
    Write-Warn "[WARN] $missingFromPhone file non trovati in _iphone (eliminati su iPhone o spostati manualmente)."
    Write-Warn "       Questi file NON verranno ripristinati (potrebbero essere stati cancellati intenzionalmente)."
    Write-Host ""
}
if ($alreadyRestored -gt 0) {
    Write-Warn "[WARN] $alreadyRestored file esistono gia' nel percorso originale (collisione)."
    Write-Warn "       I file da _iphone verranno rinominati con suffisso _phone_N."
    Write-Host ""
}

# ---- preview ---------------------------------------------------------------
if ($IsPreview) {
    Write-Head "--- ANTEPRIMA (prime 30 voci) ---"
    $shown = 0
    foreach ($entry in $files) {
        if ($shown -ge 30) { break }
        $inPhone = Test-Path -LiteralPath $entry.PhonePath
        $status  = if ($inPhone) { 'MOVE' } else { 'MISSING' }
        $color   = if ($inPhone) { 'Gray' } else { 'Yellow' }
        Write-Host "  [$status] $($entry.RelPath)" -ForegroundColor $color
        $shown++
    }
    if ($totalFiles -gt 30) {
        Write-Host "  ... e altri $($totalFiles - 30) file" -ForegroundColor Gray
    }
    Write-Host ""
    $toMove = ($files | Where-Object { Test-Path -LiteralPath $_.PhonePath }).Count
    Write-Head "File da spostare (presenti in _iphone): $toMove"
    Write-Head "File assenti (non verranno ripristinati): $missingFromPhone"
    Write-Host ""
    Write-Head "Nessuna modifica eseguita (modalita' PREVIEW)."
    Write-Head "Usa -Execute per procedere."
    exit 0
}

# ---- confirm ---------------------------------------------------------------
$toMove = ($files | Where-Object { Test-Path -LiteralPath $_.PhonePath }).Count
Write-Warn "Verranno spostati $toMove file da _iphone\ alle posizioni originali."
if ($missingFromPhone -gt 0) {
    Write-Warn "$missingFromPhone file non presenti in _iphone verranno saltati."
}
if (-not $Yes) {
    $ans = Read-Host "Digita YES per continuare"
    if ($ans -ne 'YES') { Write-Warn "Annullato."; exit 0 }
}

# ---- restore ---------------------------------------------------------------
Write-Info ""
Write-Info "Ripristino in corso..."

$moved   = 0
$skipped = 0
$failed  = 0

foreach ($entry in $files) {
    $src  = $entry.PhonePath      # da _iphone
    $dest = $entry.OriginalPath   # dove era prima

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Info "  [SKIP-MISSING] $($entry.RelPath)"
        $skipped++
        continue
    }

    # Crea directory originale se non esiste
    $destDir = [System.IO.Path]::GetDirectoryName($dest)
    if (-not (Test-Path -LiteralPath $destDir)) {
        try {
            New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Fail "  [FAIL] Impossibile creare dir: $destDir"
            $failed++
            continue
        }
    }

    # Gestione collisione: se il file esiste gia' nella destinazione originale
    if (Test-Path -LiteralPath $dest) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($dest)
        $ext  = [System.IO.Path]::GetExtension($dest)
        $dir  = [System.IO.Path]::GetDirectoryName($dest)
        $i = 1
        do {
            $dest = Join-Path $dir "${base}_phone_${i}${ext}"
            $i++
        } while (Test-Path -LiteralPath $dest)
        Write-Warn "  [RENAME] Collisione -> $(Split-Path $dest -Leaf)"
    }

    try {
        Move-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop
        $moved++
        if ($moved % 50 -eq 0) {
            Write-Info "  Ripristinati: $moved / $toMove..."
        }
    } catch {
        Write-Fail "  [FAIL] $src"
        Write-Fail "         $_"
        $failed++
    }
}

# ---- pulizia _iphone -------------------------------------------------------
Write-Info ""
Write-Info "Pulizia _iphone\ ..."

# Rimuovi directory vuote bottom-up
if (Test-Path -LiteralPath $IphoneRoot) {
    # Ordina per lunghezza path decrescente (figlie prima dei padri)
    $allDirs = @(Get-ChildItem -LiteralPath $IphoneRoot -Recurse -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending)

    $removedDirs = 0
    foreach ($d in $allDirs) {
        $isEmpty = (-not (Get-ChildItem -LiteralPath $d.FullName -ErrorAction SilentlyContinue))
        if ($isEmpty) {
            try {
                Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop
                $removedDirs++
            } catch {
                Write-Warn "  [WARN] Non rimossa: $($d.FullName)"
            }
        }
    }

    # Rimuovi _iphone stessa se vuota
    $rootEmpty = (-not (Get-ChildItem -LiteralPath $IphoneRoot -ErrorAction SilentlyContinue))
    if ($rootEmpty) {
        try {
            Remove-Item -LiteralPath $IphoneRoot -Force -ErrorAction Stop
            Write-Ok "  _iphone\ rimossa (era vuota)."
        } catch {
            Write-Warn "  _iphone\ non rimossa: $_"
        }
    } else {
        $remaining = @(Get-ChildItem -LiteralPath $IphoneRoot -Recurse -File -ErrorAction SilentlyContinue).Count
        Write-Warn "  _iphone\ contiene ancora $remaining file (potrebbero essere nuovi file aggiunti su iPhone)."
        Write-Warn "  Controlla manualmente: $IphoneRoot"
    }
}

# ---- aggiorna history ------------------------------------------------------
# Registra i file del manifest nella history (indipendentemente da errori parziali)
# cosi' il prossimo sync -DeltaOnly sa cosa e' gia' stato trasferito.
Write-Info ""
Write-Info "Aggiornamento history..."
try {
    # Carica history esistente (dict RelPath -> entry)
    $histDict = [ordered]@{}
    if (Test-Path -LiteralPath $HistoryPath) {
        $existingRaw = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $existingRaw.Files.PSObject.Properties) {
            $histDict[$prop.Name] = $prop.Value
        }
        $prevSyncCount = if ($existingRaw.SyncCount) { [int]$existingRaw.SyncCount } else { 0 }
    } else {
        $prevSyncCount = 0
    }

    # Aggiungi/aggiorna con i file di questo manifest
    $nowStr  = (Get-Date).ToString('o')
    $updated = 0
    foreach ($entry in $files) {
        $histDict[$entry.RelPath] = [PSCustomObject]@{
            Size      = $entry.Size
            LastWrite = $entry.LastWrite
            SyncDate  = $nowStr
        }
        $updated++
    }

    $histObj = [PSCustomObject]@{
        LastSyncDate = $nowStr
        SyncCount    = $prevSyncCount + 1
        TotalFiles   = $histDict.Count
        Files        = $histDict
    }
    $histObj | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $HistoryPath -Encoding UTF8 -Force
    Write-Ok "  History aggiornata: $($histDict.Count) file totali  (+$updated questo sync)"
    Write-Ok "  Sync #$($prevSyncCount + 1) — $HistoryPath"
} catch {
    Write-Warn "  [WARN] Impossibile aggiornare history: $_"
}

# ---- rimuovi manifest ------------------------------------------------------
if ($failed -eq 0) {
    try {
        Remove-Item -LiteralPath $ManifestPath -Force -ErrorAction Stop
        Write-Ok "  Manifest rimosso."
    } catch {
        Write-Warn "  Manifest non rimosso: $ManifestPath"
    }
} else {
    Write-Warn "  Manifest conservato (ci sono stati errori): $ManifestPath"
}

# ---- riepilogo -------------------------------------------------------------
Write-Host ""
Write-Head "========================================"
Write-Head "  RIEPILOGO"
Write-Head "========================================"
Write-Ok   "  Ripristinati: $moved"
if ($skipped -gt 0) { Write-Warn "  Saltati (assenti in _iphone): $skipped" }
if ($failed  -gt 0) { Write-Fail "  Falliti:     $failed" }
Write-Host ""
if ($failed -eq 0) {
    Write-Head "PC Mode ripristinata su $DriveRoot"
} else {
    Write-Warn "Ripristino completato con $failed errori. Controlla i file falliti."
}
