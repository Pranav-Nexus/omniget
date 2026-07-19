# OmniGet 📦

A sleek, universal PowerShell wrapper for the three most popular Windows package managers: **WinGet**, **Chocolatey**, and **Scoop**.

Instead of remembering the nuances of three different CLIs, use the `omniget` command to systematically search, install, upgrade, and manage software across your entire ecosystem.

---

## ✨ Features

* **Universal Operations**: Use standard commands like `install`, `upgrade`, `uninstall`, `search`, and `list` across all managers simultaneously.
* **Cascading Fallbacks**: Automatically search and install apps using WinGet. If it fails, it gracefully falls back to Chocolatey, and then to Scoop.
* **Smart Upgrades**: When running `install` or `upgrade`, OmniGet detects which package manager tracks the tool and routes requests to prevent conflicting duplicate installations.
* **Safe & Zero-Config**: Safely skips missing package managers without throwing PowerShell errors.
* **🛡️ Non-Elevated / UAC-Bypass Mode**:
  * **WinGet User-Scope**: If `UserScopeInstall` is enabled, running OmniGet in a non-elevated prompt automatically appends `--scope user --disable-interactivity` to WinGet. This allows packages to install within the current user profile, completely bypassing Windows User Account Control (UAC) administrator popup prompts.
  * **Chocolatey Non-Admin Refinement**: Automatically detects non-elevated environments and omits silent flags (`-y` and `--silent`) when falling back to Chocolatey to prevent silent failures on privilege checks.
* **TUI (Terminal UI)**: Run `omniget ui` to manage your packages via an elegant interactive terminal interface using ANSI escape sequences.
* **Conflict Doctor**: Run `omniget doctor` to scan for redundant installations of the same app across different package managers and help resolve conflict states.
* **Dry-Run Safe Mode**: Append `--dry-run` to commands to preview actions before making system modifications.
* **Argument Passthrough**: Seamlessly pass custom flags down to the underlying tools.

---

## 🚀 Installation

### Option 1: Via WinGet (Recommended)
You can install OmniGet natively through WinGet itself:
```powershell
winget install -e --id Nexus.OmniGet
```

### Option 2: Native Setup Installer
Download the `OmniGetSetup.exe` binary from the latest GitHub Release. The installer:
1. Automatically deploys the application files to `%LOCALAPPDATA%\OmniGet`.
2. Configures your user environment `PATH`.
3. Launches the **Setup Priority Wizard** to configure your package manager priority cascade and User-Scope install preferences.

### Option 3: Manual Script Setup
If you prefer running the raw PowerShell script:
* **Option A: Add to PATH**: Add the directory containing [OmniGet.ps1](file:///c:/Users/harih/Documents/Open_Source_Contribution/My%20Projects/Install%20Script/OmniGet.ps1) to your user `PATH`.
* **Option B: PowerShell Profile**: Open your profile using `notepad $PROFILE` and paste the contents of `OmniGet.ps1` at the bottom.
* **Option C: Dot-Source**: Add `. "C:\Path\To\OmniGet.ps1"` to your PowerShell profile.

---

## 📚 Examples & Usage

### Installing Packages
Installs packages cascading through WinGet ➔ Chocolatey ➔ Scoop until successful:
```powershell
omniget install nodejs
```
Pass specific versions or custom arguments:
```powershell
omniget install vlc --version 3.0.0
```

### Upgrading Packages
Check for available updates across all active package managers:
```powershell
omniget outdated
```
Update all outdated packages on your system and get a formatted summary:
```powershell
omniget upgrade all
```

### Searching & Listing
Search all active registries for a package simultaneously:
```powershell
omniget search powertoys
```
List all installed packages tracked by your managers:
```powershell
omniget list
```

### System Diagnostics & Doctor
Run a system-wide scan to detect and resolve duplicate installations (e.g. VLC installed on both WinGet and Scoop):
```powershell
omniget doctor
```

### Terminal TUI Menu
Launch the interactive Terminal User Interface:
```powershell
omniget ui
```

---

## ⚙️ Configuration & Priority Cascade

OmniGet stores your configurations in your user profile at `~/.omniget_config.json`.

### Managing Config
* **Show configuration**:
  ```powershell
  omniget config show
  ```
  This displays your current priority cascade order and if User-Scope (UAC-Bypass) installs are enabled.
* **Reset & Reconfigure**:
  ```powershell
  omniget config reset
  ```
  Launches the interactive setup wizard to configure your settings again.

---

## 🚩 Global Flags

Modify OmniGet commands using these optional flags:

| Flag | Description |
|---|---|
| `--dry-run` | **Safe Mode**: Simulates the command without executing writes. Shows commands that would run. |
| `--pm <manager>` | **Targeted Mode**: Forces OmniGet to target a specific manager (e.g., `--pm scoop`), ignoring the cascade. |
| `--no-cascade` | **Strict Priority**: Stops execution if the highest priority manager fails, rather than falling back. |
| `-v`, `--version` | Displays OmniGet version and active package manager details. |
| `-?`, `--help` | Prints the help menu. |

---

## 🛠️ Prerequisites
At least **one** of the following must be installed:
* [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (Pre-installed on modern Windows 10/11)
* [Chocolatey](https://chocolatey.org/)
* [Scoop](https://scoop.sh/)
