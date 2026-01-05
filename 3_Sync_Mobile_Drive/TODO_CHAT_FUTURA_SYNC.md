# TODO - Chat Futura: Mobile Sync (Pixel 8)

## Contesto rapido

**Dischi PC (hardcoded)**:
- `E:\` = Recent SSD (2024+)
- `D:\` = Old SSD (pre-2024, fino 2023)
- Non hanno intersezione temporale

**Telefono**: Google Pixel 8 (MTP via Windows Shell)

**Path base telefono (hardcoded)**:
`PC\Pixel 8\Memoria condivisa interna\SSD`

Nota: `SSD` e' a livello root (accanto a `DCIM`), non dentro `DCIM`.

---

## Marker folders (PC)

Cartelle di servizio canoniche (legacy supportato dallo script):
- `_mobile\` (alias `Mobile\`): contenuti da nascondere in Google Foto.
- `_gallery\` (alias `Gallery\`): contenuti che devono essere visibili in Google Foto.
- `_trash\` (alias `Trash\`): esclusa dal sync (quarantena/manuale).

Regola fondamentale: le cartelle di servizio sono **trasparenti** per naming (non danno mai il nome ai file).

---

## Mapping PC <-> Telefono (nuovo paradigma)

### PC -> Telefono

Base: `SSD\`

- `_gallery\` (visibile): i file "si dissolvono" nella cartella padre su telefono.
- `_mobile\` (nascosto): i file finiscono in sottocartella `Mobile\...` su telefono.

Esempi:
```
E:\2025\Elba\_gallery\foto.jpg        -> SSD\2025\Elba\foto.jpg
E:\2025\Elba\_mobile\clip.mp4         -> SSD\2025\Elba\Mobile\clip.mp4
E:\2025\Elba\_mobile\.nomedia         -> SSD\2025\Elba\Mobile\.nomedia
```

### Telefono -> PC (mapping reversibile)

Regola:
- Se il path contiene `\Mobile\` -> PC `_mobile\`
- Altrimenti -> PC `_gallery\`

Esempi:
```
SSD\2025\Elba\foto.jpg                -> E:\2025\Elba\_gallery\foto.jpg
SSD\2025\Elba\Mobile\clip.mp4         -> E:\2025\Elba\_mobile\clip.mp4
```

**Unificazione Old + Recent su telefono**:
- Su telefono `SSD\` contiene cartelle da ENTRAMBI i dischi
- Script reinstrada:
  - anni >= 2024 -> Recent (E:\)
  - anni < 2024 -> Old (D:\)
  - root "tematiche" (Family, Tinder, ecc.) -> disco dove esiste la cartella (se ambiguo, warning)

---

## Modalita' sync (implementate in `Sync-Mobile.ps1`)

### 1) `PC2Phone` (destructive sul telefono)

Sorgente verita': PC. Allinea `SSD\...` sul telefono.

- Copia nuovi file PC -> telefono
- Sostituisce su telefono se differisce (size/snapshot)
- Elimina dal telefono i file non piu' presenti su PC **solo** se gestiti da snapshot (salvo `-Force`)

### 2) `Phone2PC` (add-only + replace)

Sorgente verita': telefono.

- Copia nuovi file telefono -> PC
- Se il file esiste ma differisce (size/date), lo sostituisce su PC (vecchio nel Cestino)
- Non elimina mai da PC

### 3) `Phone2PCDelete` (destructive sul PC)

Come `Phone2PC`, ma elimina su PC i file mancanti sul telefono (Cestino).

Guard:
- per default elimina solo file che risultano precedentemente gestiti da snapshot (salvo `-Force`)

---

## Sezioni (`-Sections`)

Per ridurre rischi e tempi:
- `Mobile` = solo contenuti in `...\Mobile\...`
- `Gallery` = solo contenuti visibili (fuori da `Mobile\`)
- `Both` = entrambi

---

## `.nomedia` (critico)

Ogni cartella `Mobile\` sul telefono deve contenere `.nomedia`, altrimenti contenuti "di servizio" finiscono in Google Foto.

Implementazione:
- PC: crea `.nomedia` dentro ogni `_mobile\` (quando esegue)
- Telefono: crea `.nomedia` dentro ogni `...\Mobile\` (quando esegue `Phone2PC`)
- Non elimina mai `.nomedia` dal telefono

---

## Single-disk mode (safety)

Se e' connesso solo uno tra D:\ o E:\:
- lo script evita di fare delete "pericolose" su root tematiche non-anno
- per root anno, gestisce solo gli anni coerenti con il disco connesso

---

## Workflow consigliato (progetto)

1) Risolvi eventuali marker folders `1day/NDAY` (date + metadata, poi svuota/elimina cartella marker)
2) Audit `_gallery` (evita file che finiscono “oggi” in galleria) + fix se necessario
3) Esegui la sync

---

## Cleanup legacy `DCIM\\Camera` (one-time)

Vecchie sync copiavano `Gallery` in `DCIM\Camera`.
Script dedicato: `Cleanup-LegacyCamera.ps1`

Uso:
```powershell
.\Cleanup-LegacyCamera.ps1 -WhatIf
.\Cleanup-LegacyCamera.ps1 -Execute
```

Principio di sicurezza:
- cancella solo file il cui nome compare nei log storici come `COPY/REPLACE [GALLERY] ... -> <filename>`

---

## Idee / TODO futuri

- Trash su telefono: invece di delete MTP, spostare in `SSD\\_trash\\...` (opt-in)
- Resume sync: riprendere copie lente/interrotte (MTP e' fragile)
- Conflitti bidirezionali: policy esplicita quando entrambi i lati cambiano lo stesso file
