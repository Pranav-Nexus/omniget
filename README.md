# OmniGet 📦

A sleek, universal PowerShell wrapper and environment orchestrator for Windows. OmniGet brings **WinGet**, **Chocolatey**, and **Scoop** under a single, unified CLI interface, alongside advanced tools to manage environment variables, PATH settings, shell aliases, and declarative package synchronizations.

---

## ✨ Features

* **🚀 Parallel Execution Engine**: Read-only queries (`search`, `list`, `outdated`) execute concurrently across active package managers using PowerShell Runspaces, completing operations 2-3x faster.
* **🌐 Live Environment Variable Manager (`omniget env`)**: Create, list, or delete environment variables. Set operations instantly broadcast `WM_SETTINGCHANGE` globally, updating active shells and system processes without requiring a reboot.
* **🛣️ Intelligent PATH Manager (`omniget path`)**: List, append, or prepend folders to your environment `PATH` with built-in duplicate prevention.
* **🩺 Path & Environment Doctor (`omniget doctor`)**: Cleans dead paths (folders that no longer exist) and duplicate path entries. Audits User PATH by default; audits System PATH only when explicitly running `omniget doctor --system`.
* **🔄 Declarative Synchronization (`omniget sync`)**: Align your machine's package catalog with a state file. Installs missing tools and prunes extraneous tools automatically.
* **💾 Backup & Restore (`omniget export` / `omniget import`)**: Export installed catalog files to structured `.json` or raw `.txt` files and restore them on new environments.
* **🎭 Environment Profiles (`omniget profile`)**: Save current environment layouts and switch between them instantly (e.g. toggling development toolchains).
* **👥 Persistent Alias Manager (`omniget alias`)**: Easily register persistent command shortcuts inside your PowerShell `$PROFILE`.
* **⚙️ Priority Cascade & Wizards**: Route installs based on custom priorities. The wizard checks for missing managers and offers interactive console/GUI checks to bootstrap them on setup.
* **🛡️ UAC-Bypass User-Scope installs**: Runs silent user-scope installs for WinGet non-elevated to bypass Windows admin prompts.
* **TUI (Terminal UI)**: Run `omniget ui` to manage your system via a keyboard-interactive ANSI menu, now with **Batch Installs** and **Batch Upgrades** via selection checkboxes.

---

## 🚀 Installation

### Option 1: Via WinGet (Recommended)
You can install OmniGet natively through WinGet:
```powershell
winget install -e --id Nexus.OmniGet
```

### Option 2: Native Setup Installer
Download the `OmniGetSetup.exe` binary from the latest GitHub Release. The installer:
1. Automatically deploys the application files to `%LOCALAPPDATA%\OmniGet`.
2. Prompts to **bootstrap missing package managers** (Scoop, Chocolatey).
3. Configures your user environment `PATH`.
4. Launches the setup wizard to configure priority cascades and bypass options.

---

## 📚 Examples & Usage

### 📦 Package Management

```powershell
# Cascade install across WinGet, Choco, Scoop
omniget install nodejs

# Update all outdated applications and print a color-coded summary table
omniget upgrade all

# Search all registries concurrently
omniget search python

# List all tracked packages concurrently
omniget list
```

### ⚙️ Environment Variables & PATH

```powershell
# Display all environment variables
omniget env show

# Set user-level variable and broadcast globally (takes effect instantly)
omniget env set MY_API_KEY "secret_value"

# Add a folder safely to User PATH (prevents duplicates)
omniget path add "C:\MyCustomBin"

# Audit PATH issues, cleaning dead folders and duplicates on User PATH
omniget doctor

# Audit and prune System PATH specifically (requires Admin)
omniget doctor --system
```

### 💾 Backup, Sync & Profiles

```powershell
# Backup package catalog to JSON or plain TXT
omniget export my_backup.json

# Restore from a backup catalog
omniget import my_backup.json

# Declaratively sync system state to match package list
omniget sync my_backup.json

# Save environment profile
omniget profile save node-dev

# Load environment profile
omniget profile switch python-dev
```

### 👥 Shell Customization

```powershell
# Register persistent shortcut in PowerShell $PROFILE
omniget alias add g git

# List custom shortcuts
omniget alias list
```

---

## ⚙️ Configuration & Priority Cascade

OmniGet config is stored at `~/.omniget_config.json`.
* **Show config**: `omniget config show`
* **Reset wizard**: `omniget config reset` (initiates configuration and lets you bootstrap missing managers).

---

## 🚩 Global Flags

| Flag | Description |
|---|---|
| `--dry-run` | **Safe Mode**: Previews execution commands without making changes. |
| `--pm <manager>` | **Targeted Mode**: Forces routing through a specific manager (e.g. `winget`, `choco`, `scoop`, `pip`, `npm`, `cargo`, `nuget`). |
| `--no-cascade` | **Strict Priority**: Stops execution if the highest priority manager fails. |
| `-v`, `--version` | Displays version and underlying manager configurations. |
| `-?`, `--help` | Prints the help menu. |
