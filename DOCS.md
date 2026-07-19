# OmniGet Reference Documentation 📚

OmniGet is a universal package manager wrapper and developer environment manager for Windows. It provides a unified command-line interface to manage software across **WinGet**, **Chocolatey**, **Scoop**, **Pip**, **NPM**, **Cargo**, and **Nuget**, alongside shell profile and environment variable managers.

---

## 🚀 Installation & Setup

### Native Setup Installer
Run the compiled `OmniGetSetup.exe` (or `OmniGetSetup-x86.exe` on 32-bit systems) to automatically:
1. Deploy binaries to `%LOCALAPPDATA%\OmniGet`.
2. Configure your user environment `PATH`.
3. Auto-detect installed managers and prompt to **bootstrap missing package managers** (Scoop, Chocolatey).
4. Order priority cascades and configure WinGet User-Scope silent bypass options.

### PowerShell Setup Function
If you are running the script raw, paste this shortcut block into your `$PROFILE`:
```powershell
function omniget {
    & "C:\Path\To\OmniGet.ps1" @args
}
```

---

## 🛠️ Package Manager Commands

### `install`
Installs an application. It will attempt to install via your highest priority package manager. If it fails, it cascades to the next one automatically.
```powershell
omniget install git
```
* **Specific Manager**: Use `omniget install pylint --pm pip` or `omniget install eslint --pm npm` to route to runtime packages.
* **Passthrough**: Any custom flags (e.g. `--version 1.0.0`) are forwarded down to the underlying manager.

### `upgrade`
Upgrades a specific package.
```powershell
omniget upgrade vlc
```
**System Update:** Use the `all` keyword to upgrade everything across active managers. It runs **conflict resolution** before updating to ensure packages aren't duplicated across managers.
```powershell
omniget upgrade all
```

### `uninstall`
Removes an application, searching through all package managers to find where it was installed.
```powershell
omniget uninstall nodejs
```

### `search`
Concurrently searches for packages matching the query across all active managers using PowerShell Runspaces.
```powershell
omniget search python
```

### `list`
Concurrently lists all installed packages on your system, categorized by the package manager tracking them.
```powershell
omniget list
```

---

## 🌐 Environment & PATH Commands

### `env`
Manages system and user environment variables.
* **`omniget env show`**: Lists all User and System variables.
* **`omniget env set <name> <value> [--system]`**: Sets the variable and broadcasts `WM_SETTINGCHANGE` globally so that open shells and system explorer detect it instantly without restarting.
* **`omniget env remove <name> [--system]`**: Deletes the variable and broadcasts changes.

### `path`
Manages folder paths inside the environment `PATH` variable safely.
* **`omniget path show`**: Displays user and system path entries line-by-line.
* **`omniget path add <folder> [--system] [--prepend]`**: Appends or prepends a directory to `PATH`. Prevents duplicate entries.
* **`omniget path remove <folder> [--system]`**: Safely removes a directory from `PATH`.

---

## 🩺 System Diagnostic commands

### `doctor`
* Runs a conflict check to see if packages are installed on multiple managers.
* Audits the **User PATH** for dead paths (folders that do not exist) and duplicate declarations, offering a prompt to clean them.
* **`omniget doctor --system`**: Runs path health checks on the **System PATH** specifically (isolated for safety).

---

## 💾 Backup, Sync & Profiles

### `export`
Exports your current installed package list. Supports `.json` (keeps package manager metadata) and `.txt` (raw text list).
```powershell
omniget export backup.json
omniget export package_list.txt
```

### `import`
Reinstalls package lists from export files.
```powershell
omniget import backup.json
```

### `sync`
Declaratively synchronizes your system state to match a package file. Installs missing packages and uninstalls any package currently tracked that is not listed in the sync file.
```powershell
omniget sync state_file.json
```

### `profile`
Saves and switches user environment profiles.
* **`omniget profile save <name>`**: Saves all current user environment variables and PATH configurations.
* **`omniget profile switch <name>`**: Swaps your active user environment to the target profile variables and broadcasts changes globally.

---

## 👥 Shell Alias Manager

### `alias`
Registers persistent shell command shortcuts inside your PowerShell profile.
* **`omniget alias add <name> <command>`**: Registers a persistent function in `$PROFILE`.
* **`omniget alias list`**: Shows custom aliases managed by OmniGet.
* **`omniget alias remove <name>`**: Safely prunes the alias function block.

---

## ⚙️ Interactive Terminal UI (`ui`)

Run `omniget ui` to open the Terminal menu. Key integrations:
* **Batch Install (Option 7)**: Search packages, select multiple entries using comma lists (e.g. `1,3`), and batch-install them in one action.
* **Batch Upgrade (Option 8)**: Lists all outdated packages, allowing selective checkbox upgrades.
