# HANDOFF — Contesto attuale

> Ultimo aggiornamento: 2026-03-19
> Per regole permanenti leggi `CORE_CONTEXT.md`. Questo file descrive dove siamo e cosa fare dopo.

---

## Stato dischi

```
D:\  = Old SSD — anni fino al 2023 incluso
E:\  = Recent SSD — 2024+, paradigma phone-first applicato
Filesystem: exFAT (compatibile iPhone)
```

## Paradigma attuale: phone-first (da 2026-03-16)

```
EventFolder/        ← file phone-worthy (vanno su iPhone)
EventFolder/_pc/    ← tutto il resto (solo PC)
```

`_mobile` e `_gallery` sono **aboliti**. Raw Insta360 centralizzati in `E:\Insta360\YYYYNomeEvento\`.

---

## Phone Mode (sync iPhone) — operativo

| Script | Funzione |
|--------|----------|
| `Enable-PhoneMode.ps1` | Sposta file phone-worthy in `E:\_iphone\`, salva manifest |
| `Restore-PCMode.ps1` | Rimette tutto al posto, aggiorna history |
| `Import-PhoneChanges.ps1` | Importa delta da iPhone → PC |

File di sistema in `E:\_sys\` (`_iphone_history.json`, `_iphone_manifest.json`).
Primo sync eseguito: 1093 file, 2026-03-17.

BAT wrappers: `PREVIEW_*/RUN_*` per ogni script. `-DeltaOnly` disponibile dal secondo sync.

---

## Task completati di recente

### Fix E:\Snow (2026-03-19)
Problema: foto/video caricati su iPhone mostravano data "oggi" invece della data evento.
- Eliminati 66 file `._` (resource fork macOS — causavano date errate in iPhone Photos)
- Fixati 95 JPG WhatsApp: `DateTimeOriginal` + `CreateDate` da filename (`IMG-YYYYMMDD-WA*`)
- Fixati 56 video WA/Google: QuickTime tags espliciti da filename (`VID-YYYYMMDD-WA*`, `YYYYMMDD_HHmmss_NNN.mp4`)

**Nota tecnica MP4 WhatsApp**: `-AllDates` fallisce perché `IFD0:ModifyDate` contiene `0000:00:00`.
Soluzione: specificare i 6 tag QuickTime uno per uno senza `-AllDates`.

Cartelle E:\Snow fixate: NeveZoldo, Neve, Stubai, Stubai 2, 2023Neve, 4Passi — tutte complete.

---

## MemoryManage — stato

- `D:\MemoryManage\` — **creata 2026-03-20**, 20 junction link (top: STUBAI2k21 28GB, 2023Spagna 21GB, DroneOld vari)
- `E:\MemoryManage\` — da creare quando E:\ montato: `.\Create-MemoryManage.ps1 -Execute`
- Script: `1_LLM_Automation\Maintenance\Create-MemoryManage.ps1`

---

## Task successivo: fix date + nomi su D:\

Approccio per cartella:
1. `exiftool -r -DateTimeOriginal -FileName "D:\ANNO\Cartella\"` — panorama date
2. Identifica outlier e range reale
3. Fix con `Force-DateToMax.ps1` o `Force-DateFromReference.ps1`
4. Rinomina nel formato `YYYYMMDD_NomeDescrittivo_N.ext`
5. Verifica outlier residui

Avanzamento:
- [x] D:\2022 — fixati 47 outlier — 2026-03-19
- [x] D:\2023 — fixati 72 outlier — 2026-03-19
- [ ] D:\2021 (cartelle tematiche: 2021Sardegna, 2021MotoConRiki, ...)
- [ ] D:\2020 e precedenti
- [ ] Cartelle tematiche (DroneOld, Neve, Rafting, AmiciGenerale, ...)

---

## Struttura E:\ attuale

```
E:\
├── 2024\, 2025\, 2026\   (anni, paradigma phone-first)
├── Insta360\             (raw vault centralizzato, escluso da Phone Mode)
├── Foto\                 (galleria curata per iPhone Photos)
├── Snow\                 (neve — fix completato 2026-03-19)
├── Me\                   (video personali)
├── stikers\              (sticker WhatsApp, inclusi in Phone Mode)
├── _drone\               (video drone curati, inclusi in Phone Mode)
├── _sys\                 (file di sistema: history, manifest)
└── _utili\, _invia\, ... (vari)
```

---

## Fix noti / bug tecnici

- `Split-Path -LiteralPath -Parent` ritorna stringa vuota su exFAT in PS 5.1
  → Fix: usare `[System.IO.Path]::GetDirectoryName()`
- `New-Item` con `$ErrorActionPreference = 'SilentlyContinue'` fallisce silenziosamente
  → Fix: aggiungere `-ErrorAction Stop` esplicito
- Em dash U+2014 causa errori parser PS
  → Fix: usare ` - ` ASCII
- `-AllDates` fallisce su MP4 WhatsApp per `IFD0:ModifyDate=0000`
  → Fix: specificare i 6 QuickTime tag esplicitamente
