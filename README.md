# OmniGet 📦

A sleek, universal PowerShell wrapper for the three most popular Windows package managers: **WinGet**, **Chocolatey**, and **Scoop**.

Instead of remembering the nuances of three different CLIs, use the `omniget` (or `app`) command to systematically search, install, upgrade, and manage software across your entire ecosystem.

## ✨ Features
* **Universal Operations**: Use standard commands like `install`, `upgrade`, `uninstall`, `search`, and `list` across all managers simultaneously.
* **Cascading Fallbacks**: Automatically tries to find or install an app using WinGet first. If it fails, it gracefully falls back to Chocolatey, and then to Scoop.
* **Smart Upgrades**: When running `install` or `upgrade`, it detects which package manager primarily tracks the tool and routes requests to prevent conflicting states.
* **Safe & Zero-Config**: If a package manager is missing on a workstation, it safely skips it without throwing ugly PowerShell errors.
* **Argument Passthrough**: Append custom flags like `--version` and they are seamlessly passed down to the underlying tools.

## 🚀 Installation

There are two primary ways to setup OmniGet natively:

### Option A: Edit your PowerShell Profile (Recommended)
1. Open PowerShell and type:
   ```powershell
   notepad $PROFILE
   ```
2. Paste the contents of `OmniGet.ps1` at the very bottom of the document.
3. Save, restart PowerShell, and use `app` natively!

### Option B: Dot-Source the Script
Keep `OmniGet.ps1` somewhere on your computer and simply dot-source it in your profile:
```powershell
. "C:\Path\To\Your\Folder\OmniGet.ps1"
```

## 📚 Examples & Usage

Installs cascading through WinGet ➔ Chocolatey ➔ Scoop until successful:
```powershell
app install nodejs
```

Pass down specific versions or arguments:
```powershell
app install vlc --version 3.0.0
```

Update everything on your system (across all 3 package managers!):
```powershell
app upgrade all
```

Search across all registries simultaneously to see where a tool lives:
```powershell
app search powertoys
```

View your system's entire managed software catalog:
```powershell
app list
```

Remove an application seamlessly regardless of how it was installed:
```powershell
app uninstall python
```

## 🛠️ Prerequisites
At least **one** of the following must be installed on your Windows machine:
* [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (Pre-installed on modern Windows 10/11)
* [Chocolatey](https://chocolatey.org/)
* [Scoop](https://scoop.sh/)
