# iPhone ↔ Windows (Media Archive) - Compatibilità e Piano

Questa guida aggiorna il progetto per il passaggio da Android (ADB) a **iPhone su Windows**.

## TL;DR (scelta consigliata)

1. **Archivio Master = PC (D:\ + E:\)**: rimane la sorgente di verità.
2. **Foto “da galleria” = iPhone Photos (+ opzionale iCloud Photos)**: subset curato (`_gallery`).
3. **Archivio/privato/pesante = Files / SSD esterno (exFAT)**: subset privato (`_mobile`).

In pratica: non cerchiamo di “montare” l’iPhone come filesystem per fare mirroring completo (non è Android).

---

## Cosa cambia rispetto ad Android (ADB)

- iOS **non espone una cartella equivalente a `/sdcard/`** su cui fare sync bidirezionale affidabile da script.
- La libreria **Foto** (Photos) non è un filesystem: **Album ≠ cartelle** (sono tag/collezioni).
- La parte “Files” (su iPhone / iCloud Drive / SSD esterno) invece è filesystem, ma **non alimenta automaticamente la timeline Foto**.

---

## Strumenti (iPhone ↔ Windows)

Scegli in base al caso d’uso:

### A) Import “nuove foto/video” da iPhone a PC (consigliato)
- **iCloud per Windows (iCloud Photos)**: scarica automaticamente sul PC.
  - Pro: affidabile, incrementale, zero USB.
  - Contro: richiede cloud/spazio e una scelta chiara su cosa resta in iCloud.
- In alternativa: **Import manuale da DCIM via USB** (Esplora file / app Foto di Windows).
  - Pro: offline.
  - Contro: spesso lento, e la scrittura PC→iPhone via DCIM non è supportata.

#### Setup rapido iCloud Photos su Windows (Fase 1)
1. Installa **iCloud per Windows** (Microsoft Store) e fai login.
2. Attiva **Foto** / **iCloud Photos**.
3. Aspetta il primo download su PC (può richiedere tempo).
4. Poi usa lo script di import Inbox:
   - Preview: `3_Sync_Mobile_Drive/PREVIEW_IMPORT_ICLOUD_TO_INBOX.bat`
   - Run: `3_Sync_Mobile_Drive/RUN_IMPORT_ICLOUD_TO_INBOX.bat`
   - Script: `3_Sync_Mobile_Drive/Import-iCloudPhotos-ToInbox.ps1`

### B) Portare file dal PC su iPhone (curati / “gallery”)
- **iCloud Photos Upload** (se attivi iCloud Photos): carichi dal PC e arrivano in Foto su iPhone.
- Automazione proposta (PC-side): `3_Sync_Mobile_Drive/Publish-Gallery-ToiCloudUploads.ps1` (wrapper: `3_Sync_Mobile_Drive/PREVIEW_PUBLISH_GALLERY_TO_ICLOUD.bat` / `3_Sync_Mobile_Drive/RUN_PUBLISH_GALLERY_TO_ICLOUD.bat`).
- Oppure app di trasferimento tipo **PhotoSync / iMazing** (più controllo su formati, Live Photo, metadati).
- Offline: copia su **SSD exFAT**, poi su iPhone importi in Foto (manuale) oppure li usi come file in Files.

### C) Portare “archivio privato/pesante” sul telefono senza intasare Foto
- **SSD esterno exFAT** collegato all’iPhone (Files).
- Oppure **iCloud Drive / OneDrive** (come filesystem, non come Foto).

---

## SSD compatibile con iPhone (formattazione)

### Regola pratica
- **exFAT**: migliore compatibilità tra iPhone e Windows (e macOS).
- **FAT32**: compatibile ma limite **4GB per file** (problema per video).
- **NTFS**: su iPhone in genere **non** è scrivibile (spesso non è nemmeno leggibile senza app/driver).

### Strategia consigliata (non distruttiva)
- Nel setup attuale, `D:\` (Old) e `E:\` (Recent) risultano già **exFAT** → quindi sono già leggibili dall’iPhone (Files).
- Se non vuoi collegare “tutto l’archivio” al telefono, aggiungi comunque un disco “navetta” (es. `X:\`) in **exFAT** per scambi rapidi.
  - Dentro metti due root:
    - `X:\_IPHONE_FILES\`  (equivalente `_mobile`)
    - `X:\_IPHONE_PHOTOS_IMPORT\` (equivalente `_gallery`, pronta per import)

Se invece vuoi davvero riformattare i dischi archivio in exFAT: prima serve un piano backup/restore (è distruttivo).

Tool utile: `3_Sync_Mobile_Drive/Check-ExternalDrive-ForiPhone.ps1`.

Esempi:
```powershell
# Preview (consigliato)
.\3_Sync_Mobile_Drive\Check-ExternalDrive-ForiPhone.ps1 -DriveLetters X

