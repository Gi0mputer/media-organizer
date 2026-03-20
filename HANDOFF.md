# HANDOFF — Contesto attuale

> Ultimo aggiornamento: 2026-03-20 (aggiornato dopo incidente Fix-DateFromFilename)
> Per regole permanenti leggi `CORE_CONTEXT.md`. Questo file descrive dove siamo e cosa fare dopo.

---

## Stato dischi

```
D:\  = Old SSD — anni fino al 2023 incluso
E:\  = Recent SSD — 2024+, si monta come E:\ o F:\ a seconda della sessione
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

## DANNO DA RIPARARE — priorita alta (2026-03-20)

Durante la sessione del 2026-03-20 Claude ha eseguito `Fix-DateFromFilename -Force -Yes` senza conferma
esplicita su due cartelle, sovrascrivendo DateTimeOriginal anche su file che lo avevano gia corretto.

### Cartelle danneggiate

**E:\2025\SardegnaMoto** — 248 file toccati
- Stato attuale: date sparse per giorno reale del viaggio (da filename WA/Android), orario 12:00:00 su tutto
- Distribuzione date ora presente:
  - Apr 19-20: 14 file
  - Apr 21-23: 63 file
  - Apr 24-26: 124 file
  - Apr 27-29: 45 file
  - Jul 27, Oct 18: 2 outlier da rimuovere o correggere
- Danno: orario preciso perso, file dello stesso giorno non ordinati tra loro

**E:\Snow\NeveZoldo** — 117 file toccati
- Stato attuale: due cluster logici (Feb 4-9 2024 e Dic 25-31 2024), orario 12:00:00 su tutto
- Distribuzione date ora presente:
  - Feb 4-9 2024: 21 file
  - Oct 21 2024: 1 outlier
  - Dic 25-31 2024: 91 file
  - Gen-Apr 2025: 4 outlier
- Danno: orario preciso perso, file dello stesso giorno non ordinati tra loro

### Piano di riparazione (da fare con feedback visivo)

Il flusso concordato con l'utente:
1. Apri cartella in Explorer ordinata per data
2. L'utente guarda visivamente i file e li raggruppa per contenuto (es. "mattina in moto", "pranzo", "pomeriggio mare")
3. Claude assegna a ciascun gruppo un orario (09:00, 13:00, 16:00) cosi si agglomerano correttamente
4. Fix eseguito SOLO sui file del gruppo, con WhatIf prima di ogni esecuzione reale

**REGOLA CRITICA appresa:** Mai usare Fix-DateFromFilename (o qualsiasi fix EXIF bulk) con -Force/-Yes
senza conferma esplicita dell'utente per ogni cartella. Il flusso corretto e sempre:
analisi -> mostra risultati -> aspetta ok -> WhatIf -> aspetta ok -> esegui.

---

## Task completati di recente

### Fix E:\Snow (2026-03-19)
Eliminati 66 file `._` macOS, fixati 95 JPG WA + 56 video WA/Google. Tutte le sottocartelle Snow complete.

### Fix D:\ date outlier (2026-03-19)
- D:\2021Sardegna, D:\2021MotoConRiki — outlier a MAX range evento
- D:\2022 — 47 file fixati da filename
- D:\2023 — 72 file fixati da filename

### Fix F:\ (recent SSD) date outlier (2026-03-20)
- F:\2024: 7 file fixati (CapodannoBerlino, Croazia, Laurea)
- F:\2025: 133 file fixati (arezzo, Como, FerrataAquile, GiroMotoDolomiti, SardegnaMoto)
- Pattern 1979-12-31 (epoch Unix) e 1601-01-01 (epoch Windows FILETIME) tutti risolti

### MemoryManage D:\ (2026-03-20)
D:\MemoryManage creata con 20 junction link. Top: STUBAI2k21 28GB, 2023Spagna 21GB.

---

## MemoryManage — stato

- `D:\MemoryManage\` — **creata 2026-03-20**, 20 junction link (top: STUBAI2k21 28GB, 2023Spagna 21GB, DroneOld vari)
- `E:\MemoryManage\` — da creare quando E:\ montato: `.\Create-MemoryManage.ps1 -Execute`
- Script: `1_LLM_Automation\Maintenance\Create-MemoryManage.ps1`

---

## Task successivi

### Fix date restanti su D:\ (cartelle tematiche)
Cartelle anno 2022/2023 complete. Restano:
- [ ] D:\2021 e precedenti (anni)
- [ ] DroneOld, Neve, Rafting, AmiciGenerale, Avventure, Covid, Europei, Family, Foto, FuochiTendate, Lago, Lavoro, Mappe, Me Old, Moto, RicordiMiei, Sup, Tellaro, Wallpapers

### Fix date cartelle tematiche F:\ (recent SSD)
- [ ] F:\Sup (289 file)
- [ ] F:\_drone (373 file)
- [ ] F:\Rafting (94 file)
- [ ] F:\Lavoro (48 file)
- [ ] F:\Snow (gia fixata, ma riverifica se necessario)

### MemoryManage F:\
- [ ] Rieseguire `Create-MemoryManage.ps1 -Execute` quando F:\ montato (script gia pronto)

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
