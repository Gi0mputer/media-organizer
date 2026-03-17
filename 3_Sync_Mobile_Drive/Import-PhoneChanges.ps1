# ============================================================================
# NOME: Import-PhoneChanges.ps1
# DESCRIZIONE: Importa le modifiche fatte su iPhone rilevando le differenze
#              tra la cartella _iphone\ (copiata da iPhone Files) e la
#              history dell'ultimo sync.
#
# PREREQUISITO: L'utente ha copiato l'albero di iPhone Files dentro _iphone\
#               sul drive, sostituendo il contenuto precedente.
#
# LOGICA DI CONFRONTO (basata su RelPath + Size + LastWrite):
#   - In _iphone\ AND in history, identico   -> skip (non modificato)
#   - In _iphone\ AND in history, diverso    -> modificato su iPhone -> aggiorna su PC
#   - In _iphone\ ma NON in history          -> nuovo da iPhone -> importa su PC
#   - In history ma ASSENTE da _iphone\      -> eliminato su iPhone -> sposta in _pc\_trash\
#
# DOVE VANNO I FILE IMPORTATI:
#   Il RelPath nel manifest indica il percorso originale su PC.
#   I file nuovi (non in history) vengono messi nella stessa struttura
#   di cartelle, nella root dell'evento (phone-worthy).
#
# USO:
#   .\Import-PhoneChanges.ps1 -DriveRoot E:\            # Preview
#   .\Import-PhoneChanges.ps1 -DriveRoot E:\ -Execute   # Esegui
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

