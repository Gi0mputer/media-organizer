param(
    [string]$Root,
    [switch]$Delete,
    [switch]$ListAll
)

$ErrorActionPreference = 'SilentlyContinue'

try {
    $Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
} catch {
    Write-Host "[ERROR] Invalid path."
    exit 1
}

Write-Host "Scanning: $Root"
$all = Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 }
$total = ($all | Measure-Object).Count

if ($total -eq 0) {
    Write-Host "No files found."
    exit 0
}

# Calculate depth and properties
$files = $all | ForEach-Object {
    $rel = $_.FullName.Substring($Root.Length).TrimStart('\')
    $depth = ($rel -split '\\').Count
    [pscustomobject]@{
        'Name' = $_.Name.ToLowerInvariant()
        'FullName' = $_.FullName
        'Length' = $_.Length
        'LastWrite' = $_.LastWriteTime
        'Depth' = $depth
    }
}

# Group by Name
$groups = $files | Group-Object Name | Where-Object { $_.Count -gt 1 }
$actions = @()

foreach ($g in $groups) {
    # Sub-group by Length (Size)
    foreach ($sg in ($g.Group | Group-Object Length)) {
        if ($sg.Count -le 1) { continue }

        # Sort: Deepest first, then Oldest first, then Alphabetical
        $sorted = $sg.Group | Sort-Object -Property @{Expression='Depth'; Descending=$true}, @{Expression='LastWrite'; Descending=$false}, @{Expression='FullName'; Descending=$false}
        
        $keep = $sorted | Select-Object -First 1
        $del  = $sorted | Select-Object -Skip 1
        
        foreach ($d in $del) {
            $dp = Split-Path $d.FullName -Parent | Split-Path -Leaf
            $kp = Split-Path $keep.FullName -Parent | Split-Path -Leaf
            $actions += [pscustomobject]@{
                'Name' = $keep.Name
                'Del' = $d.FullName
                'DelParent' = $dp
                'Keep' = $keep.FullName
                'KeepParent' = $kp
            }
        }
    }
}

$todo = $actions.Count
if ($todo -eq 0) {
    Write-Host "No duplicates (Name + Size) found."
    exit 0
}

$summary = $actions | Group-Object DelParent, KeepParent | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{
        'Name' = ($_.Group[0].DelParent + " -> " + $_.Group[0].KeepParent)
        'Count' = $_.Count
    }
}

Write-Host ("Found {0} duplicates to remove." -f $todo)

# DRY RUN
if (-not $Delete) {
    Write-Host "Examples:"
    $max = if ($ListAll) { 2147483647 } else { 60 }
    
    $actions | Select-Object -First $max | ForEach-Object {
        Write-Host ($_.DelParent + " -> " + $_.KeepParent + " - " + $_.Name)
    }
    
    Write-Host ""
    Write-Host "Folder pairs summary (top 30):"
    $summary | Select-Object -First 30 | ForEach-Object { Write-Host ($_.Name + " (x" + $_.Count + ")") }
    
    Write-Host ""
    Write-Host "[DRY-RUN] No changes made."
    exit 0
}

# EXECUTION
Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
$ans = Read-Host "Confirm move to Recycle Bin? Type YES to proceed"
if ($ans -ne 'YES') {
    Write-Host "Cancelled."
    exit 0
}

$ok = 0
$err = 0
foreach ($a in $actions) {
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($a.Del, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin, [Microsoft.VisualBasic.FileIO.UICancelOption]::DoNothing)
        $ok++
    } catch {
        $err++
        Write-Host ("[ERROR] " + $a.Del)
    }
}

Write-Host ""
Write-Host ("Done. Moved to Recycle Bin: {0}   Errors: {1}" -f $ok, $err)
