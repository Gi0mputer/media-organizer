# Sync Mobile (Google Pixel 8)

## Obiettivo
Sincronizzare subset selettivi dell’archivio PC (E:\ Recent + D:\ Old) verso Pixel 8 via MTP, mantenendo un mapping **reversibile** (telefono -> PC).

## Marker folders (PC)
Cartelle di servizio canoniche (legacy supportato dallo script):
- `_mobile\` (alias: `Mobile\`): contenuti “privati/di lavoro” -> su telefono finiscono in `...\Mobile\...` e **non** devono comparire in Google Foto (via `.nomedia`)
- `_gallery\` (alias: `Gallery\`): contenuti **visibili** -> su telefono si “dissolvono” nella cartella padre (non si usa più `DCIM\Camera\`)
- `_trash\` (alias: `Trash\`): esclusa dal sync (quarantena/manuale)

Nota: le cartelle di servizio sono **trasparenti** per il naming dei file (non danno mai il nome).

## Struttura telefono
Base (hardcoded in `3_Sync_Mobile_Drive/device_config.json`): `PC\\Pixel 8\\Memoria condivisa interna\\SSD`

Mapping PC -> Pixel:
- `_gallery\` -> **parent folder** su telefono (visibile in Foto)
- `_mobile\` -> sottocartella `Mobile\...` (nascosta via `.nomedia`)

Esempi:
```
E:\2025\Elba\_gallery\foto.jpg        -> SSD\2025\Elba\foto.jpg
E:\2025\Elba\_mobile\clip.mp4         -> SSD\2025\Elba\Mobile\clip.mp4
E:\2025\Elba\_mobile\.nomedia         -> SSD\2025\Elba\Mobile\.nomedia
```

Mapping Pixel -> PC:
- se il path contiene `\Mobile\` -> `_mobile\`
- altrimenti -> `_gallery\` (per mantenere mapping reversibile)

## Script: `Sync-Mobile.ps1`

Modalità:
- `PC2Phone` (destructive sul telefono): allinea `SSD\...` al PC (delete **solo** su file gestiti da snapshot, salvo `-Force`)
- `Phone2PC` (add-only + replace): importa nuovi file dal telefono; se un file esiste ma differisce (size/date) lo **sostituisce** su PC (vecchio nel Cestino)
- `Phone2PCDelete` (destructive sul PC): elimina su PC i file mancanti sul telefono (Cestino), con guard snapshot (salvo `-Force`)

Sezioni:
- `-Sections Mobile` -> solo contenuti in `...\Mobile\...`
- `-Sections Gallery` -> solo contenuti “visibili” (fuori da `Mobile\`)
- `-Sections Both` -> entrambi

Opzioni utili:
- `-ScanRoots` per limitare lo scope (es. una singola cartella evento)
- `-SourceDisk Recent|Old|Both` per lavorare anche in single-disk mode

Esempio (preview + execute):
```powershell
.\Sync-Mobile.ps1 -Mode PC2Phone -WhatIf
.\Sync-Mobile.ps1 -Mode PC2Phone -Execute
```

## `.nomedia` (critico)
Ogni cartella `Mobile\` sul telefono deve contenere `.nomedia`, altrimenti WhatsApp stickers e altri contenuti “di servizio” finiscono in Google Foto.

Lo script:
- crea `.nomedia` nei `_mobile\` su PC (quando esegue)
- crea `.nomedia` nelle cartelle `Mobile\` sul telefono (quando esegue `Phone2PC`)
- non elimina mai `.nomedia` dal telefono

## Cleanup legacy `DCIM\\Camera` (one-time)
Vecchie sync “Gallery -> Camera” possono aver copiato file dentro `DCIM\Camera`.
Per rimuovere **solo** quei file (basandosi sui log storici):
```powershell
.\Cleanup-LegacyCamera.ps1 -WhatIf
.\Cleanup-LegacyCamera.ps1 -Execute
```

## Workflow consigliato
1. Risolvi eventuali marker `1day/Nday` (date + metadati) e svuota/elimina le cartelle marker.
2. Audit date `_gallery` (evita file che finiscono “oggi” in galleria).
3. Esegui la sync.

## Limitazioni
- MTP è lento/fragile: usare `-ScanRoots` e batch piccoli se il telefono si disconnette.
- Non gestisce conflitti “veri” (modifiche diverse su entrambi i lati): scegli tu quale direzione è source-of-truth (`PC2Phone` o `Phone2PC`).
- Legacy cleanup: vecchie sync potevano lasciare file `_mobile` anche fuori da `Mobile\` (duplicati). `PC2Phone` prova a cancellare la copia “fuori” quando trova duplicati con size uguale (se size è unknown/mismatch, fa warning e non cancella).
