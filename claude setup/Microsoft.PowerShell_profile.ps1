function work {
    $cp = "$env:USERPROFILE\.claude\projects"

    function _ClaudePath([string]$n) {
        if ($n -notmatch '^([A-Za-z])--(.+)$') { return $null }
        $d = $matches[1].ToUpper() + ':\'
        if (-not (Test-Path $d)) { return $null }
        $tok = $matches[2] -split '-'; $cur = $d; $i = 0
        while ($i -lt $tok.Count) {
            $ok = $false; $mx = [Math]::Min(4, $tok.Count - $i)
            for ($t = $mx; $t -ge 1; $t--) {
                foreach ($sep in '.', '-', '_') {
                    $c = Join-Path $cur (($tok[$i..($i+$t-1)]) -join $sep)
                    if (Test-Path $c -PathType Container) { $cur = $c; $i += $t; $ok = $true; break }
                }
                if (-not $ok -and $t -eq 1) {
                    $c = Join-Path $cur $tok[$i]
                    if (Test-Path $c -PathType Container) { $cur = $c; $i++; $ok = $true }
                }
                if ($ok) { break }
            }
            if (-not $ok) { return $null }
        }
        return $cur
    }

    function _Rename([string]$jsonlPath, [string]$uuid, [string]$title) {
        $lines = @(Get-Content $jsonlPath)
        $tl = '{"type":"custom-title","customTitle":"' + $title + '","sessionId":"' + $uuid + '"}'
        try {
            $obj = $lines[0] | ConvertFrom-Json
            if ($obj.type -eq 'custom-title') { $lines[0] = $tl }
            else { $lines = @($tl) + $lines }
        } catch { $lines = @($tl) + $lines }
        Set-Content -Path $jsonlPath -Value $lines
    }

    $items = @()
    foreach ($pd in Get-ChildItem $cp -Directory -EA SilentlyContinue) {
        $rp = _ClaudePath $pd.Name
        $lb = if ($rp) { Split-Path $rp -Leaf } else { $pd.Name }
        foreach ($j in Get-ChildItem $pd.FullName -Filter '*.jsonl' -EA SilentlyContinue) {
            $ti = ''
            try { $o = (Get-Content $j.FullName -First 1) | ConvertFrom-Json; if ($o.customTitle) { $ti = $o.customTitle } } catch {}
            $items += [PSCustomObject]@{ Title=$ti; UUID=$j.BaseName; Path=$rp; Dir=$pd.FullName; Label=$lb; Date=$j.LastWriteTime }
        }
    }
    $items = @($items | Sort-Object Date -Descending)

    if ($items.Count -eq 0) {
        Write-Host ''
        Write-Host '  (nessuna sessione Claude)' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    $ESC = [char]27
    $EL  = $ESC + '[K'
    $R   = $ESC + '[0m'
    $ORA = $ESC + '[38;2;218;119;56m'
    $WHT = $ESC + '[97m'
    $GRY = $ESC + '[38;2;120;120;120m'
    $DGR = $ESC + '[38;2;65;65;65m'
    $CYN = $ESC + '[38;2;86;182;194m'
    $YLW = $ESC + '[38;2;229;192;123m'

    $sel = 0; $msg = $null; $menuRow = [Console]::CursorTop

    while ($true) {
        [Console]::SetCursorPosition(0, $menuRow)
        $W = [Math]::Max(60, [Console]::WindowWidth - 4)

        Write-Host ($ORA + '  Claude' + $R + $WHT + ' Sessions' + $R + $EL)
        Write-Host ($DGR + '  ' + ('-' * $W) + $R + $EL)
        Write-Host $EL

        for ($i = 0; $i -lt $items.Count; $i++) {
            $s  = $items[$i]; $on = $i -eq $sel
            $noTitle = -not $s.Title
            $ti = if ($noTitle) { '(no title)' } elseif ($s.Title.Length -gt 32) { $s.Title.Substring(0,31) + '...' } else { $s.Title }
            $lb = if ($s.Label.Length -gt 20) { $s.Label.Substring(0,19) + '...' } else { $s.Label }
            $dt = $s.Date.ToString('dd/MM HH:mm')

            if ($on) {
                $tc = if ($noTitle) { $GRY } else { $WHT }
                Write-Host ($ORA + '  > ' + $R + $tc + $ti.PadRight(32) + $R + $CYN + '  ' + $lb.PadRight(20) + $R + $GRY + '  ' + $dt + $R + $EL)
            } else {
                $tc = if ($noTitle) { $DGR } else { $GRY }
                Write-Host ($DGR + '    ' + $R + $tc + $ti.PadRight(32) + $R + $DGR + '  ' + $lb.PadRight(20) + '  ' + $dt + $R + $EL)
            }
        }

        Write-Host $EL
        Write-Host ($DGR + '  ' + ('-' * $W) + $R + $EL)
        if ($msg) {
            Write-Host ($YLW + '  ' + $msg + $R + $EL)
            $msg = $null
        } else {
            Write-Host ($DGR + '  up/down' + $R + $GRY + ' naviga  ' + $DGR + '|' + $R + $GRY + '  Enter apri  ' + $DGR + '|' + $R + $GRY + '  R rinomina  ' + $DGR + '|' + $R + $GRY + '  D elimina  ' + $DGR + '|' + $R + $GRY + '  Esc esci' + $R + $EL)
        }

        $k = [Console]::ReadKey($true)

        if ($k.Key -eq 'UpArrow')   { if ($sel -gt 0) { $sel-- }; continue }
        if ($k.Key -eq 'DownArrow') { if ($sel -lt $items.Count - 1) { $sel++ }; continue }

        if ($k.Key -eq 'Escape') {
            [Console]::SetCursorPosition(0, $menuRow)
            0..($items.Count + 5) | ForEach-Object { Write-Host $EL }
            [Console]::SetCursorPosition(0, $menuRow)
            return
        }

        if ($k.Key -eq 'Enter') {
            $s = $items[$sel]
            [Console]::SetCursorPosition(0, $menuRow)
            0..($items.Count + 5) | ForEach-Object { Write-Host $EL }
            [Console]::SetCursorPosition(0, $menuRow)
            if ($s.Path -and (Test-Path $s.Path)) {
                Set-Location $s.Path
                & claude --resume $s.UUID
            } else {
                Write-Host ($ORA + '  Percorso non trovato.' + $R)
                Write-Host ($GRY + '  claude --resume ' + $s.UUID + $R)
            }
            return
        }

        if ($k.KeyChar -eq [char]'R' -or $k.KeyChar -eq [char]'r') {
            $s = $items[$sel]
            $fr = [Math]::Min($menuRow + $items.Count + 5, [Console]::WindowHeight - 2)
            [Console]::SetCursorPosition(0, $fr)
            Write-Host ($EL + $ORA + '  Nuovo nome: ' + $R) -NoNewline
            $newName = [Console]::ReadLine()
            if ($newName -and $newName.Trim() -ne '') {
                _Rename ($s.Dir + '\' + $s.UUID + '.jsonl') $s.UUID $newName.Trim()
                $items[$sel].Title = $newName.Trim()
                $msg = 'Sessione rinominata.'
            }
            continue
        }

        if ($k.KeyChar -eq [char]'D' -or $k.KeyChar -eq [char]'d') {
            $s = $items[$sel]
            $td = if ($s.Title) { "'" + $s.Title + "'" } else { 'questa sessione' }
            $fr = [Math]::Min($menuRow + $items.Count + 5, [Console]::WindowHeight - 2)
            [Console]::SetCursorPosition(0, $fr)
            Write-Host ($EL + $ORA + '  Elimina ' + $WHT + $td + $GRY + '? (S/n) ' + $R) -NoNewline
            $cf = [Console]::ReadKey($true)
            if ($cf.KeyChar -eq [char]'S' -or $cf.KeyChar -eq [char]'s') {
                Remove-Item ($s.Dir + '\' + $s.UUID + '.jsonl') -EA SilentlyContinue
                Remove-Item ($s.Dir + '\' + $s.UUID) -Recurse -EA SilentlyContinue
                $items = @($items | Where-Object { $_.UUID -ne $s.UUID })
                $sel = [Math]::Min($sel, [Math]::Max(0, $items.Count - 1))
                if ($items.Count -eq 0) {
                    Write-Host ''
                    Write-Host ($ORA + '  Nessuna sessione rimasta.' + $R)
                    return
                }
                $msg = 'Sessione eliminata.'
            }
            continue
        }
    }
}

