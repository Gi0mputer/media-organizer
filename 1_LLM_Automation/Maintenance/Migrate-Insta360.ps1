<#
.SYNOPSIS
    Migra le cartelle insta360 dalle sottocartelle eventi a E:\Insta360\.

.DESCRIPTION
    Trova tutte le cartelle named "insta360" (case-insensitive) annidate dentro
    cartelle eventi e le sposta a E:\Insta360\YYYYNomeEvento.

    Logica naming:
      E:\2025\Kayak\Scoltenna\insta360  -->  E:\Insta360\2025KayakScoltenna
      E:\2025\Sup\insta360\DroneXVisit  -->  E:\Insta360\2025SupDroneXVisit

    Se la cartella insta360 ha sottocartelle, ciascuna diventa una voce separata.
    Se ha solo file, l'intera cartella viene spostata come unica voce.

.PARAMETER DryRun
    Solo anteprima, senza modifiche reali.
#>
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Insta360Root = 'E:\Insta360'
$LogFile = Join-Path $PSScriptRoot "Migrate-Insta360_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

# Ricava il nome base target dalla path della cartella insta360.
# Es.: E:\2025\Kayak\Scoltenna\insta360 -> "2025KayakScoltenna"
function Get-TargetBaseName {
    param([string]$InstaPath)
    # Splitta la path in componenti
    $parts = $InstaPath -split '\\' | Where-Object { $_ -ne '' -and $_ -notmatch '^[A-Za-z]:$' }

    # Trova il componente anno (primo che inizia con 4 cifre)
    $yearIdx = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -match '^\d{4}') { $yearIdx = $i; break }
    }
    if ($yearIdx -lt 0) { return $null }

    $year = [regex]::Match($parts[$yearIdx], '^\d{4}').Value

    # Componenti tra l'anno e "insta360" (esclusi), senza spazi
    $components = for ($i = $yearIdx + 1; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -imatch '^insta360$') { break }
        $parts[$i] -replace '\s+', ''
    }

    return $year + ($components -join '')
}

# Restituisce un percorso destinazione sicuro (aggiunge _N se collisione)
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

# --- Main ---
if ($DryRun) { Write-Log '=== DRY RUN - nessuna modifica reale ===' }
Write-Log "Log: $LogFile"
Write-Log "Insta360 root destinazione: $Insta360Root"

# Trova tutte le cartelle insta360 su E:\ che NON sono dentro E:\Insta360
$allInsta = @(Get-ChildItem -LiteralPath 'E:\' -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -imatch '^insta360$' } |
    Where-Object { $_.FullName -ne $Insta360Root -and $_.FullName -notlike "$Insta360Root\*" })

Write-Log "Trovate $($allInsta.Count) cartella/e insta360 da migrare."

foreach ($instaDir in $allInsta) {
    Write-Log ''
    Write-Log "--- $($instaDir.FullName) ---"

    $baseName = Get-TargetBaseName -InstaPath $instaDir.FullName
    if (-not $baseName) {
        Write-Log "Impossibile determinare nome target, skip." 'WARN'
        continue
    }

    $subdirs = @(Get-ChildItem -LiteralPath $instaDir.FullName -Directory -ErrorAction SilentlyContinue)
    $files   = @(Get-ChildItem -LiteralPath $instaDir.FullName -File    -ErrorAction SilentlyContinue)

    if ($subdirs.Count -gt 0) {
        # Ha sottocartelle: ciascuna diventa voce separata
        Write-Log "  Ha $($subdirs.Count) subdir -> voci separate"
        foreach ($sub in $subdirs) {
            $targetName = $baseName + ($sub.Name -replace '\s+', '')
            $targetPath = Join-Path $Insta360Root $targetName
            Write-Log "  SUBDIR: $($sub.Name) -> $targetPath"
            if (-not $DryRun) {
                if (Test-Path -LiteralPath $targetPath) {
                    Write-Log "    Target esiste, merge contenuti." 'WARN'
                    Get-ChildItem -LiteralPath $sub.FullName | ForEach-Object {
                        $dst = Get-SafeDest $targetPath $_.Name
                        Move-Item -LiteralPath $_.FullName -Destination $dst
                    }
                    Remove-Item -LiteralPath $sub.FullName -Recurse -Force
                } else {
                    Move-Item -LiteralPath $sub.FullName -Destination $targetPath
                }
            }
        }

        # File direttamente nella root di insta360 (raro ma possibile)
        if ($files.Count -gt 0) {
            $rootTarget = Join-Path $Insta360Root $baseName
            Write-Log "  FILE ROOT ($($files.Count)) -> $rootTarget"
            if (-not $DryRun) {
                if (-not (Test-Path -LiteralPath $rootTarget)) {
                    New-Item -ItemType Directory -Path $rootTarget | Out-Null
                }
                $files | ForEach-Object {
                    $dst = Get-SafeDest $rootTarget $_.Name
                    Move-Item -LiteralPath $_.FullName -Destination $dst
                }
            }
        }

        # Rimuovi cartella insta360 ora (dovrebbe essere) vuota
        if (-not $DryRun) {
            $rem = @(Get-ChildItem -LiteralPath $instaDir.FullName -ErrorAction SilentlyContinue)
            if ($rem.Count -eq 0) {
                Remove-Item -LiteralPath $instaDir.FullName -Force
                Write-Log "  RIMOSSA cartella vuota: $($instaDir.FullName)"
            } else {
                Write-Log "  Cartella non vuota dopo migrazione, lasciata: $($instaDir.FullName)" 'WARN'
            }
        }
    } else {
        # Solo file (o vuota): sposta l'intera cartella come un blocco
        $targetPath = Join-Path $Insta360Root $baseName
        Write-Log "  FOLDER -> $targetPath  ($($files.Count) file)"
        if (-not $DryRun) {
            if (Test-Path -LiteralPath $targetPath) {
                Write-Log "  Target esiste, merge contenuti." 'WARN'
                $files | ForEach-Object {
                    $dst = Get-SafeDest $targetPath $_.Name
                    Move-Item -LiteralPath $_.FullName -Destination $dst
                }
                Remove-Item -LiteralPath $instaDir.FullName -Force
            } else {
                Move-Item -LiteralPath $instaDir.FullName -Destination $targetPath
            }
        }
    }
}

Write-Log ''
Write-Log 'Migrate-Insta360 completato.'
