# ============================================================================
# NOME: Enable-PhoneMode.ps1
# DESCRIZIONE: Attiva la "Phone Mode" su un hard disk.
#              Sposta i file phone-worthy in _iphone\ nella root del drive,
#              replicando l'albero originale senza le cartelle _pc.
#
# HISTORY / DELTA:
#   _iphone_history.json traccia i file gia' trasferiti su iPhone.
#   -DeltaOnly : sposta solo file nuovi o modificati dall'ultimo sync.
#   -SaveHistory: registra lo stato attuale come "gia' trasferito"
#                 (usare dopo il primo trasferimento manuale, senza -Execute).
#
# SICUREZZA:
#   - Salva il manifest PRIMA di qualsiasi move
#   - In Preview non tocca nulla
#   - Il manifest permette il restore completo via Restore-PCMode.ps1
#
# USO:
#   .\Enable-PhoneMode.ps1 -DriveRoot E:\                      # Preview tutto
#   .\Enable-PhoneMode.ps1 -DriveRoot E:\ -DeltaOnly           # Preview solo delta
#   .\Enable-PhoneMode.ps1 -DriveRoot E:\ -Execute             # Esegui tutto
#   .\Enable-PhoneMode.ps1 -DriveRoot E:\ -Execute -DeltaOnly  # Esegui solo delta
#   .\Enable-PhoneMode.ps1 -DriveRoot E:\ -SaveHistory         # Registra stato attuale
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$DriveRoot,

    [switch]$Execute,
    [switch]$WhatIf,
    [switch]$Yes,
    [switch]$DeltaOnly,
    [switch]$SaveHistory
)

$ErrorActionPreference = 'SilentlyContinue'
$IsPreview = $WhatIf -or (-not $Execute -and -not $SaveHistory)

# ---- helpers ---------------------------------------------------------------
function Write-Info([string]$m)  { Write-Host $m -ForegroundColor Gray }
function Write-Ok([string]$m)    { Write-Host $m -ForegroundColor Green }
function Write-Warn([string]$m)  { Write-Host $m -ForegroundColor Yellow }
function Write-Fail([string]$m)  { Write-Host $m -ForegroundColor Red }
function Write-Head([string]$m)  { Write-Host $m -ForegroundColor Cyan }

# Cartelle di sistema da saltare completamente
$SystemSkip = [System.Collections.Generic.HashSet[string]]([System.StringComparer]::OrdinalIgnoreCase)
@('$RECYCLE.BIN','System Volume Information','.Spotlight-V100','FOUND.000',
  '_sys','__sys','_iphone','Insta360') | ForEach-Object { [void]$SystemSkip.Add($_) }

# Contenitori di anni/temi (attraversati ma non trattati come eventi)
$ContainerFolders = [System.Collections.Generic.HashSet[string]]([System.StringComparer]::OrdinalIgnoreCase)
@('2018','2019','2020','2021','2022','2023','2024','2025','2026',
  'Family','AmiciGenerale','Insta360','Foto','_iphone') | ForEach-Object { [void]$ContainerFolders.Add($_) }

# ---- normalizza DriveRoot --------------------------------------------------
$DriveRoot    = $DriveRoot.TrimEnd('\') + '\'
$IphoneRoot   = Join-Path $DriveRoot '_iphone'
$SysDir       = Join-Path $DriveRoot '_sys'
$ManifestPath = Join-Path $SysDir    '_iphone_manifest.json'
$HistoryPath  = Join-Path $SysDir    '_iphone_history.json'

if (-not (Test-Path -LiteralPath $DriveRoot)) {
    Write-Fail "[ERROR] Drive non trovato: $DriveRoot"
    exit 1
}
if (-not (Test-Path -LiteralPath $SysDir)) {
    New-Item -ItemType Directory -Path $SysDir -Force -ErrorAction SilentlyContinue | Out-Null
}

# ---- carica history --------------------------------------------------------
function Get-HistoryDict {
    if (-not (Test-Path -LiteralPath $HistoryPath)) { return @{} }
    try {
        $raw  = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $dict = @{}
        foreach ($prop in $raw.Files.PSObject.Properties) {
            $dict[$prop.Name] = $prop.Value
        }
        return $dict
    } catch {
        Write-Warn "[WARN] Impossibile leggere history: $_"
        return @{}
    }
}

# ---- raccolta file phone-worthy --------------------------------------------
$allFiles = [System.Collections.Generic.List[object]]::new()
$dirCount = 0

function Invoke-CollectPhoneWorthy {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $script:dirCount++

    foreach ($f in @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue)) {
        $rel  = $f.FullName.Substring($DriveRoot.Length)
        $dest = Join-Path $IphoneRoot $rel
        [void]$allFiles.Add([PSCustomObject]@{
            OriginalPath = $f.FullName
            PhonePath    = $dest
            RelPath      = $rel
            Size         = $f.Length
            LastWrite    = $f.LastWriteTimeUtc.ToString('o')
        })
    }

    foreach ($sub in @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not $SystemSkip.Contains($_.Name) -and $_.Name -inotmatch '^_pc' })) {
        Invoke-CollectPhoneWorthy -Path $sub.FullName
    }
}

