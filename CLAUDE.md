# CLAUDE.md — Media Archive Management

Leggi questo file all'inizio di ogni sessione, poi i tre file indicati sotto in ordine.

## Documenti da leggere (in ordine)

1. `CORE_CONTEXT.md` — regole permanenti: paths hardcoded, struttura archivio, naming, date, sync iPhone
2. `HANDOFF.md` — contesto attuale: a che punto siamo, cosa è pronto, su quale task si sta lavorando
3. `TODO.md` — consegne dell'utente + task list suddivisa in step

> Se `HANDOFF.md` o `TODO.md` non esistono ancora per un'area, leggi i README della sottocartella pertinente.

---

## Regole operative

### Letture e modifiche al codice
- **Non chiedere conferma** per leggere file o modificare codice
- La versione stabile è sempre committata — il revert è sempre possibile
- Chiedi conferma solo per azioni irreversibili senza backup (push force, delete definitivo)

### Commit
- **Committa sempre** al termine di una sessione in cui l'utente ha espresso soddisfazione
- Il commit è il checkpoint di sicurezza: farlo è parte del workflow, non serve richiesta esplicita
- Messaggio commit: descrittivo, in italiano, con lista bullet delle modifiche principali

### File di progetto da mantenere aggiornati
Dopo ogni modifica maggiore funzionante, aggiorna questi tre file:

| File | Contenuto |
|------|-----------|
| `TODO.md` | Consegne dell'utente riordinate + task list in step semplici e stabili |
| `DOCS.md` | Documentazione storica: cosa è stato fatto, perché, come funziona |
| `HANDOFF.md` | Contesto attuale per riprendere da un'altra chat o un altro PC |

`CORE_CONTEXT.md` si aggiorna solo se cambiano regole fondamentali (paths, paradigmi).

---

## Struttura progetto

```
Desktop\Batchs\
├── CLAUDE.md                    ← questo file
├── CORE_CONTEXT.md              ← regole permanenti
├── HANDOFF.md                   ← stato attuale (handoff)
├── TODO.md                      ← consegne + task list
├── DOCS.md                      ← documentazione storica
├── SETUP.md                     ← setup ambiente (exiftool, ffmpeg, ecc.)
├── 1_LLM_Automation\            ← workflow assistiti, script euristici, report
├── 2_DragDrop_Tools\            ← tool drag & drop uso quotidiano
└── 3_Sync_Mobile_Drive\         ← sync iPhone (Phone Mode)
```

## Dischi

```
D:\  = Old SSD (fino 2023 incluso)
E:\  = Recent SSD (2024+)
Filesystem: exFAT (compatibile iPhone)
```

## Dipendenze richieste in PATH
- `exiftool`
- `ffmpeg` / `ffprobe`
- PowerShell 5.1+
