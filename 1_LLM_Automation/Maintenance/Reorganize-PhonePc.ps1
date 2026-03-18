<#
.SYNOPSIS
    Ribalta il paradigma _mobile/_gallery -> _pc su tutte le cartelle.

.DESCRIPTION
    Per ogni cartella (processata bottom-up, dalla piu profonda alla radice):

      1. Tutti i file/dir radice (non _mobile/_gallery/_pc/sistema) -> _pc
      2. Contenuto di _mobile -> cartella padre  (phone-worthy)
      3. Contenuto di _gallery -> cartella padre (phone-worthy)
      4. Rimuove _mobile e _gallery se vuoti

    Risultato:
      - File nella radice della cartella = contenuto phone-worthy
      - _pc/ = tutto il resto (solo PC)

    NON ricorre dentro _pc (considerato gia PC-only).
    NON processa E:\Insta360 (cartella separata gestita da Migrate-Insta360.ps1).

.PARAMETER Roots
    Array di cartelle radice da processare.
    Se omesso usa i default (tutte le cartelle note su D:\ e E:\).

.PARAMETER DryRun
    Solo anteprima, senza modifiche reali.
#>
param(
    [string[]]$Roots,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$LogFile = Join-Path $PSScriptRoot "Reorganize-PhonePc_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Cartelle di sistema: non processare, non ricorrere
$SystemSkip = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
@('$RECYCLE.BIN','System Volume Information','.Spotlight-V100',
  'FOUND.000','_sys','__sys') | ForEach-Object { [void]$SystemSkip.Add($_) }

# Cartelle speciali: non finiscono in _pc, gestite separatamente
$KeepAtRoot = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
@('_mobile','_gallery','_pc') | ForEach-Object { [void]$KeepAtRoot.Add($_) }

# Radici di default (NON includere E:\Insta360)
$DefaultRoots = @(
    'E:\2024', 'E:\2025', 'E:\2026',
    'E:\AmiciGenerale', 'E:\Foto', 'E:\Me', 'E:\_drone', 'E:\_invia', 'E:\_utili',
    'D:\2018 e pre', 'D:\2019', 'D:\2020', 'D:\2021', 'D:\2022', 'D:\2023',
    'D:\AmiciGenerale', 'D:\DroneOld', 'D:\Family', 'D:\Giulia', 'D:\Lago',
    'D:\Me(foto di me per veder ecome ero)', 'D:\Moto', 'D:\Neve', 'D:\Particelle',
    'D:\Polpo', 'D:\RicordiPizze', 'D:\Uni', 'D:\Wallpapers'
)

if (-not $Roots) { $Roots = $DefaultRoots }

# Contatori globali
$script:MovedToPC   = 0
$script:DissolvedM  = 0
$script:DissolvedG  = 0
$script:Warnings    = 0

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

# Percorso destinazione sicuro: aggiunge _N in caso di collisione
function Get-SafeDest {
    param([string]$Dir, [string]$Name)
    $dest = Join-Path $Dir $Name
    if (-not (Test-Path -LiteralPath $dest)) { return $dest }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $ext  = [System.IO.Path]::GetExtension($Name)
    $i = 1
    do { $dest = Join-Path $Dir "$base`_$i$ext"; $i++ } while (Test-Path -LiteralPath $dest)
    return $dest
}

# Dissolve tutti gli elementi di $SourceDir nella cartella $DestDir
function Dissolve-Dir {
    param([string]$SourceDir, [string]$DestDir, [string]$Label)
    if (-not (Test-Path -LiteralPath $SourceDir)) { return }

    $items = @(Get-ChildItem -LiteralPath $SourceDir -ErrorAction SilentlyContinue)
    foreach ($item in $items) {
        $dest = Get-SafeDest $DestDir $item.Name
        Write-Log "    DISSOLVE $Label : $($item.Name) -> $(Split-Path $dest -Leaf)"
        if (-not $DryRun) {
            Move-Item -LiteralPath $item.FullName -Destination $dest
        }
        if ($Label -eq '_mobile') { $script:DissolvedM++ } else { $script:DissolvedG++ }
    }

    # Rimuovi se vuota
    $rem = @(Get-ChildItem -LiteralPath $SourceDir -ErrorAction SilentlyContinue)
    if ($rem.Count -eq 0) {
        Write-Log "    RMDIR $Label : $SourceDir"
        if (-not $DryRun) { Remove-Item -LiteralPath $SourceDir -Force }
    } else {
        Write-Log "    WARN: $Label non vuota dopo dissolve: $SourceDir" 'WARN'
        $script:Warnings++
    }
}

# Processa ricorsivamente (bottom-up: prima i figli, poi il nodo corrente)
function Process-Folder {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }

    # Ricorre nei figli (esclude _pc, cartelle di sistema)
    $children = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not $SystemSkip.Contains($_.Name) -and $_.Name -ine '_pc' })

    foreach ($child in $children) {
        Process-Folder $child.FullName
    }

    # --- Processa questa cartella ---
    $mobileDir  = Join-Path $Path '_mobile'
    $galleryDir = Join-Path $Path '_gallery'
    $pcDir      = Join-Path $Path '_pc'

    $hasMobile  = Test-Path -LiteralPath $mobileDir
    $hasGallery = Test-Path -LiteralPath $galleryDir

    # Elementi radice da spostare in _pc (tutto tranne _mobile, _gallery, _pc, sistema)
    $rootItems = @(Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue |
        Where-Object { -not $SystemSkip.Contains($_.Name) -and -not $KeepAtRoot.Contains($_.Name) })

    # Se non c'e nulla da fare, salta silenziosamente
    if ($rootItems.Count -eq 0 -and -not $hasMobile -and -not $hasGallery) { return }

    Write-Log "  [$Path]"

    # Step 1: Sposta elementi radice -> _pc
    if ($rootItems.Count -gt 0) {
        if (-not (Test-Path -LiteralPath $pcDir)) {
            Write-Log "    CREATE _pc"
            if (-not $DryRun) { New-Item -ItemType Directory -Path $pcDir | Out-Null }
        }
        foreach ($item in $rootItems) {
            $dest = Get-SafeDest $pcDir $item.Name
            Write-Log "    -> _pc : $($item.Name)"
            if (-not $DryRun) { Move-Item -LiteralPath $item.FullName -Destination $dest }
            $script:MovedToPC++
        }
    }

    # Step 2: Dissolvi _mobile -> padre
    if ($hasMobile) { Dissolve-Dir $mobileDir $Path '_mobile' }

    # Step 3: Dissolvi _gallery -> padre
    if ($hasGallery) { Dissolve-Dir $galleryDir $Path '_gallery' }
}

# --- Main ---
if ($DryRun) { Write-Log '=== DRY RUN - nessuna modifica reale ===' }
Write-Log "Log: $LogFile"
Write-Log "Radici da processare: $($Roots.Count)"

foreach ($root in $Roots) {
    if (-not (Test-Path -LiteralPath $root)) {
        Write-Log "Root non trovata, skip: $root" 'WARN'
        continue
    }
    Write-Log ''
    Write-Log "=== $root ==="
    Process-Folder $root
}

Write-Log ''
Write-Log "=== RIEPILOGO ==="
Write-Log "  Spostati in _pc  : $($script:MovedToPC)"
Write-Log "  Dissolti _mobile : $($script:DissolvedM)"
Write-Log "  Dissolti _gallery: $($script:DissolvedG)"
Write-Log "  Warning          : $($script:Warnings)"
Write-Log 'Reorganize-PhonePc completato.'