# ---- header ----------------------------------------------------------------
Write-Head "========================================"
if ($SaveHistory) {
    Write-Head "  SAVE HISTORY (primo trasferimento)"
} elseif ($DeltaOnly) {
    Write-Head "  ENABLE PHONE MODE  [DELTA]"
} else {
    Write-Head "  ENABLE PHONE MODE"
}
Write-Head "========================================"
Write-Head "Drive:    $DriveRoot"
if (-not $SaveHistory) {
    Write-Head "Modalita: $(if ($IsPreview) { 'PREVIEW (nessuna modifica)' } else { 'EXECUTE' })"
}
Write-Host ""

# ---- raccolta --------------------------------------------------------------
Write-Info "Raccolta file phone-worthy..."

foreach ($top in @(Get-ChildItem -LiteralPath $DriveRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { -not $SystemSkip.Contains($_.Name) })) {

    if ($ContainerFolders.Contains($top.Name)) {
        foreach ($ev in @(Get-ChildItem -LiteralPath $top.FullName -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not $SystemSkip.Contains($_.Name) -and $_.Name -inotmatch '^_pc' })) {
            Invoke-CollectPhoneWorthy -Path $ev.FullName
        }
        foreach ($f in @(Get-ChildItem -LiteralPath $top.FullName -File -ErrorAction SilentlyContinue)) {
            $rel  = $f.FullName.Substring($DriveRoot.Length)
            $dest = Join-Path $IphoneRoot $rel
            [void]$allFiles.Add([PSCustomObject]@{
                OriginalPath = $f.FullName
                PhonePath    = $dest
                RelPath      = $rel
                Size         = $f.Length
                LastWrite    = $f.LastWriteTimeUtc.ToString('o')
            })
        }
    } else {
        Invoke-CollectPhoneWorthy -Path $top.FullName
    }
}

$totalAllMB = [math]::Round(($allFiles | Measure-Object Size -Sum).Sum / 1MB, 1)
Write-Info "Cartelle visitate: $dirCount"
Write-Info "File trovati:      $($allFiles.Count)  ($totalAllMB MB)"

# ---- modalita' SaveHistory -------------------------------------------------
if ($SaveHistory) {
    Write-Host ""
    if (Test-Path -LiteralPath $HistoryPath) {
        Write-Warn "History gia' esistente: $HistoryPath"
        $ans = Read-Host "Sovrascrivere? (YES)"
        if ($ans -ne 'YES') { Write-Warn "Annullato."; exit 0 }
    }

    $filesDict = [ordered]@{}
    foreach ($f in $allFiles) {
        $filesDict[$f.RelPath] = [PSCustomObject]@{
            Size      = $f.Size
            LastWrite = $f.LastWrite
            SyncDate  = (Get-Date).ToString('o')
        }
    }
    $histObj = [PSCustomObject]@{
        LastSyncDate = (Get-Date).ToString('o')
        SyncCount    = 1
        TotalFiles   = $allFiles.Count
        Note         = 'Primo trasferimento registrato manualmente'
        Files        = $filesDict
    }
    try {
        $histObj | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $HistoryPath -Encoding UTF8 -Force
        Write-Ok ""
        Write-Ok "  History salvata: $HistoryPath"
        Write-Ok "  $($allFiles.Count) file registrati come 'gia' trasferiti'."
        Write-Ok "  I prossimi sync con -DeltaOnly porteranno solo le novita'."
    } catch {
        Write-Fail "[FATAL] Impossibile salvare history: $_"
        exit 1
    }
    exit 0
}

# ---- applica delta (se richiesto) ------------------------------------------
$manifest = $allFiles  # default: tutto

if ($DeltaOnly) {
    $history = Get-HistoryDict
    if ($history.Count -eq 0) {
        Write-Warn "[WARN] Nessuna history trovata - verranno inclusi tutti i file."
        Write-Warn "       Usa -SaveHistory dopo il primo trasferimento manuale."
    } else {
        Write-Info "History caricata: $($history.Count) file gia' trasferiti."
        $delta = [System.Collections.Generic.List[object]]::new()
        $skippedCount = 0
        foreach ($f in $allFiles) {
            if ($history.ContainsKey($f.RelPath)) {
                $h = $history[$f.RelPath]
                # Stesso file se size E lastwrite coincidono
                if ($h.Size -eq $f.Size -and $h.LastWrite -eq $f.LastWrite) {
                    $skippedCount++
                    continue
                }
                # Size o data diversa: file modificato -> re-trasferisci
            }
            [void]$delta.Add($f)
        }
        $manifest = $delta
        Write-Info "Gia' trasferiti (skip): $skippedCount"
        Write-Info "Da trasferire (delta):  $($manifest.Count)"
    }
}

