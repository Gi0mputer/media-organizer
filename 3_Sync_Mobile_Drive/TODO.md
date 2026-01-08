# TODO & ROADMAP (Sync Mobile)

## ✅ Stato Attuale (Gennaio 2026)
*   **Motore:** Android Debug Bridge (ADB). Veloce, no popup.
*   **Architettura:** Dual Root.
    *   `_gallery` (PC) ➔ `DCIM\SSD` (Tel) [Visibile]
    *   `_mobile` (PC) ➔ `SSD` (Tel) [Archivio]
*   **Sicurezza:** Sync distruttiva PC2Phone (Mirroring). Pulizia automatica file obsoleti.

## 🔮 Roadmap Aggiornata

### 1. Sync Bidirezionale Intelligente (Phone2PC)
*   [ ] Implementare logica per rilevare spostamenti su telefono (da `SSD` a `DCIM`) e replicarli su PC (Move invece di Delete+Copy).
*   [ ] Gestione file cancellati su telefono: decidere se cancellare su PC o ripristinare.

### 2. Gestione Nuove Foto (Inbox)
*   [ ] Script per scaricare `DCIM/Camera` in una cartella `Inbox` su PC per smistamento manuale.
*   [ ] Workflow di integrazione: Camera -> Inbox -> Smistamento -> Sync PC2Phone.

### 3. Ottimizzazioni Tecniche
*   [ ] **Fast Move:** Usare `adb shell mv` per spostamenti interni al telefono (evita USB roundtrip).
*   [ ] **Safety Check:** Avviso se il numero di delete supera una soglia (es. >50 file) per evitare disastri accidentali.
