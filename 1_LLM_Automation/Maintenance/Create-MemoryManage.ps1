<#
.SYNOPSIS
    Crea cartelle MemoryManage con junction (link) alle cartelle foglia più pesanti.

.DESCRIPTION
    Scansiona D:\ e E:\ separatamente. Per ogni disco trova le cartelle foglia
    (senza sottocartelle) più pesanti e crea junction points in D:\MemoryManage
    e E:\MemoryManage. Esclude E:\Insta360 e cartelle di servizio (_sys, _pc, ecc).

.PARAMETER TopN
    Numero di cartelle foglia da includere (default: 20)

.PARAMETER MinSizeMB
    Dimensione minima cartella in MB per essere inclusa (default: 100)

.PARAMETER Execute
    Se specificato, crea effettivamente le junction. Altrimenti preview.

.EXAMPLE
    .\Create-MemoryManage.ps1 -Execute
    .\Create-MemoryManage.ps1 -TopN 30 -MinSizeMB 50
#>

param(
    [int]$TopN = 20,
    [int]$MinSizeMB = 100,
    [switch]$Execute
)

$excludePatterns = @('_sys', '_pc', '_trash', 'Trash', 'MemoryManage', 'FOUND.000', 'System Volume Information', '$RECYCLE.BIN')
$excludeExact    = @('E:\Insta360')

function Get-LeafFolders {
    param([string]$Root)

    $results = @()
    Get-ChildItem $Root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $top = $_
        # Salta esclusioni
        if ($excludePatterns | Where-Object { $top.Name -like "*$_*" }) { return }
        if ($excludeExact -contains $top.FullName) { return }

        # Cerca ricorsivamente le foglie
        $allDirs = Get-ChildItem $top.FullName -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $name = $_.Name; -not ($excludePatterns | Where-Object { $name -like "*$_*" }) }

        $leaves = @()
        if ($allDirs.Count -eq 0) {
            $leaves = @($top)
        } else {
            foreach ($d in $allDirs) {
                $hasSubDirs = (Get-ChildItem $d.FullName -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $n = $_.Name; -not ($excludePatterns | Where-Object { $n -like "*$_*" }) }).Count -gt 0
                if (-not $hasSubDirs) { $leaves += $d }
            }
        }

        foreach ($leaf in $leaves) {
            $files = Get-ChildItem $leaf.FullName -File -ErrorAction SilentlyContinue
            $sizeMB = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 1)
            if ($sizeMB -ge $MinSizeMB) {
                $results += [PSCustomObject]@{
                    Path   = $leaf.FullName
                    SizeMB = $sizeMB
                    Files  = $files.Count
                }
            }
        }
    }
    return $results | Sort-Object SizeMB -Descending | Select-Object -First $TopN
}

foreach ($drive in @('D:', 'E:')) {
    if (-not (Test-Path $drive)) { Write-Host "$drive non trovato, skip."; continue }

    $outDir = "$drive\MemoryManage"
    Write-Host ""
    Write-Host "=== $drive — Top $TopN cartelle foglia (min ${MinSizeMB}MB) ==="

    $leaves = Get-LeafFolders -Root $drive
    if ($leaves.Count -eq 0) { Write-Host "Nessuna cartella trovata."; continue }

    $leaves | Format-Table SizeMB, Files, Path -AutoSize

    if ($Execute) {
        # Rimuovi vecchia MemoryManage se esiste
        if (Test-Path $outDir) {
            Get-ChildItem $outDir | Remove-Item -Force -ErrorAction SilentlyContinue
        } else {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        foreach ($leaf in $leaves) {
            # Nome link: percorso relativo con _ al posto di \
            $relPath = $leaf.Path.Substring(3) -replace '\\', '_'
            $linkPath = "$outDir\$relPath"
            cmd /c "mklink /J `"$linkPath`" `"$($leaf.Path)`"" 2>$null | Out-Null
            Write-Host "  -> $relPath  ($($leaf.SizeMB) MB)"
        }
        Write-Host "MemoryManage creata in $outDir ($($leaves.Count) link)"
    } else {
        Write-Host "[PREVIEW] Usa -Execute per creare le junction in $outDir"
    }
}
