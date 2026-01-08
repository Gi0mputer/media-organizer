# LLM AUTOMATION & AGENT GUIDELINES

This directory contains automation scripts and guidelines for the **Media Archive Management** project.
**READ THIS FIRST** when starting a new session related to automation or maintenance.

---

## 🚨 CRITICAL PROTOCOLS (Updated 2026-01-08)

### 1. Mobile Synchronization (Pixel 8)
*   **DO NOT USE MTP OR POWERSHELL COM OBJECTS.** They are unreliable.
*   **ALWAYS USE ADB (Android Debug Bridge).**
    *   Sync Engine: `3_Sync_Mobile_Drive\Sync-Mobile.ps1` (wraps ADB).
    *   Requirement: "USB Debugging" enabled on phone.
    *   Drivers: `3_Sync_Mobile_Drive\Tools`.

### 2. Project Architectures
*   **Dual Root Mobile Sync:**
    *   `_gallery` (PC) ➔ `DCIM\SSD` (Phone) [Visible in Google Photos]
    *   `_mobile` (PC) ➔ `SSD` (Phone) [Archive/Hidden]
*   **No .nomedia:** Do not manage `.nomedia` files anymore. Visibility is governed by folder path.

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
*   `RUN_SYNC_MOBILE.bat`: One-click ADB Sync.

---

## 📂 DIRECTORY STRUCTURE

*   `1_LLM_Automation/`: Intelligence, scripts, analysis tools.
*   `2_DragDrop_Tools/`: User-facing batch wrappers.
*   `3_Sync_Mobile_Drive/`: Mobile sync engine (ADB), config, roadmap.

---

## 🤖 INSTRUCTIONS FOR AI AGENTS

When tasked with a new objective:
1.  **Read `CORE_CONTEXT.md`** (Root) for hardcoded paths (`E:\`, `D:\`).
2.  **Identify Domain:**
    *   If **Sync/Mobile**: Go to `3_Sync_Mobile_Drive`. Read `TODO.md` there.
    *   If **Cleanup/Dates**: Check `1_LLM_Automation/Scripts`.
3.  **Use Existing Tools:** Do not reinvent the wheel. Use `adb`, `exiftool`, `ffmpeg` wrappers provided.