# ---- normalizza paths ------------------------------------------------------
$DriveRoot  = $DriveRoot.TrimEnd('\') + '\'
$SysDir     = Join-Path $DriveRoot '_sys'
$IphoneRoot = Join-Path $DriveRoot '_iphone'
$HistoryPath = Join-Path $SysDir   '_iphone_history.json'

if (-not (Test-Path -LiteralPath $DriveRoot)) {
    Write-Fail "[ERROR] Drive non trovato: $DriveRoot"
    exit 1
}
if (-not (Test-Path -LiteralPath $IphoneRoot)) {
    Write-Fail "[ERROR] Cartella _iphone\ non trovata: $IphoneRoot"
    Write-Warn "        Copia prima l'albero da iPhone Files in _iphone\ sul drive."
    exit 1
}
if (-not (Test-Path -LiteralPath $HistoryPath)) {
    Write-Fail "[ERROR] History non trovata: $HistoryPath"
    Write-Warn "        Esegui prima Enable-PhoneMode con -SaveHistory."
    exit 1
}

# ---- header ----------------------------------------------------------------
Write-Head "========================================"
Write-Head "  IMPORT PHONE CHANGES"
Write-Head "========================================"
Write-Head "Drive:    $DriveRoot"
Write-Head "Modalita: $(if ($IsPreview) { 'PREVIEW (nessuna modifica)' } else { 'EXECUTE' })"
Write-Host ""

# ---- carica history --------------------------------------------------------
Write-Info "Lettura history..."
try {
    $histRaw = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $history = @{}
    foreach ($prop in $histRaw.Files.PSObject.Properties) {
        $history[$prop.Name] = $prop.Value
    }
    Write-Info "  History: $($history.Count) file  (sync #$($histRaw.SyncCount), $($histRaw.LastSyncDate.Substring(0,10)))"
} catch {
    Write-Fail "[ERROR] Impossibile leggere history: $_"
    exit 1
}

# ---- scansione _iphone\ attuale --------------------------------------------
Write-Info "Scansione _iphone\ ..."
$phoneFiles = @{}
$allPhoneItems = Get-ChildItem -LiteralPath $IphoneRoot -Recurse -File -ErrorAction SilentlyContinue
foreach ($f in $allPhoneItems) {
    $rel = $f.FullName.Substring($IphoneRoot.Length).TrimStart('\')
    $phoneFiles[$rel] = [PSCustomObject]@{
        FullPath  = $f.FullName
        RelPath   = $rel
        Size      = $f.Length
        LastWrite = $f.LastWriteTimeUtc.ToString('o')
    }
}
Write-Info "  File in _iphone\: $($phoneFiles.Count)"
Write-Host ""

# ---- calcola delta ---------------------------------------------------------
$toImportNew      = [System.Collections.Generic.List[object]]::new()  # nuovi da iPhone
$toImportModified = [System.Collections.Generic.List[object]]::new()  # modificati su iPhone
$toTrash          = [System.Collections.Generic.List[string]]::new()  # eliminati su iPhone
$unchanged        = 0

# File in _iphone\ -> confronta con history
foreach ($rel in $phoneFiles.Keys) {
    $pf = $phoneFiles[$rel]
    if ($history.ContainsKey($rel)) {
        $h = $history[$rel]
        if ($h.Size -eq $pf.Size -and $h.LastWrite -eq $pf.LastWrite) {
            $unchanged++
        } else {
            [void]$toImportModified.Add($pf)
        }
    } else {
        [void]$toImportNew.Add($pf)
    }
}

# File in history ma assenti da _iphone\ -> eliminati su iPhone
foreach ($rel in $history.Keys) {
    if (-not $phoneFiles.ContainsKey($rel)) {
        [void]$toTrash.Add($rel)
    }
}

$totalNewMB  = [math]::Round(($toImportNew      | Measure-Object Size -Sum).Sum / 1MB, 1)
$totalModMB  = [math]::Round(($toImportModified | Measure-Object Size -Sum).Sum / 1MB, 1)

Write-Head "--- RIEPILOGO DELTA ---"
Write-Ok   "  Invariati:   $unchanged"
Write-Head "  Nuovi:       $($toImportNew.Count)  ($totalNewMB MB)"
Write-Head "  Modificati:  $($toImportModified.Count)  ($totalModMB MB)"
Write-Warn "  Da eliminare (in _pc\_trash): $($toTrash.Count)"
Write-Host ""

if ($toImportNew.Count -eq 0 -and $toImportModified.Count -eq 0 -and $toTrash.Count -eq 0) {
    Write-Ok "Nessuna modifica rilevata. iPhone e PC sono allineati."
    exit 0
}

# ---- preview ---------------------------------------------------------------
if ($IsPreview) {
    if ($toImportNew.Count -gt 0) {
        Write-Head "--- NUOVI DA IPHONE (prime 15) ---"
        $toImportNew | Select-Object -First 15 | ForEach-Object {
            Write-Host "  [NEW] $($_.RelPath)  [$([math]::Round($_.Size/1KB,0))KB]" -ForegroundColor Cyan
        }
        if ($toImportNew.Count -gt 15) { Write-Host "  ... e altri $($toImportNew.Count - 15)" -ForegroundColor Gray }
        Write-Host ""
    }
    if ($toImportModified.Count -gt 0) {
        Write-Head "--- MODIFICATI SU IPHONE (prime 15) ---"
        $toImportModified | Select-Object -First 15 | ForEach-Object {
            Write-Host "  [MOD] $($_.RelPath)  [$([math]::Round($_.Size/1KB,0))KB]" -ForegroundColor Yellow
        }
        if ($toImportModified.Count -gt 15) { Write-Host "  ... e altri $($toImportModified.Count - 15)" -ForegroundColor Gray }
        Write-Host ""
    }
    if ($toTrash.Count -gt 0) {
        Write-Head "--- ELIMINATI SU IPHONE (prime 15) ---"
        $toTrash | Select-Object -First 15 | ForEach-Object {
            Write-Host "  [DEL] $_" -ForegroundColor Red
        }
        if ($toTrash.Count -gt 15) { Write-Host "  ... e altri $($toTrash.Count - 15)" -ForegroundColor Gray }
        Write-Host ""
    }
    Write-Head "Nessuna modifica eseguita (modalita' PREVIEW)."
    Write-Head "Usa -Execute per procedere."
    exit 0
}

# ---- confirm ---------------------------------------------------------------
if (-not $Yes) {
    $ans = Read-Host "Digita YES per continuare"
    if ($ans -ne 'YES') { Write-Warn "Annullato."; exit 0 }
}

# ---- esecuzione ------------------------------------------------------------
$imported  = 0
$trashed   = 0
$failed    = 0
$nowStr    = (Get-Date).ToString('o')

# 1. Importa file nuovi e modificati da _iphone\ -> posizione PC originale
foreach ($pf in ($toImportNew + $toImportModified)) {
    # Il RelPath in _iphone corrisponde al RelPath originale su PC
    $destOriginal = Join-Path $DriveRoot $pf.RelPath
    $destDir      = [System.IO.Path]::GetDirectoryName($destOriginal)

    if (-not (Test-Path -LiteralPath $destDir)) {
        try { New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null }
        catch { Write-Fail "  [FAIL] Dir: $destDir"; $failed++; continue }
    }

    # Se esiste gia' un file identico (size+lastwrite) -> skip duplicato
    if (Test-Path -LiteralPath $destOriginal) {
        $existing = Get-Item -LiteralPath $destOriginal
        if ($existing.Length -eq $pf.Size) {
            Write-Info "  [SKIP-DUP] $($pf.RelPath)"
            $unchanged++
            continue
        }
        # File diverso -> rinomina esistente in _trash prima di sovrascrivere
        $trashDir = Join-Path $destDir '_pc\_trash'
        if (-not (Test-Path -LiteralPath $trashDir)) {
            New-Item -ItemType Directory -Path $trashDir -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $trashDest = Join-Path $trashDir (Split-Path $destOriginal -Leaf)
        Move-Item -LiteralPath $destOriginal -Destination $trashDest -Force -ErrorAction SilentlyContinue
    }

    try {
        Copy-Item -LiteralPath $pf.FullPath -Destination $destOriginal -Force -ErrorAction Stop
        $imported++
        if ($imported % 20 -eq 0) { Write-Info "  Importati: $imported ..." }
    } catch {
        Write-Fail "  [FAIL] $($pf.RelPath): $_"
        $failed++
    }
}

# 2. File eliminati su iPhone -> sposta original PC in _pc\_trash\
foreach ($rel in $toTrash) {
    $originalPath = Join-Path $DriveRoot $rel
    if (-not (Test-Path -LiteralPath $originalPath)) {
        Write-Info "  [SKIP] Gia' assente su PC: $rel"
        continue
    }

    # Calcola la cartella _pc\_trash\ relativa all'evento
    # Il rel e' tipo "2025\Elba\foto.jpg" -> evento = "2025\Elba", trash = "2025\Elba\_pc\_trash"
    $parts      = $rel -split '\\'
    $eventParts = if ($parts.Count -ge 3) { $parts[0..($parts.Count-2)] } else { $parts[0..0] }
    $eventDir   = Join-Path $DriveRoot ($eventParts -join '\')
    $trashDir   = Join-Path $eventDir '_pc\_trash'

    if (-not (Test-Path -LiteralPath $trashDir)) {
        try { New-Item -ItemType Directory -Path $trashDir -Force -ErrorAction Stop | Out-Null }
        catch { Write-Fail "  [FAIL] Trash dir: $trashDir"; $failed++; continue }
    }

    $trashDest = Join-Path $trashDir (Split-Path $originalPath -Leaf)
    if (Test-Path -LiteralPath $trashDest) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($trashDest)
        $ext  = [System.IO.Path]::GetExtension($trashDest)
        $i    = 1
        do { $trashDest = Join-Path $trashDir "${base}_$i${ext}"; $i++ } while (Test-Path -LiteralPath $trashDest)
    }

    try {
        Move-Item -LiteralPath $originalPath -Destination $trashDest -Force -ErrorAction Stop
        $trashed++
    } catch {
        Write-Fail "  [FAIL] Trash $rel : $_"
        $failed++
    }
}

# ---- aggiorna history ------------------------------------------------------
Write-Info ""
Write-Info "Aggiornamento history..."
try {
    # Ricarica history corrente
    $histDict = [ordered]@{}
    foreach ($prop in $histRaw.Files.PSObject.Properties) { $histDict[$prop.Name] = $prop.Value }

    # Aggiorna con file importati/modificati
    foreach ($pf in ($toImportNew + $toImportModified)) {
        $histDict[$pf.RelPath] = [PSCustomObject]@{
            Size      = $pf.Size
            LastWrite = $pf.LastWrite
            SyncDate  = $nowStr
        }
    }
    # Rimuovi file andati in trash
    foreach ($rel in $toTrash) { $histDict.Remove($rel) }

    $histObj = [PSCustomObject]@{
        LastSyncDate = $nowStr
        SyncCount    = [int]$histRaw.SyncCount + 1
        TotalFiles   = $histDict.Count
        Files        = $histDict
    }
    $histObj | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $HistoryPath -Encoding UTF8 -Force
    Write-Ok "  History aggiornata: $($histDict.Count) file totali"
} catch {
    Write-Warn "  [WARN] Impossibile aggiornare history: $_"
}

# ---- riepilogo finale ------------------------------------------------------
Write-Host ""
Write-Head "========================================"
Write-Head "  RIEPILOGO"
Write-Head "========================================"
Write-Ok   "  Importati (nuovi/modificati): $imported"
Write-Ok   "  Spostati in _pc\_trash:       $trashed"
if ($failed -gt 0) { Write-Fail "  Falliti: $failed" }
Write-Host ""
Write-Head "Import completato su $DriveRoot"
Write-Head "Prossimo passo: rimuovi _iphone\ manualmente se non piu' necessaria"
Write-Head "  oppure ri-esegui Enable-PhoneMode -DeltaOnly per il prossimo sync."
