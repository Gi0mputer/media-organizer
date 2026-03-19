# HANDOFF — Fix Date & Nomi (Priorità Attiva)

> Ultimo aggiornamento: 2026-03-19 (pomeriggio — fix E:\Snow completato)
> Leggi CORE_CONTEXT.md per regole permanenti. Questo file descrive lo stato e il task corrente.

---

## Flusso (definitivo — semplice)

```
SSD (D:\, E:\) — exFAT → collegato a iPhone via cavo/adattatore
  → drag & drop cartella in iPhone Foto
  → appare in Apple Photos con le date EXIF
```

**Il PC serve solo per:**
1. Spostare file/cartelle tra D:\ e E:\ (scomodo da iPhone)
2. Riorganizzazione massiva (drag & drop multi-cartella)
3. Script Claude: analisi, compressione video, fix nomi + date EXIF ← PRIORITÀ
4. Nessuna sync automatica, nessuno script di trasferimento

Le cartelle `_pc\` dentro le cartelle evento = file che non vanno su iPhone (grezzo, raw, editing).
iPhone non le vede. Non servono script per gestirle — si ignorano e basta.

**Script Phone Mode (Enable-PhoneMode, Restore-PCMode, Import-PhoneChanges) = OBSOLETI.**
Esistono nel repo ma non fanno parte del flusso. Non usare, non suggerire.

---

## Problema principale — DATE MESCOLATE IN GALLERIA IPHONE

**Sintomo:** in iPhone Photos le foto finiscono tutte "oggi" invece che sulla data dell'evento.

**Causa:** molti file hanno DateTimeOriginal (tag EXIF/QuickTime) alterata.
Anche una piccola modifica al file ha sovrascritto la data con quella di modifica.
Apple Photos usa *solo* i metadati, non la data filesystem.

**Soluzione:** usare ExifTool per correggere i tag su D:\ e E:\ prima di portare i file su iPhone.

### Tag rilevanti per Apple Photos

| Formato | Tag che conta |
|---|---|
| JPG | `DateTimeOriginal`, poi `CreateDate` |
| MP4/MOV | `QuickTime:CreateDate`, `QuickTime:MediaCreateDate` |
| INSV (Insta360) | tag proprietari — non modificare direttamente |

### Strategia date (regola chiave)

- Fonte di verità: GPS DateTime > EXIF DateTimeOriginal > LastWriteTime > deduzione contestuale
- Se i file di una cartella hanno date sparse e l'evento è di 1 giornata → **forza tutti alla stessa data** (anche se non esatta — anno/mese giusti bastano per file vecchi)
- Se c'è un outlier → forzarlo alla data MAX del range (non mediana), così va in fondo all'evento in galleria, non in mezzo

### Comandi ExifTool di riferimento

```powershell
# Vedere le date di tutti i file in una cartella
exiftool -r -DateTimeOriginal -CreateDate -FileName "D:\2016\Vacanza\"

# Forzare data su JPG
exiftool -DateTimeOriginal="2016:08:15 12:00:00" -CreateDate="2016:08:15 12:00:00" foto.jpg

# Forzare data su MP4/MOV
exiftool "-QuickTime:CreateDate=2016:08:15 12:00:00" "-QuickTime:MediaCreateDate=2016:08:15 12:00:00" video.mp4

# Batch su cartella intera (ricorsivo, tutti i formati)
exiftool -r -DateTimeOriginal="2016:08:15 12:00:00" "D:\2016\Vacanza\"

# Copiare data filesystem → EXIF (se il filesystem è affidabile)
exiftool "-DateTimeOriginal<FileModifyDate" nomefile.jpg

# Rimuovere backup .jpg_original creati automaticamente da exiftool
exiftool -delete_original "D:\2016\Vacanza\"
```

---

## Naming convention target

```
YYYYMMDD_NomeDescrittivo_N.ext
```

- N senza zero-padding (1, 2, 10 — NON 001)
- N omesso se file unico per quella data+nome
- Il nome viene dalla cartella evento (non dalle sottocartelle di servizio)

```
20160815_VacanzaGrecia.jpg
20160815_VacanzaGrecia_1.jpg
20160815_VacanzaGrecia_2.jpg
```

---

## Struttura drive

```
D:\  = Old SSD (fino al 2023, exFAT)
  2018\, 2019\, 2020\, 2021\, 2022\, 2023\
  FileKayak\, FileAmici\, FileFamiglia\, Mavic Pro\  ← macrocategorie cross-anno
  _pc\  ← ECCEZIONE: cartella root _pc NON va dissolta (file solo-PC a livello root)

