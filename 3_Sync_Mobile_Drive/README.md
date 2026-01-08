# Sync Mobile & Drive (Pixel 8)

Sistema di sincronizzazione unidirezionale/bidirezionale tra PC e Google Pixel 8, ottimizzato per Google Foto.
Utilizza **ADB (Android Debug Bridge)** per massima velocità e affidabilità.

## 🚀 Architettura "Dual Root"
Per gestire correttamente la visibilità in Google Foto, il sistema divide i file in due destinazioni sul telefono:

1.  **GALLERY (Visibile):** Cartelle PC `_gallery` ➔ Telefono `DCIM\SSD`
    *   Appaiono nel feed principale di Google Foto.
    *   Contengono le foto "curate" o pubbliche.
2.  **MOBILE (Nascosto):** Cartelle PC `_mobile` ➔ Telefono `SSD`
    *   Non appaiono nel feed principale (ma visibili in Raccolta).
    *   Contengono archivio, raw, meme, screenshots, video pesanti.

## 🛠️ Requisiti
*   **Debug USB** attivato sul telefono (Impostazioni > Opzioni Sviluppatore).
*   **Driver ADB** installati (lo script `Setup-ADB.ps1` li scarica automaticamente in `Tools/`).

## 📜 Script Principali

### `Sync-Mobile.ps1`
Il motore di sincronizzazione principale.
*   **Motore:** ADB (no popup, veloce).
*   **Default:** `PC2Phone` (Mirroring distruttivo PC -> Telefono).
*   **Uso:**
    ```powershell
    .\Sync-Mobile.ps1 -Execute
    ```
    Senza `-Execute` fa solo una PREVIEW del piano.

### `Setup-ADB.ps1`
Scarica i `platform-tools` di Google se non presenti. Eseguire una volta.

## 🔄 Sync Modes

### 1. `PC2Phone` (Master: PC)
*   **Obiettivo:** Replicare lo stato del PC sul telefono (Mirroring).
*   **Azione:** Copia file nuovi su telefono. **CANCELLA** file dal telefono che non sono sul PC (per liberare spazio).
*   **Safety:** Usa logica "Source-Aware" che protegge i file di dischi scollegati.

### 2. `Phone2PC` (Master: Phone)
*   **Obiettivo:** Importare modifiche fatte in mobilità.
*   **Azione:** Copia file nuovi dal telefono al PC.
*   **Dynamic Root Discovery:**
    *   Lo script cerca dove esiste la cartella radice (es. `2025`, `meme`) sui dischi connessi.
    *   Se trova `D:\2020`, mette i file lì.
    *   Se trova `E:\meme`, mette i file lì.
    *   **Fallback:** Se la cartella è completamente nuova, la crea su `E:\` (Recent) per default.
*   **Safety (Soft Delete):** Se hai cancellato un file dal telefono, lo script **NON LO CANCELLA** dal PC, ma lo sposta in una cartella `_trash`.
*   **Trim Detection:** Se sovrascrivi un file locale con uno più piccolo (es. video ritagliato sul telefono), l'originale viene spostato in `_trash` con il suffisso `(long)`.
    *   Esempio: `Video.mp4` (PC, 1GB) sovrascritto da `Video.mp4` (Phone, 100MB).
    *   Cestino: `Video(long).mp4` (1GB).

### 3. Date Strategy (Filename Sovereignty)
Poiché l'editing su telefono può alterare i metadati (Data Ultima Modifica = Oggi), facciamo affidamento sul **Nome del File**.
*   Formato: `YYYYMMDD_...`
*   Questo nome è l'unica "Verità Assoluta".
*   In caso di disallineamento, usare gli strumenti in `1_LLM_Automation` per ripristinare i metadati basandosi sul nome.

## 🛡️ Safe Partial Sync (Single Disk)
Lo script rileva automaticamente quali dischi sono connessi (`E:\` o `D:\`).
*   **Logica Push:** Carica solo dai dischi connessi.
*   **Logica Delete (Phone Side):** Elimina un file dal telefono **SOLO SE** il disco di origine teorico è connesso.
    *   Es: Se `D:` è scollegato, i file del 2019 sul telefono NON verranno toccati.

## ⚠️ Note Importanti
*   **Sync Distruttiva (PC2Phone):** All'interno delle cartelle gestite, `PC2Phone` è mirroring distruttivo.
*   **Soft Delete (Phone2PC):** Il PC non perde mai dati definitivamente. Controlla le cartelle `_trash` periodicamente.
