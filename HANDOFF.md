# HANDOFF — Contesto attuale

> Ultimo aggiornamento: 2026-04-10
> Per regole permanenti leggi `CORE_CONTEXT.md`. Questo file descrive dove siamo e cosa fare dopo.

---

## REGOLE OPERATIVE — OBBLIGATORIE (leggile prima di tutto)

### 1. Interpretazione cartelle — intelligenza contestuale
**Mai processare il nome di una cartella in modo automatico.**
Ogni nome cartella va letto e interpretato con intelligenza intuitiva: capire il contesto (evento, viaggio, persona, attivita), valutare se il significato e chiaro, e in caso chiedere all'utente prima di procedere.
Esempi: "Snow" = eventi neve (piu cartelle evento dentro), "gayaktopc" = file da iPhone per kayak, "adventure topc" = file da iPhone per avventure/uscite.

### 2. Flusso obbligatorio per ogni fix EXIF bulk
**Mai eseguire fix EXIF (DateTimeOriginal, QuickTime tags, etc.) senza questo flusso:**
1. Analisi — mostra date trovate e cosa verrebbe cambiato
2. Aspetta conferma utente
3. WhatIf — mostra cosa farebbe il comando
4. Aspetta conferma utente
5. Esegui

Vietato usare `-Force/-Yes` senza conferma esplicita per ogni singola cartella.
**Questo e il risultato di un incidente reale (2026-03-20) che ha sovrascritto DateTimeOriginal su 365 file.**

### 3. Divisione del lavoro Claude / utente
**Claude fa:** analisi (date, pesi, anomalie, duplicati), operazioni batch ripetitive (delete cartelle vuote, fix EXIF bulk, rinomina ricorsiva).
**L'utente fa:** spostamenti manuali di file/cartelle, decisioni visive (capire cosa siano certi file, classificare un evento), scelte di merge.
Non proporre mai a Claude di spostare file da A a B autonomamente — presentare l'analisi e lasciare che l'utente decida e agisca.

### 4. Script Phone Mode = OBSOLETI
`Enable-PhoneMode.ps1`, `Restore-PCMode.ps1`, `Import-PhoneChanges.ps1` esistono nel repo ma non fanno parte del flusso attuale. Non usare, non suggerire.

---

## Stato dischi

```
D:\  = Old SSD — anni fino al 2023 incluso (exFAT)
F:\  = Recent SSD — 2024+ (exFAT, si montava come E:\ in sessioni precedenti — ora e F:\)
```

> ATTENZIONE: nei vecchi handoff il recent SSD e chiamato E:\. Ora si monta come F:\.
> Adattare mentalmente ogni riferimento a E:\ → F:\ per il recent SSD.

> NOTA PC GFANTONI-PC (sessione 2026-04-10): su questo PC i drive sono INVERTITI rispetto alla descrizione sopra.
> D:\ = Recent SSD (2024+)  |  E:\ = Old SSD (fino al 2023)
> pc_config.local.json aggiornato di conseguenza (non committato).

---

## Sessione 2026-04-10 — lavoro completato

### Pulizia generale
- Eliminati 17 cartelle vuote su D:\ e E:\
- Eliminati 38 file `._` macOS su E:\ (D:\ non montato in quella sessione)

