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

## 📂 Struttura Cartelle PC
*   I dischi `E:\` (Recent) e `D:\` (Old) vengono scansionati.
*   Le cartelle target sono identificate dai suffissi `_gallery` e `_mobile`.
    *   `2024\Evento\_gallery\foto.jpg` ➔ `DCIM\SSD\2024\Evento\foto.jpg`
    *   `2024\Evento\_mobile\extra.jpg` ➔ `SSD\2024\Evento\extra.jpg`

## 🛡️ Safe Partial Sync (Single Disk)
Lo script rileva automaticamente quali dischi sono connessi (`E:\` o `D:\`).
*   **Logica Push:** Carica solo dai dischi connessi.
*   **Logica Delete (Safety):** Elimina un file dal telefono **SOLO SE** il disco di origine teorico è connesso.
    *   Es: Se `D:` è scollegato, i file del 2019 sul telefono NON verranno toccati, anche se mancano nel piano di sync attuale.
    *   Questo permette di aggiornare le foto recenti (E:) senza dover collegare l'archivio storico (D:).

## ⚠️ Note Importanti
*   **Sync Distruttiva (Scoped):** All'interno delle cartelle gestite dai dischi connessi, la sync è mirroring (cancella ciò che non c'è su PC).
*   **File .nomedia:** NON gestiti. Visibilità basata su path.