# Crea cartelle navetta (scrive su disco)
.\3_Sync_Mobile_Drive\Check-ExternalDrive-ForiPhone.ps1 -DriveLetters X -CreateFolders -Execute
```

---

## “Files” vs “Foto” su iPhone (come separare)

### Mappa concettuale del progetto
- `_gallery` (PC): roba “curata” che vuoi **in Foto** (timeline/ricordi/condivisione).
- `_mobile` (PC): roba privata/di lavoro che vuoi **come file** (Files/SSD), non in timeline.

### Album (come ragionarci)
- Un elemento può stare in più album: l’album è una **vista**, non un contenitore.
- Quindi: l’ordine cronologico dipende dai **metadati data/ora**, non dalla cartella.
- Suggerimento pratico:
  - Album per “evento/viaggio” (nome evento).
  - Folder di album per anno (`2026`, `2025`, …).
  - Evita di replicare il filesystem 1:1 in album (diventa ingestibile).

---

## Workflow proposto (Fase 1)

1. **Acquisizione su iPhone**
2. **Import su PC** (iCloud Photos o USB → cartella Inbox dedicata)
3. **Pulizia/normalizzazione su PC**
   - `1_LLM_Automation/Maintenance/Process-DayMarkerFolders.ps1` (se usi `1day/Nday`)
   - `2_DragDrop_Tools/MetadataTools/FIX_DATE_FROM_FILENAME.bat` (solo quando il filename contiene la data)
   - `1_LLM_Automation/Scripts/Force-DateToMax.ps1` (eventi con outlier)
4. **Smistamento** in `D:\YYYY\Evento\...` o `E:\YYYY\Evento\...` + `_gallery/_mobile`
5. **Export verso iPhone**
   - `_gallery` → Foto (iCloud upload / app transfer / import manuale)
   - `_mobile` → SSD exFAT (Files)

---

## Decisioni da prendere (per chiudere la migrazione)

- Vuoi usare **iCloud Photos** come ponte stabile iPhone↔PC per la parte Foto?
- Quanto “archivio” vuoi davvero sul telefono, e quanto invece su SSD esterno?
- Vuoi un SSD “navetta” dedicato exFAT, o vuoi convertire i dischi archivio?

---

## Troubleshooting: iPhone non vede l'hard disk / SSD

Checklist (in ordine):

1. **Apri l'app Files (File)** su iPhone → tab **Sfoglia** → **Posizioni**  
   Il disco esterno appare qui (non in Foto). A volte serve entrare in *Sfoglia* dopo aver collegato il disco.

2. **Cavo/adapter giusto (data, non solo carica)**
   - iPhone **USB‑C**: usa un cavo USB‑C ⇄ USB‑C che supporti dati (meglio quello del disco).
   - iPhone **Lightning**: serve un adapter tipo *Lightning → USB (Camera Adapter)*; spesso serve anche alimentazione esterna.

3. **Alimentazione**
   - HDD (meccanici) quasi sempre richiedono alimentazione (hub/alimentatore).
   - SSD di solito vanno, ma alcuni modelli via hub/adapter economici possono dare problemi.

4. **FileSystem / sicurezza**
   - OK: **exFAT** (consigliato), FAT32 (limite 4GB/file).
   - Evita: **BitLocker/drive cifrati** (iPhone non li monta).
   - Preferibile: **una sola partizione** principale.

5. **Prova incrociata**
   - Prova con un'altra chiavetta/SSD exFAT (piccola) per capire se è un problema di adapter/power.
   - Se un disco funziona e l'altro no, potrebbe essere una differenza di **partition table** (MBR/GPT) o hardware del box.

5b. **Caso subdolo: exFAT ma partizione MBR marcata FAT32**
Su Windows il volume può risultare exFAT, ma la **tabella MBR** può indicare un tipo FAT32 (es. `MbrType=12`).
Mac/iPhone in alcuni casi non montano il disco se il tipo partizione non è coerente.

Fix (non distruttivo, richiede admin su Windows):
- `3_Sync_Mobile_Drive/Fix-MbrPartitionType-ForExFAT.ps1`

6. **FileSystem “sporco”**
   Se il disco è stato staccato senza *Rimozione sicura*, exFAT può risultare “dirty” e iOS può rifiutare il mount.  
   Su Windows: fai *Rimozione sicura* e, se serve, `chkdsk X: /f` (con attenzione).

Tool lato PC: `3_Sync_Mobile_Drive/Check-ExternalDrive-ForiPhone.ps1`
