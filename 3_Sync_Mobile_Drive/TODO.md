# TODO & ROADMAP (Sync Mobile)

## ✅ Stato Attuale (Marzo 2026)
*   **Dispositivo attuale:** iPhone (su Windows).
*   **Conseguenza:** la sync ADB (Android) resta **legacy**; serve un flusso nuovo basato su:
    *   **Photos:** iCloud Photos + iCloud per Windows (consigliato per `_gallery`)
    *   **Files:** SSD esterno exFAT (consigliato per `_mobile`)
*   Doc principale: `3_Sync_Mobile_Drive/IPHONE_WINDOWS.md`

## ✅ Legacy (Gennaio 2026) - Android / Pixel 8
*   **Motore:** Android Debug Bridge (ADB). Veloce, no popup.
*   **Architettura:** Dual Root.
    *   `_gallery` (PC) ➔ `DCIM\SSD` (Tel) [Visibile]
    *   `_mobile` (PC) ➔ `SSD` (Tel) [Archivio]
*   **Sicurezza:** Sync distruttiva PC2Phone (Mirroring). Pulizia automatica file obsoleti.

## 🔮 Roadmap Aggiornata

### 0. Migrazione iPhone (Fase 1)
*   [x] Deciso: usare **iCloud Photos** come canale principale per `_gallery`.
*   [x] SSD archivio (D:\ / E:\): già **exFAT** (compatibile iPhone).
*   [x] Inbox iPhone su PC: `3_Sync_Mobile_Drive/Import-iCloudPhotos-ToInbox.ps1` (+ wrapper `.bat`).
*   [x] Publish `_gallery` -> iCloud Uploads: `3_Sync_Mobile_Drive/Publish-Gallery-ToiCloudUploads.ps1` (+ wrapper `.bat`).
*   [x] Documentata strategia Album (Photos) vs Folder (Files): `3_Sync_Mobile_Drive/IPHONE_WINDOWS.md`.

### 1. Sync Bidirezionale Intelligente (Phone2PC)
*   [ ] Implementare logica per rilevare spostamenti su telefono (da `SSD` a `DCIM`) e replicarli su PC (Move invece di Delete+Copy).
*   [ ] Gestione file cancellati su telefono: decidere se cancellare su PC o ripristinare.

### 2. Gestione Nuove Foto (Inbox)
*   [ ] Script per scaricare `DCIM/Camera` in una cartella `Inbox` su PC per smistamento manuale.
*   [ ] Workflow di integrazione: Camera -> Inbox -> Smistamento -> Sync PC2Phone.

### 3. Ottimizzazioni Tecniche
*   [ ] **Fast Move:** Usare `adb shell mv` per spostamenti interni al telefono (evita USB roundtrip).
*   [ ] **Safety Check:** Avviso se il numero di delete supera una soglia (es. >50 file) per evitare disastri accidentali.
