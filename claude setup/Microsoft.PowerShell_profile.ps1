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

    $items = @()
    foreach ($pd in Get-ChildItem $cp -Directory -EA SilentlyContinue) {
        $rp = _ClaudePath $pd.Name
        $lb = if ($rp) { Split-Path $rp -Leaf } else { $pd.Name }
        foreach ($j in Get-ChildItem $pd.FullName -Filter '*.jsonl' -EA SilentlyContinue) {
            $ti = '(senza nome)'
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
    $sel = 0
    $msg = $null
    $menuRow = [Console]::CursorTop

    while ($true) {
        [Console]::SetCursorPosition(0, $menuRow)
        $W = [Math]::Max(60, [Console]::WindowWidth - 4)

        Write-Host ('  Claude Sessions' + $EL) -ForegroundColor Cyan
        Write-Host ('  ' + ('-' * $W) + $EL) -ForegroundColor DarkGray
        Write-Host $EL

        for ($i = 0; $i -lt $items.Count; $i++) {
            $s  = $items[$i]
            $on = $i -eq $sel
            $mark = if ($on) { '  > ' } else { '    ' }
            $fc   = if ($on) { 'White' } else { 'DarkGray' }
            $ac   = if ($on) { 'Cyan'  } else { 'DarkGray' }
            $ti   = if ($s.Title.Length -gt 32) { $s.Title.Substring(0,31) + '...' } else { $s.Title }
            $lb   = if ($s.Label.Length -gt 20) { $s.Label.Substring(0,19) + '...' } else { $s.Label }
            Write-Host $mark -NoNewline -ForegroundColor $ac
            Write-Host $ti.PadRight(32) -NoNewline -ForegroundColor $fc
            Write-Host ('  ' + $lb.PadRight(20)) -NoNewline -ForegroundColor $ac
            Write-Host ('  ' + $s.Date.ToString('dd/MM HH:mm') + $EL) -ForegroundColor DarkGray
        }

        Write-Host $EL
        Write-Host ('  ' + ('-' * $W) + $EL) -ForegroundColor DarkGray
        if ($msg) {
            Write-Host ('  ' + $msg + $EL) -ForegroundColor Yellow
            $msg = $null
        } else {
            Write-Host ('  up/down naviga  |  Enter apri  |  D elimina  |  Esc esci' + $EL) -ForegroundColor DarkGray
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
                Write-Host ('  Percorso non trovato.' + $EL) -ForegroundColor Yellow
                Write-Host ('  claude --resume ' + $s.UUID + $EL) -ForegroundColor DarkGray
            }
            return
        }

        if ($k.KeyChar -eq [char]'D' -or $k.KeyChar -eq [char]'d') {
            $s = $items[$sel]
            Write-Host ('  Elimina ' + $s.Title + '? (S/n) ' + $EL) -NoNewline -ForegroundColor Yellow
            $cf = [Console]::ReadKey($true)
            if ($cf.KeyChar -eq [char]'S' -or $cf.KeyChar -eq [char]'s') {
                Remove-Item ($s.Dir + '\' + $s.UUID + '.jsonl') -EA SilentlyContinue
                Remove-Item ($s.Dir + '\' + $s.UUID) -Recurse -EA SilentlyContinue
                $items = @($items | Where-Object { $_.UUID -ne $s.UUID })
                $sel = [Math]::Min($sel, [Math]::Max(0, $items.Count - 1))
                if ($items.Count -eq 0) {
                    Write-Host ''
                    Write-Host ('  Nessuna sessione rimasta.' + $EL) -ForegroundColor DarkGray
                    return
                }
                $msg = 'Sessione eliminata.'
            }
            continue
        }
    }
}

