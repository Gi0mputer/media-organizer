# CLAUDE.md — Media Archive Management

Leggi questo file all'inizio di ogni sessione, poi i documenti indicati sotto in ordine.

## Documenti da leggere (in ordine)

1. `CORE_CONTEXT.md` — regole permanenti: paths hardcoded, struttura archivio, naming, date, sync iPhone
2. `HANDOFF.md` — contesto attuale: a che punto siamo, cosa e' pronto, su quale task si sta lavorando
3. `TODO.md` — consegne dell'utente + task list suddivisa in step

> Se `HANDOFF.md` o `TODO.md` non esistono ancora per un'area, leggi i README della sottocartella pertinente.
> Contesti issue attivi per sessione: `Agent_context/` (non tracciato su git).

---

## Regole operative

### Letture e modifiche al codice
- **Non chiedere conferma** per leggere file o modificare codice
- La versione stabile e' sempre committata — il revert e' sempre possibile
- Chiedi conferma solo per azioni irreversibili senza backup (push force, delete definitivo senza log)

### Commit
- **Committa sempre** al termine di una sessione in cui l'utente ha espresso soddisfazione
- Il commit e' il checkpoint di sicurezza: farlo e' parte del workflow, non serve richiesta esplicita
- Messaggio commit: descrittivo, in italiano, con lista bullet delle modifiche principali

### File di progetto da mantenere aggiornati
Dopo ogni modifica maggiore funzionante, aggiorna questi file:

| File | Contenuto |
|------|-----------|
| `TODO.md` | Consegne dell'utente riordinate + task list in step semplici e stabili |
| `DOCS.md` | Documentazione storica: cosa e' stato fatto, perche', come funziona |
| `HANDOFF.md` | Contesto attuale per riprendere da un'altra chat o un altro PC |

`CORE_CONTEXT.md` si aggiorna solo se cambiano regole fondamentali (paths, paradigmi).

---

## Struttura progetto

```
media-organizer\
- CLAUDE.md                    <- questo file
- CORE_CONTEXT.md              <- regole permanenti (LEGGI SEMPRE)
- HANDOFF.md                   <- stato attuale (handoff)
- TODO.md                      <- consegne + task list
- DOCS.md                      <- documentazione storica
- SETUP.md                     <- setup ambiente
- 1_LLM_Automation\            <- workflow assistiti, script euristici, report
- 2_DragDrop_Tools\            <- tool drag & drop uso quotidiano
- 3_Sync_Mobile_Drive\         <- utility iPhone/iCloud
- Agent_context\               <- contesti sessioni Claude (tracciato su git)
```

---

## Setup su un nuovo PC

```powershell
git clone <repo>
cd media-organizer
.\Setup-Environment.ps1   # installa exiftool, ffmpeg, libimobiledevice
.\Setup-Claude.ps1        # installa Claude Code + shortcut 'work'
# Crea pc_config.local.json con RecentDrive, OldDrive, PCLabel
```

Riprendere da qualsiasi terminale: `work` — mostra tutte le sessioni di tutti i progetti.

## Stack tecnico

- **Linguaggio:** PowerShell 5.1+ (Windows)
- **Tool esterni richiesti in PATH:** `exiftool`, `ffmpeg`, `ffprobe`, `ideviceinfo`/`idevicepair`
- **Setup:** `Setup-Environment.ps1` installa tutto via winget
- **Config per-PC:** `pc_config.local.json` (non committato) — definisce `RecentDrive`, `OldDrive`, `PCLabel`
- **Esecuzione script:** `powershell -NoProfile -ExecutionPolicy Bypass -File "script.ps1"`

## Architettura storage

```
E:\  = Recent SSD (2024+, exFAT) — cartelle: 2024\, 2025\, 2026\, Insta360\
D:\  = Old SSD (fino al 2023, exFAT) — cartelle: 2018\..2023\, FileKayak\, FileAmici\, FileFamiglia\, Mavic Pro\
```

I due drive non hanno mai intersezione temporale. Le lettere drive variano per PC — verificare sempre `pc_config.local.json`.

## Paradigma iPhone (attuale — 2026-03-18)

SSD exFAT collegato direttamente a iPhone via cavo. Nessuna sync automatica — trasferimento manuale cartella per cartella. Script Phone Mode (`Enable-PhoneMode`, `Restore-PCMode`, `Import-PhoneChanges`) sono **obsoleti**, non usarli.

Prerequisito prima di ogni trasferimento su iPhone: file devono avere nome e data EXIF corretti.

## Regole critiche (sintesi)

- **Naming:** `YYYYMMDD_NomeDescrittivo_N.ext` — N senza zero-padding, omesso se file unico
- **Date forzate:** sempre MAX del range, mai mediana (preserva cronologia visuale in galleria)
- **Cartelle di servizio:** `_pc\`, `_trash\`, `Drive\`, `MERGE\`, `RAW\` — trasparenti per naming
- **`_mobile` e `_gallery` sono ABOLITI** — non crearle, non suggerirle
- **Insta360 raw:** centralizzati in `E:\Insta360\YYYYNomeEvento\`
- **Eliminazioni:** preferire Recycle Bin, mai eliminare senza log
- **Path su exFAT:** usare `[System.IO.Path]::GetDirectoryName()` invece di `Split-Path -Parent`
- **Em dash U+2014:** causa errori parser PS — usare trattino ASCII ` - `