$totalMB = [math]::Round(($manifest | Measure-Object Size -Sum).Sum / 1MB, 1)
Write-Host ""

if ($manifest.Count -eq 0) {
    Write-Ok "Nessun file da trasferire. iPhone e' gia' aggiornato."
    exit 0
}

# ---- verifica manifest esistente -------------------------------------------
if (-not $IsPreview) {
    if (Test-Path -LiteralPath $ManifestPath) {
        Write-Fail "[ERROR] Manifest gia' esiste: $ManifestPath"
        Write-Warn "        Phone Mode potrebbe essere gia' attiva."
        Write-Warn "        Usa Restore-PCMode.ps1 prima di riattivare."
        exit 1
    }
    if (Test-Path -LiteralPath $IphoneRoot) {
        Write-Warn "[WARN]  Cartella _iphone gia' esiste."
        if (-not $Yes) {
            $ans = Read-Host "Continuare comunque? (YES)"
            if ($ans -ne 'YES') { Write-Warn "Annullato."; exit 0 }
        }
    }
}

# ---- preview ---------------------------------------------------------------
if ($IsPreview) {
    Write-Head "--- ANTEPRIMA (prime 30 voci) ---"
    $manifest | Select-Object -First 30 | ForEach-Object {
        $sizekb = [math]::Round($_.Size / 1KB, 0)
        Write-Host "  $($_.RelPath)  [${sizekb}KB]" -ForegroundColor Gray
    }
    if ($manifest.Count -gt 30) {
        Write-Host "  ... e altri $($manifest.Count - 30) file" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Head "Totale da spostare: $($manifest.Count) file  ($totalMB MB)"
    Write-Host ""
    Write-Head "Nessuna modifica eseguita (modalita' PREVIEW)."
    Write-Head "Usa -Execute per procedere."
    exit 0
}

# ---- confirm ---------------------------------------------------------------
Write-Warn "Verranno SPOSTATI $($manifest.Count) file ($totalMB MB) in: $IphoneRoot"
Write-Warn "Il manifest sara' salvato in: $ManifestPath"
if (-not $Yes) {
    $ans = Read-Host "Digita YES per continuare"
    if ($ans -ne 'YES') { Write-Warn "Annullato."; exit 0 }
}

# ---- salva manifest PRIMA di qualsiasi move --------------------------------
Write-Info "Salvataggio manifest..."
$manifestObj = [PSCustomObject]@{
    EnableDate  = (Get-Date).ToString('o')
    DriveRoot   = $DriveRoot
    IphoneRoot  = $IphoneRoot
    IsDelta     = $DeltaOnly.IsPresent
    TotalFiles  = $manifest.Count
    TotalSizeMB = $totalMB
    Files       = $manifest
}
try {
    $manifestObj | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $ManifestPath -Encoding UTF8 -Force
    Write-Ok "  Manifest salvato: $ManifestPath"
} catch {
    Write-Fail "[FATAL] Impossibile salvare manifest. Operazione annullata."
    Write-Fail "  $_"
    exit 1
}

# ---- move ------------------------------------------------------------------
Write-Info ""
Write-Info "Spostamento file in corso..."

$moved   = 0
$failed  = 0
$skipped = 0

foreach ($entry in $manifest) {
    $src  = $entry.OriginalPath
    $dest = $entry.PhonePath

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warn "  [SKIP] Non trovato: $src"
        $skipped++
        continue
    }

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

    if (Test-Path -LiteralPath $dest) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($dest)
        $ext  = [System.IO.Path]::GetExtension($dest)
        $i    = 1
        do { $dest = Join-Path $destDir "${base}_$i${ext}"; $i++ } while (Test-Path -LiteralPath $dest)
        Write-Warn "  [RENAME] Collisione -> $dest"
    }

    try {
        Move-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop
        $moved++
        if ($moved % 50 -eq 0) { Write-Info "  Spostati: $moved / $($manifest.Count)..." }
    } catch {
        Write-Fail "  [FAIL] $src"
        Write-Fail "         $_"
        $failed++
    }
}

# ---- riepilogo -------------------------------------------------------------
Write-Host ""
Write-Head "========================================"
Write-Head "  RIEPILOGO"
Write-Head "========================================"
Write-Ok   "  Spostati: $moved"
if ($skipped -gt 0) { Write-Warn "  Skip:      $skipped" }
if ($failed  -gt 0) { Write-Fail "  Falliti:   $failed" }
Write-Host ""
Write-Head "Phone Mode ATTIVA su $DriveRoot"
Write-Head "Manifest: $ManifestPath"
Write-Head "Per ripristinare: Restore-PCMode.ps1 -DriveRoot $DriveRoot"
