# HANDOFF — Prossima Chat

Leggi sempre `CORE_CONTEXT.md` all'inizio.

---

## Stato attuale (2026-03-17)

### Completato in questa sessione

**Paradigma phone-first** (sessione precedente):
- `_mobile` e `_gallery` aboliti: root evento = phone-worthy, `_pc\` = solo PC
- Tool: `1_LLM_Automation/Maintenance/Reorganize-PhonePc.ps1`
- Insta360 centralizzato in `E:\Insta360\YYYYNomeEvento\`
- Tool: `1_LLM_Automation/Maintenance/Migrate-Insta360.ps1`

**Phone Mode workflow** (questa sessione):
- `3_Sync_Mobile_Drive/Enable-PhoneMode.ps1` — sposta file phone-worthy in `_iphone\`, salva manifest
- `3_Sync_Mobile_Drive/Restore-PCMode.ps1` — rimette tutto al posto, aggiorna history
- `3_Sync_Mobile_Drive/Import-PhoneChanges.ps1` — importa modifiche da iPhone (delta)
- BAT wrappers: `PREVIEW_*/RUN_*` per ogni script
- File di sistema in `E:\_sys\` (non sporca la root)
- History primo trasferimento salvata: `E:\_sys\_iphone_history.json` (1093 file, 2026-03-17)

**Sticker**: spostati da `E:\_utili\_pc\WhatsStickers\_pc\` a `E:\stikers\`

**Legacy rimosso**:
- `Sync-Mobile.ps1`, `Setup-ADB.ps1` (Android/ADB)
- `Sync-iPhoneFiles.ps1`, BAT staging vecchio approccio

---

## Flusso operativo attuale

### Export (PC → iPhone)
```
RUN_ENABLE_PHONE_MODE.bat        → E:\ in Phone Mode (move in _iphone\)
[copia _iphone\ su iPhone Files via SSD]
RUN_RESTORE_PC_MODE.bat          → ripristina PC Mode
```
Dal secondo sync: aggiungi `-DeltaOnly` (porta solo novita').

### Import (iPhone → PC)
```
[copia albero da iPhone Files in _iphone\ sul SSD]
RUN_IMPORT_PHONE_CHANGES.bat     → applica delta
```

---

## Fix noti / bug risolti

- `Split-Path -LiteralPath -Parent` ritorna stringa vuota su exFAT in PS 5.1
  → Fix: usare `[System.IO.Path]::GetDirectoryName()`
- `New-Item` con `$ErrorActionPreference = 'SilentlyContinue'` fallisce silenziosamente
  → Fix: aggiungere `-ErrorAction Stop` esplicito
- Em dash U+2014 causa errori parser PS in certi contesti
  → Fix: usare ` - ` ASCII

---

## Possibili prossimi lavori

- **_pc nested cleanup**: script per collassare `_pc` annidate (es. `E:\2025\Elba\_pc\Sub\_pc\file`) nella `_pc` piu' vicina alla root dell'evento — richiesto, da implementare
- **BAT -DeltaOnly**: `PREVIEW/RUN_ENABLE_PHONE_MODE_DELTA.bat`
- **D:\ Phone Mode**: il workflow funziona su qualsiasi drive con `-DriveRoot D:\`

---

## Struttura E:\ attuale

```
E:\
├── 2024\, 2025\, 2026\   (anni, eventi con paradigma phone-first)
├── Insta360\             (raw vault centralizzato, escluso da Phone Mode)
├── Foto\                 (galleria curata per iPhone Photos)
├── Me\                   (video personali)
├── stikers\              (sticker WhatsApp, inclusi in Phone Mode)
├── _drone\               (video drone curati, inclusi in Phone Mode)
├── _sys\                 (file di sistema: history, manifest)
└── _utili\, _invia\, ... (vari)
```
