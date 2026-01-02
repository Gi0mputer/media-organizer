# Batch Media Tools

A collection of batch and PowerShell scripts for organizing, processing, and maintaining photo and video collections.

## Prerequisites

*   **ffmpeg** and **ffprobe**: Must be installed and available in your system PATH.
*   **ExifTool**: Required for metadata operations. The scripts check for it in the system PATH or next to the script.
*   **Windows**: These scripts are designed for Windows (Batch + PowerShell).

## Scripts Overview

### Video Processing

*   **`Downscale1920_HEVC.bat`**
    *   **Purpose**: Downscales videos to 1920px (long edge) using HEVC (NVENC) compression.
    *   **Usage**: Drag and drop video files onto the script.
    *   **Features**: Preserves original file dates and metadata. Skips files that are already processed.

*   **`SmartDownscale_1920.bat`**
    *   **Purpose**: Similar to `Downscale1920_HEVC.bat` but with smarter logic.
    *   **Usage**: Drag and drop video files.
    *   **Features**: Checks dimensions first and skips if the video is already <= 1920px. Tries HEVC first, falls back to H.264 if HEVC fails.

*   **`Converti-4K-a-1080p.bat`** (calls `Converti-4K-a-1080p.ps1`)
    *   **Purpose**: Bulk converts 4K videos to 1080p and separates High FPS videos.
    *   **Usage**: Run from command line with parameters: `-Root <source> -OutputBase <destination>`
    *   **Features**: Recursive scan, separates "4K" and "HighFPS" into different output folders.

*   **`Repair_Insta360_INS_Videos.bat`**
    *   **Purpose**: Repairs corrupted `.insv` or `.mp4` files (e.g., from Insta360 cameras) using `untrunc`.
    *   **Usage**: `Repair_Insta360_INS_Videos.bat <ReferenceVideo> [InputFolder]`
    *   **Requirements**: Requires a working "reference" video from the same camera and `untrunc.exe`.

*   **`RiparaMini5.bat`**
    *   **Purpose**: Fixes playback issues (lag, startup blocks) often found in DJI Mini 5 videos or LosslessCut exports.
    *   **Usage**: Drag and drop files. Use `/overwrite` flag to replace originals.
    *   **Features**: Resets timestamps and moves `moov` atom to the beginning (Fast Start).

*   **`fixTimestamp.bat`**
    *   **Purpose**: Simple utility to reset timestamps in MP4/MOV containers.
    *   **Usage**: Drag and drop files. **Warning**: Overwrites originals by default.

### Organization & Diagnostics

*   **`Dates_Diagnostics_PLUS_Console.bat`** (calls `Dates_Diagnostics.ps1`)
    *   **Purpose**: Analyzes file dates comparing FileSystem dates vs. Internal Metadata (EXIF/QuickTime).
    *   **Usage**: Drag and drop a folder to scan.
    *   **Output**: Displays a summary of file types and which date sources are available/best.

*   **`DuplicateCleaner_KeepDeepest.bat`** (calls `DuplicateCleaner.ps1`)
    *   **Purpose**: Finds duplicate files based on **Name + Size**.
    *   **Usage**: Drag and drop a folder.
    *   **Logic**: Keeps the copy that is "deepest" in the directory structure. If depth is equal, keeps the oldest one.
    *   **Modes**: Default is DRY-RUN (preview). Use `/go` flag to actually delete (move to Recycle Bin).

*   **`Check_ExifTool.bat`**
    *   **Purpose**: Diagnostic utility to check if ExifTool is correctly installed and detected.

## Installation

1.  Clone or download this repository.
2.  Ensure dependencies (ffmpeg, ffprobe, exiftool) are in your PATH.
3.  Drag and drop files/folders onto the `.bat` scripts as needed.

## Notes

- **IMPORTANT**: ffmpeg and exiftool are NOT included. You must install them separately.
- All scripts have been refactored from Italian to English.
- Most destructive operations require confirmation or have a DRY-RUN mode first.
