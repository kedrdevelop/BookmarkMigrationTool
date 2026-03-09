# 🔖 Chrome to Edge Bookmark Migrator

A sleek, GUI-driven utility for safe and automatic bookmark migration from Google Chrome to Microsoft Edge.

This application automatically locates active browser profiles, creates secure backups, generates new GUIDs to prevent synchronization conflicts, and seamlessly integrates the imported folders directly into Edge's JSON structure.

## 🏗 Architecture: Why Two Different Solutions?

The core feature of this repository is that it provides two completely different implementations for the exact same task. Both versions share an identical **Material Design 3 (Dark Theme)** user interface, but they work completely differently under the hood.

This separation was born out of necessity to navigate strict corporate security environments:

### 1. The Classic Version (C# / WPF / `.exe`)
* **Location:** `Source_CSharp` folder
* **Description:** The standard, robust engineering approach. It compiles into a Self-Contained Single File executable with the .NET 8 runtime embedded. It's fast, reliable, and asynchronous.
* **The Problem:** In corporate networks with Zero Trust architectures (featuring aggressive AppLocker or SmartScreen policies), running unsigned `.exe` files downloaded from an intranet or the internet is often strictly blocked.

### 2. The Corporate Bypass (PowerShell Polyglot / `.bat`)
* **Location:** `BookmarkMigrator.bat`
* **Description:** An elegant workaround for restrictive security policies. The entire JSON parsing logic and the raw XAML UI markup are bundled into a single hybrid `.bat` file. It silently invokes the system's PowerShell in the background, bypasses the `ExecutionPolicy`, and renders a fully functional WPF graphical window using `PresentationFramework`.
* **The Result:** The extraction method changes completely, but the end-user experience remains flawless. Windows natively trusts the script execution, allowing users to access the polished UI without triggering security blocks.

## ✨ Key Features

* **Advanced JSON Parsing:** Directly modifies the Chromium `Bookmarks` files without relying on third-party libraries. Uses native .NET methods to save files strictly without BOM (Byte Order Mark) to ensure Edge engine compatibility.
* **Safety First (Rollback):** Automatically backs up original files to the Desktop before making any changes. If parsing fails or file access is denied, the system triggers an automatic rollback and displays an error screen with developer contact information.
* **Modern UI:** The interface remains responsive during migration (utilizing C# `async/await` and PowerShell `[System.Windows.Forms.Application]::DoEvents()`). Features a multi-step visual progress indicator (Stepper) and bilingual support (German / English).
* **Process Management:** Safely terminates background browser processes to release file locks, while gracefully ignoring `SYSTEM` level processes to prevent script crashes.

## 🚀 How to Use

### Running the C# Version:
1. Compile the project via CLI:  
   `dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true`
2. Retrieve the generated `.exe` from the `publish` folder and run it.

### Running the Polyglot (.bat) Version:
1. Download the `BookmarkMigrator.bat` file.
2. Double-click it. The console window will hide automatically, presenting you directly with the WPF graphical interface.

---
*Designed for seamless user onboarding in strict corporate ecosystems.*