E:\  = Recent SSD (2024+, exFAT)
  2024\, 2025\, 2026\
  Insta360\  ← raw Insta360 centralizzati (E:\Insta360\YYYYNomeEvento\)
```

---

## Completato in questa sessione: fix E:\Snow (2026-03-19)

Problema: foto/video caricati su iPhone finivano "oggi" invece della data evento.

**Fix eseguiti su E:\Snow (tutte le sottocartelle):**
1. Eliminati 66 file `._` (resource fork macOS, causa "martedi" = 2026-03-18 in Photos) — tutti avevano controparte reale
2. Fix `DateTimeOriginal` + `CreateDate` su 95 file WhatsApp JPG da filename (IMG-YYYYMMDD-WA*)
3. Fix `QuickTime:CreateDate/ModifyDate/TrackCreateDate/TrackModifyDate/MediaCreateDate/MediaModifyDate` su 56 video WA/Google da filename (VID-YYYYMMDD-WA*, YYYYMMDD_HHmmss_NNN.mp4)

**Nota tecnica importante (esiftool su MP4 WA):**
- `-AllDates` fallisce su questi MP4 perche' IFD0:ModifyDate contiene 0000:00:00 non parsabile
- Soluzione: usare QuickTime tags esplicitamente senza AllDates
- `-m` da solo non basta — serve specificare i 6 tag QuickTime uno per uno

**File rimasti anomali in E:\Snow (non bloccanti per iPhone):**
- `VacanzaNeveZoldo (small).MP4` — CreateDate 2025:10:03 (probabile render date errata, non WA)
- File con FileModifyDate 1601/1979 ma EXIF corretto — Apple Photos usa EXIF, ignora FileModifyDate

**Cartelle E:\Snow analizzate:**
- [x] NeveZoldo — fix completo (dic 2024 + gen 2025 + feb 2024)
- [x] Neve — OK (pochi file, EXIF buono)
- [x] Stubai / Stubai 2 — fix file `._` (dic 2025)
- [x] 2023Neve / 2023Neve\STUBAI2k21 / 2023Neve\SangioCla — fix file `._` (dic 2022)
- [x] 4Passi — fix video WA (mar 2024 + mar 2025)

---

## Task successivo: fix date + nomi su D:\

Approccio per cartella:
1. `exiftool -r -DateTimeOriginal -FileName "D:\ANNO\Cartella\"` — panorama date
2. Decisione: mono-giorno (1 data per tutti) o multi-giorno (range reale)
3. Fix batch exiftool
4. Rinomina file nel formato standard
5. Verifica rapida outlier

Avanzamento — si parte da D:\ (nessuna cartella ancora completata):
- [ ] D:\2016 (se esiste)
- [ ] D:\2017
- [ ] D:\2018
- [ ] D:\2019
- [ ] D:\2020
- [ ] D:\2021
- [ ] D:\2022
- [ ] D:\2023
- [ ] D:\FileKayak
- [ ] D:\FileAmici
- [ ] D:\FileFamiglia
- [ ] D:\Mavic Pro

---

## Script esistenti utili

| Script | Cosa fa |
|---|---|
| `1_LLM_Automation/Scripts/Fix-MediaDates.ps1` | Fix date EXIF batch con logica smart |
| `1_LLM_Automation/Scripts/Fix-MediaDates-Batch.ps1` | Variante batch per più cartelle |
| `1_LLM_Automation/Scripts/Audit-GalleryDates.ps1` | Audit date — trova anomalie |
| `1_LLM_Automation/Scripts/Dates_Diagnostics.ps1` | Diagnostica completa date |
| `1_LLM_Automation/Scripts/Force-DateFromReference.ps1` | Forza data da file di riferimento |
| `1_LLM_Automation/Scripts/Force-DateToMax.ps1` | Forza outlier alla data MAX |
| `2_DragDrop_Tools/MetadataTools/Fix-DateFromFilename.ps1` | Deduce data dal nome file |
| `1_LLM_Automation/Maintenance/Process-DayMarkerFolders.ps1` | Risolve cartelle 1day/Nday |

Setup strumenti: `Setup-Environment.ps1` (installa exiftool, ffmpeg, libimobiledevice)

---

## Fix tecnici noti (PS 5.1 su exFAT)

- `Split-Path -Parent` ritorna stringa vuota su exFAT → usare `[System.IO.Path]::GetDirectoryName()`
- `New-Item` con `$ErrorActionPreference = 'SilentlyContinue'` fallisce silenziosamente → aggiungere `-ErrorAction Stop`
- Em dash U+2014 causa errori parser → usare ` - ` ASCII
