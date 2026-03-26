# LLM AUTOMATION & AGENT GUIDELINES

This directory contains automation scripts and guidelines for the **Media Archive Management** project.
**READ THIS FIRST** when starting a new session related to automation or maintenance.

---

## 🚨 CRITICAL PROTOCOLS (Updated 2026-03-09)

### 1. Mobile Synchronization (Current: iPhone on Windows)
*   iPhone Photos is **not** a filesystem: albums are collections, not folders.
*   Prefer one of these transfer paths:
    *   **Photos path:** iCloud Photos + iCloud for Windows (recommended for “gallery” subset).
    *   **Files path:** SSD esterno **exFAT** (recommended for private/large archive subset).
*   PC-side helpers:
    *   Import: `3_Sync_Mobile_Drive/Import-iCloudPhotos-ToInbox.ps1`
    *   Publish: `3_Sync_Mobile_Drive/Publish-Gallery-ToiCloudUploads.ps1`
*   Reference: `3_Sync_Mobile_Drive/IPHONE_WINDOWS.md`.

### 1b. Legacy Mobile Synchronization (Android / Pixel 8)
*   **Avoid MTP / PowerShell COM objects** when you need reliability.
*   Use **ADB (Android Debug Bridge)**:
    *   Sync engine: `3_Sync_Mobile_Drive\Sync-Mobile.ps1`.
    *   Requirement: “USB Debugging” enabled on the phone.
    *   Drivers/tools: `3_Sync_Mobile_Drive\Tools`.

### 2. Project Architectures

> **OBSOLETO (2026-03-16):** `_gallery` e `_mobile` sono **aboliti**. Non crearli, non suggerirli.

*   **Paradigma attuale — phone-first:**
    *   `EventFolder/` (root) ➔ file phone-worthy (vanno su iPhone via drag&drop su SSD exFAT)
    *   `EventFolder/_pc/` ➔ tutto il resto (solo PC, raw, editing)
*   I Phone Mode scripts (`Enable-PhoneMode`, `Restore-PCMode`, `Import-PhoneChanges`) esistono ma sono **obsoleti** — non usarli.
*   **iPhone note:** trasferimento manuale cartella per cartella, SSD exFAT collegato direttamente a iPhone.

### 3. Date Strategy (The "MAX Date" Rule)
*   **Discontinuities:** When fixing dates for a folder/event, prevent anomalies from appearing in the middle of the event.
*   **Solution:** Force outlier files to the **MAX date** (end of the interval) of that event.
*   **Priority:** 1. EXIF GPS/DateOriginal -> 2. Filename Regex -> 3. LastWriteTime -> 4. MAX Date (Fallback).

---

## 🛠️ WORKFLOWS & SCRIPTS

### A. Maintenance & Cleanup
*   `Maintenance/Process-DayMarkerFolders.ps1`: Handles temporary `1day`/`Nday` markers. Check regex patterns, fix dates, un-nest files.
*   `Remove-EmptyFolders.ps1`: General cleanup.

### B. Date & Metadata Fixing
*   `Audit-GalleryDates.ps1`: **Pre-Sync Check.** Ensures files in `_gallery` have valid metadata.
*   `Force-DateToMax.ps1`: Auto-detects event range and forces outliers to the end (MAX).
*   `Force-DateFromReference.ps1`: Drag-drop a reference file to apply its date to the folder.
*   `Analyze-FolderDatePatterns.ps1`: Detects mismatches between folder names (e.g. "2024_08_Ferragosto") and file content.

### C. Drag & Drop Tools (Quick Actions)
Located in `2_DragDrop_Tools`.
*   `STANDARDIZE_VIDEO.bat`: Converters (1080p/30fps).
*   `FIX_DATE_FROM_FILENAME.bat`: Metadata fixers.
*   Android-only: `3_Sync_Mobile_Drive/RUN_SYNC_PC_TO_PHONE.bat` and `3_Sync_Mobile_Drive/RUN_SYNC_PHONE_TO_PC.bat`.

---

## 📂 DIRECTORY STRUCTURE

*   `1_LLM_Automation/`: Intelligence, scripts, analysis tools.
*   `2_DragDrop_Tools/`: User-facing batch wrappers.
*   `3_Sync_Mobile_Drive/`: Mobile sync (Android legacy) + iPhone roadmap/docs.

---

## 🤖 INSTRUCTIONS FOR AI AGENTS

When tasked with a new objective:
1.  **Read `CORE_CONTEXT.md`** (Root) for hardcoded paths (`E:\`, `D:\`).
2.  **Identify Domain:**
    *   If **Sync/Mobile**: Go to `3_Sync_Mobile_Drive`. Read `TODO.md` there.
    *   If **Cleanup/Dates**: Check `1_LLM_Automation/Scripts`.
3.  **Use Existing Tools:** Do not reinvent the wheel. Use `adb`, `exiftool`, `ffmpeg` wrappers provided.
