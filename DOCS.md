# OmniGet Documentation 📚

OmniGet is a universal package manager wrapper for Windows. It provides a unified command-line interface to manage software across **WinGet**, **Chocolatey**, and **Scoop**.

---

## 🚀 Installation

### Option 1: Native Executable Installer (Recommended)
Run the `OmniGetSetup.exe` file included in the release. This will automatically:
1. Configure your system `PATH`.
2. Walk you through setting your package manager priority.

### Option 2: Manual Script Usage
If you prefer running the raw PowerShell script:
1. Open PowerShell and edit your profile:
   ```powershell
   notepad $PROFILE
   ```
2. Add the following function to the bottom of the file (adjust the path to point to your script):
   ```powershell
   function omniget {
       & "C:\Path\To\OmniGet.ps1" @args
   }
   ```
3. Restart PowerShell. You can now use `omniget` from anywhere!

---

## 🛠️ Core Commands

OmniGet enhances these standard commands to work across all your installed package managers simultaneously:

### `install`
Installs an application. It will attempt to install via your highest priority package manager. If it fails, it cascades to the next one automatically.
```powershell
omniget install nodejs
```

### `upgrade`
Upgrades a specific package.
```powershell
omniget upgrade vlc
```
**System-Wide Update:** Use the `all` keyword to upgrade *everything* across your system cleanly, with a color-coded summary at the end.
```powershell
omniget upgrade all
```

### `uninstall`
Removes an application, searching through all package managers to find where it was installed.
```powershell
omniget uninstall python
```

### `search`
Finds packages matching your search term across all active package managers.
```powershell
omniget search powertoys
```

### `list`
Displays a list of all installed packages on your system, categorized by the package manager that tracks them.
```powershell
omniget list
```

### `info`
Shows detailed information about a specific package.
```powershell
omniget info firefox
```

### `outdated`
Scans your system and lists all applications that currently have updates available.
```powershell
omniget outdated
```

### `doctor`
Scans your system for duplicate installations (e.g., an app installed via both WinGet and Chocolatey) and helps you resolve the conflicts.
```powershell
omniget doctor
```

### `config`
Manage your OmniGet priority cascade settings.
* `omniget config show` - Displays your current priority order.
* `omniget config reset` - Deletes your configuration and launches the Priority Wizard to set it up again.

### `ui`
Launches the interactive Terminal User Interface (TUI), allowing you to manage packages using an elegant menu system without typing commands.
```powershell
omniget ui
```

---

## 🚩 Global Flags

You can append these flags to modify OmniGet's behavior:

| Flag | Description |
|---|---|
| `--dry-run` | **Safe Mode**: Simulates the command without actually installing, upgrading, or modifying your system. It prints exactly what the script *would* execute behind the scenes. |
| `--pm <manager>` | **Targeted Mode**: Forces OmniGet to exclusively use the specified package manager (e.g., `--pm scoop`). It ignores your priority cascade. |
| `--no-cascade` | **Strict Priority**: Tells OmniGet to only attempt the command on your #1 priority package manager. If it fails, it will stop instead of falling back to the next one. |
| `-v`, `--version`| Displays the current version of OmniGet and the versions of your installed package managers. |
| `--info` | Displays general system information and diagnostics for your package managers. |
| `-?`, `--help` | Prints the OmniGet help menu. |

**Example of combining flags:**
```powershell
omniget upgrade all --pm choco --dry-run
```

---

## ⚙️ Configuration & Priority Cascade

The core feature of OmniGet is the **Priority Cascade**. When you first run the script or run `omniget config reset`, you are prompted to set the order of your package managers.

For example, if you set your priority to: `winget -> choco -> scoop`

When you type `omniget install git`, OmniGet will:
1. Attempt to install `git` via `winget`.
2. If `winget` fails or the package isn't found, it gracefully catches the error and moves to `choco`.
3. If `choco` fails, it tries `scoop`.

Your configuration is safely saved in your user directory at `~/.omniget_config.json`.

---

## 🎯 Native Passthrough Commands

OmniGet acts as a transparent proxy. Any flag you pass that OmniGet doesn't explicitly recognize (like `--exact`, `--version 2.0.0`, etc.) is seamlessly passed down to the underlying package managers.

Additionally, standard WinGet commands that don't need multi-manager logic are natively passed through. This means you can still use commands like:
* `omniget source`
* `omniget hash`
* `omniget settings`
* `omniget pin`
* `omniget features`