### MemoryManage
- `D:\_memorymanage\` e `E:\_memorymanage\` create con junction link + `_REPORT_DIMENSIONI.txt`
- Script aggiornato: ora usa `_memorymanage` (underscore) e lettere drive variabili via `-RecentDrive`

### Migrazione _droneold
- Tutte le cartelle `E:\_droneold\` spostate in `D:\_drone\` con rinomina:
  - Cartelle generiche: `NomeCartella` → `zoldNomeCartella`
  - Sottocartelle Mavic Pro: `NomeSottocartella` → `zzmpNomeSottocartella`
  - (`zold` < `zzmp` alfabeticamente → Mavic Pro in fondo, DroneOld prima)
- `E:\_droneold\` eliminata completamente (0 file persi)
- `D:\_drone\_REPORT_DIMENSIONI.txt` — panoramica con barre ASCII di tutte le 70 cartelle
- `D:\_drone\NomeCartella\_REPORT_FILE_GRANDI.txt` — in 47 cartelle con file >300 MB

### Rinomina _insta360
- Tutte le 20 sottocartelle di `D:\_insta360\` rinominate con tag `is36` dopo l'anno
- Formato: `YYYYis36NomeCamelCase` (es. `2025is36SupSalo`, `2025is36QuattroPassi`)
- Serve a identificare le cartelle come Insta360 anche dopo spostamenti

### Duplicati / trash
- Analisi duplicati video >100 MB: nessun duplicato tra cartelle live
- Tutti i duplicati trovati erano tra cartelle live e cestini ($RECYCLE.BIN / .Trashes)
- `D:\2026\_trash\Marocco` (28 GB) — backup intenzionale mentre l'utente edita su telefono, DA NON TOCCARE
- `.Trashes` su D:\ ed E:\: 183 file con copia live (da svuotare), 223 orfani (da valutare)

---

## Paradigma attuale: phone-first

```
EventFolder/        <- file phone-worthy (vanno su iPhone via drag&drop)
EventFolder/_pc/    <- tutto il resto (solo PC, iPhone non la vede)
```

Le cartelle `_pc\` non vanno mai dissolte automaticamente. Il contenuto di `_pc\` va ignorato durante i fix per iPhone.
Raw Insta360 centralizzati in `F:\Insta360\YYYYNomeEvento\` (esclusi da Phone Mode).

---

## PULIZIA F:\ IN CORSO (sessione 2026-03-26) — NON COMPLETATA

### Struttura top-level F:\

```
F:\
├── 2024\, 2025\, 2026\       (anni)
├── _drone\                   (video drone curati)
├── _foto\                    (galleria curata)
├── _insta360\                (raw Insta360)
├── _invia\, _utili\          (vari)
├── __sys\                    (sistema)
├── Animali\                  (animali)
├── Adventure\                (avventure generiche)
├── Lago\                     (lago)
├── Lavoro\                   (lavoro)
├── Me\, MePiccolo\           (video personali)
├── Particelle\               (progetto artistico particelle)
├── Rafting\                  (rafting)
├── RicordiMiei\              (ricordi personali)
├── Snow\                     (neve)
├── Sup\                      (sup/paddle)
├── --- TOPC FOLDERS ---
├── adventure topc\           (10 file da iPhone, avventure)
├── dronetopc\                (4 file da iPhone, drone)
├── gayaktopc\                (52 file + sottocartelle da iPhone, kayak)
├── lavorotopc\               (13 file da iPhone, lavoro)
└── topc\                     (22 file da iPhone, generici/misti)
```

### Cartelle "topc" — da processare

Le cartelle `*topc` contengono file appena portati da iPhone. Vanno mergiati nelle cartelle corrispondenti eliminando i duplicati.

| Cartella topc | Stato | Note |
|---|---|---|
| `lavorotopc` | **RIMOSSA** (altro PC) | Mergiata in F:\Lavoro\ |
| `dronetopc` | **RIMOSSA** (altro PC) | Mergiata in F:\_drone\ |
| `gayaktopc` | **RIMOSSA** (altro PC) | Mergiata in F:\2026\Gayak\ (ora ha subdirs PatPat/Scoltenna/SesiaPeter/Sture/Visit con contenuto) |
| `adventure topc` | **RIMOSSA** (altro PC) | Destinazione da verificare |
| `topc` | **DA FARE** — 22 file | Mix date 2024-2026, nessuna categoria chiara — l'utente deve classificare visivamente |

**Contenuto `topc` ancora da classificare (22 file):**
- `IMG_0859.JPG` (gen 2026)
- `VID-20241004-WA0075.MP4`, `20241209_224232_754~2.MP4`, `VID_60021120_221849_123.MP4` (ott/dic 2024)
- `VID-20251005-WA0010/9.MP4`, `VID-20250921-WA0014.MP4` (set/ott 2025)
- `VID-20260119-WA0015.MP4`, `VID-20260116-WA0019.MP4` (gen 2026)
- 7x `VID-20251101-WA*.MP4` (nov 2025 — stesso giorno, forse stesso evento dei file Greg in _trash?)
- `IMG_0490/0493.JPG` (mar 2026), `IMG_0828/0841/0843/0845.JPG` (mar 2026)

### Cartella `F:\2026\_trash` — da processare

Contiene 4 sottocartelle. Decisione da prendere cartella per cartella: eliminare se duplicato, ripristinare fuori da _trash se unico.

**`_trash\Eskimi`** (23 file, feb 2026)
- Contenuto: video kayak eskimo roll/handroll. `HandRollSync.mp4`, `eskimi13101-116.mp4`, subdir `Mocca\` e `Noe\`
- Non esiste una cartella `F:\2026\Eskimi` o simile
- Da valutare: creare `F:\2026\Gayak\Eskimi` o altra destinazione, oppure stanno gia nel gayaktopc?
- Decisione richiesta all'utente

**`_trash\Greg`** (22 file, ott-nov 2025 + gen 2026)
- Contenuto: foto/video Pixel da Greg (PXL_20251031*, PXL_20260109-11*) + file WhatsApp 1 nov 2025 (IMG/VID-20251101-WA*)
- OVERLAP: i 3 PXL_20260110_* sono anche in `adventure topc`
- `F:\Adventure\Greg\` esiste ma e VUOTA
- Domanda: questi file fanno parte di un'avventura/uscita con Greg? Il WA del 1 nov suggerisce un evento (halloween?)
- Decisione richiesta all'utente

**`_trash\Lavoro`** (2 file, gen-feb 2026)
- `PXL_20260127_160508344.MP.jpg` + `WhatsApp Video 2026-01-16 at 17.15.50.mp4`
- Probabilmente duplicati di file gia in `F:\Lavoro\` o `lavorotopc`
- Da verificare prima di eliminare

**`_trash\Marocco`** (109 file, feb 2026)
- Contenuto: enorme raccolta video drone DJI + `dji_fly_*` + `compose_video_*` + 2x `PXL_*.LS.mp4`
- Date: 13-22 feb 2026. Marocco = viaggio in Marocco febbraio 2026
- Non esiste `F:\2026\Marocco` (dovrebbe essere creata)
- OVERLAP: i 3 `dji_fly_20260213_*` sono anche in `dronetopc`
- I `dji_fly_*` sembrano essere versioni iPhone dei DJI (stessa scena, nome diverso) — probabilmente non duplicati esatti ma versioni diverse
- I `compose_video_*` sono video compositi/montati fatti sull'iPhone
- Decisione richiesta all'utente: creare F:\2026\Marocco\ e spostare tutti i file?

### Cartelle vuote su F:\

Avviata scansione ma non completata. **BUG NOTO:** `Get-ChildItem -Recurse -Force` su exFAT in PS 5.1 restituisce falsi positivi (cartelle con file risultano vuote). Verificare sempre senza `-Force` prima di eliminare.

Cartelle sicuramente vuote da eliminare (subdirs senza file):
- `F:\Adventure\Greg\` — vuota, i file Greg stanno in `_trash\Greg`
- Molte `_pc\` vuote dentro `_drone\`, `Sup\`, etc.
- Subdirs evento vuote dentro `2025\SardegnaMoto\` (Serata paesino, Andata in moto, Cena, ferragosto pranzo)

---

## DANNO DA RIPARARE — priorita alta (da 2026-03-20)

### F:\2025\SardegnaMoto — 248 file
- Orario forzato a 12:00:00 su tutto, ordine intra-giorno perso
- Date corrette per giorno ma non per ora
- Piano: feedback visivo — utente raggruppa file per contenuto, Claude assegna orari diversi

### F:\Snow\NeveZoldo — 117 file
- Stesso problema. Due cluster: Feb 4-9 2024 e Dic 25-31 2024
- Piano identico

---

## Task successivi (in ordine di priorita)

1. **Completare pulizia F:\** — risolvere topc folders + _trash (domande sopra)
2. **Eliminare cartelle vuote F:\** — dopo pulizia topc/_trash
3. **Riparazione SardegnaMoto + NeveZoldo** — fix orari con feedback visivo
4. **Fix date D:\ cartelle tematiche** — anni 2021 e precedenti + DroneOld, Neve, Rafting, etc.
5. **Fix date F:\ cartelle tematiche** — Sup, _drone, Rafting, Lavoro
6. **MemoryManage F:\** — `Create-MemoryManage.ps1 -Execute` quando F:\ montato

---

## Script utili

| Script | Cosa fa |
|---|---|
| `1_LLM_Automation/Scripts/Fix-MediaDates.ps1` | Fix date EXIF batch con logica smart |
| `1_LLM_Automation/Scripts/Audit-GalleryDates.ps1` | Audit date — trova anomalie |
| `1_LLM_Automation/Scripts/Force-DateToMax.ps1` | Forza outlier alla data MAX |
| `2_DragDrop_Tools/MetadataTools/Fix-DateFromFilename.ps1` | Deduce data dal nome file |

---

## Fix tecnici noti (PS 5.1 su exFAT)

- `Split-Path -LiteralPath -Parent` ritorna stringa vuota su exFAT → usare `[System.IO.Path]::GetDirectoryName()`
- `New-Item` con `$ErrorActionPreference = 'SilentlyContinue'` fallisce silenziosamente → aggiungere `-ErrorAction Stop`
- Em dash U+2014 causa errori parser PS → usare ` - ` ASCII
- `-AllDates` fallisce su MP4 WhatsApp per `IFD0:ModifyDate=0000` → specificare i 6 QuickTime tag esplicitamente
- `Get-ChildItem -Recurse -Force` su exFAT puo restituire falsi positivi (cartelle con file risultano vuote) → verificare senza `-Force`

---

## Struttura F:\ — note

```
F:\2026\Gayak\   <- sottocartelle gia create: PatPat, Scoltenna, SesiaPeter, Sture, Visit (tutte vuote)
F:\Adventure\    <- ha solo Greg\ (vuota)
F:\_insta360\    <- molte sottocartelle eventi, tutte vuote (raw non ancora copiati?)
```

### Tag EXIF rilevanti per Apple Photos

| Formato | Tag |
|---|---|
| JPG | `DateTimeOriginal`, poi `CreateDate` |
| MP4/MOV | `QuickTime:CreateDate`, `QuickTime:MediaCreateDate` |
| INSV (Insta360) | tag proprietari — non modificare direttamente |

Fonte di verita date: GPS DateTime > EXIF DateTimeOriginal > LastWriteTime > deduzione contestuale.
