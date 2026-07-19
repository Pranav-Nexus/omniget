<#
    .SYNOPSIS
    A universal wrapper for Windows package managers (WinGet, Chocolatey, Scoop, and more).

    .DESCRIPTION
    The 'omniget' command provides a unified interface to install, update, remove, search, and manage packages across your entire Windows ecosystem. 
    It cascades through installed package managers based on your custom configuration order.
    If a package manager is not installed, it safely skips it.
    #>
$Action = ""
$Name = ""
$RemainingArgs = @()

$DryRun = $false
$NoCascade = $false
$TargetPM = ""

for ($i = 0; $i -lt $args.Count; $i++) {
    $a = $args[$i]
    if ($a -eq "--dry-run") { $DryRun = $true }
    elseif ($a -eq "--no-cascade") { $NoCascade = $true }
    elseif ($a -eq "--pm" -and ($i + 1) -lt $args.Count) {
        $i++
        $TargetPM = $args[$i].ToLower().Trim()
    }
    elseif ($Action -eq "" -and -not $a.StartsWith("-")) {
        $Action = $a
    }
    elseif ($Name -eq "" -and -not $a.StartsWith("-") -and $Action -ne "") {
        $Name = $a
    }
    else {
        $RemainingArgs += $a
    }
}

function Show-Help {
    Write-Host "OmniGet Universal Package Manager & Environment Manager" -ForegroundColor Cyan
    Write-Host "A unified tool for WinGet, Chocolatey, Scoop, Pip, NPM, Cargo, Nuget, and Environment variables.`n"
    
    Write-Host "usage: omniget [<command>] [<package_name>] [<options>]`n" 

    Write-Host "The following commands are natively enhanced by OmniGet:" -ForegroundColor Yellow
    Write-Host "  install    Installs the given package across configured PMs"
    Write-Host "  upgrade    Shows and performs available upgrades (use 'all' for system update)"
    Write-Host "  uninstall  Uninstalls the given package"
    Write-Host "  search     Find and show basic info of packages (parallelized)"
    Write-Host "  list       Display installed packages (parallelized)"
    Write-Host "  info       Shows information about a package"
    Write-Host "  outdated   Shows all available upgrades across configured PMs (parallelized)"
    Write-Host "  doctor     Scans for duplicated packages and audits PATH health"
    Write-Host "  config     Manage priority settings ('show' or 'reset')"
    Write-Host "  ui         Launch Interactive Terminal UI (TUI)"
    Write-Host "  gui        Launch Graphical UI (GUI placeholder)`n"
    
    Write-Host "Unified Environment & Backup Commands:" -ForegroundColor Yellow
    Write-Host "  env        Manage environment variables ('show', 'set', 'remove')"
    Write-Host "  path       Manage Windows environment PATH ('show', 'add', 'remove')"
    Write-Host "  profile    Save and switch environment profiles ('save', 'switch')"
    Write-Host "  alias      PowerShell custom persistent alias manager ('add', 'remove', 'list')"
    Write-Host "  bootstrap  Install missing package managers ('scoop', 'choco', 'winget')"
    Write-Host "  export     Backup installed package catalog to JSON/TXT file"
    Write-Host "  import     Restore package catalog from JSON/TXT backup file"
    Write-Host "  sync       Declaratively synchronize installed packages with a state file"
    Write-Host "  pin        Control upgrades / hold packages ('add', 'remove', 'list')"
    Write-Host "  history    View OmniGet installation audit trails`n"

    Write-Host "The following options are available:" -ForegroundColor Yellow
    Write-Host "  --dry-run                   Mock execution without installing or modifying anything"
    Write-Host "  --pm <manager>              Force execution using only the specified manager"
    Write-Host "  --no-cascade                Stop if the first package manager fails (no fallback)"
    Write-Host "  -v,--version                Display the version of the tool"
    Write-Host "  --info                      Display general info of the tool"
    Write-Host "  -?,--help                   Shows help about the selected command"
}

$actionLower = $Action.ToLower().Trim()
$OmniGetVersion = "v1.0.4"

# Global flags
if ($actionLower -in @("-v", "--version") -or $RemainingArgs -contains "-v" -or $RemainingArgs -contains "--version") {
    Write-Host "OmniGet $OmniGetVersion" -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) { $wVer = winget --version | Select-Object -First 1; Write-Host "WinGet: $wVer" -ForegroundColor DarkGray }
    if (Get-Command choco -ErrorAction SilentlyContinue) { $cVer = choco -v | Select-Object -First 1; Write-Host "Chocolatey: $cVer" -ForegroundColor DarkGray }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { $sVer = scoop -v | Select-Object -First 1; Write-Host "Scoop: $sVer" -ForegroundColor DarkGray }
    if (Get-Command pip -ErrorAction SilentlyContinue) { $pVer = pip -V | Select-Object -First 1; Write-Host "Pip: $pVer" -ForegroundColor DarkGray }
    if (Get-Command npm -ErrorAction SilentlyContinue) { $nVer = npm -v | Select-Object -First 1; Write-Host "NPM: $nVer" -ForegroundColor DarkGray }
    if (Get-Command cargo -ErrorAction SilentlyContinue) { $caVer = cargo -V | Select-Object -First 1; Write-Host "Cargo: $caVer" -ForegroundColor DarkGray }
    return
}

if ($RemainingArgs -contains "--info" -or ($actionLower -eq "info" -and $Name -eq "")) {
    Write-Host "OmniGet System Information ($OmniGetVersion)" -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) { winget --info }
    if (Get-Command choco -ErrorAction SilentlyContinue) { Write-Host "`n[Chocolatey]" -ForegroundColor Yellow; choco info chocolatey 2>$null }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { Write-Host "`n[Scoop]" -ForegroundColor Green; scoop info scoop 2>$null }
    return
}

if ($actionLower -eq "" -or $actionLower -in @("-?", "--help", "help") -or $RemainingArgs -contains "-?" -or $RemainingArgs -contains "--help") {
    Show-Help
    return
}

# Normalize aliases
if ($actionLower -eq "update")  { $actionLower = "upgrade" }
if ($actionLower -eq "remove")  { $actionLower = "uninstall" }
if ($actionLower -eq "view")    { $actionLower = "show" }
if ($actionLower -eq "find")    { $actionLower = "search" }
if ($actionLower -eq "priority") { $actionLower = "config"; $Name = "reset" }

# Handle 'update all'
if ($actionLower -eq "upgrade" -and ($Name -ieq "all" -or $RemainingArgs -contains "--all" -or $RemainingArgs -contains "-all")) {
    $actionLower = "all"
    $RemainingArgs = @($RemainingArgs | Where-Object { $_ -ne "--all" -and $_ -ne "-all" })
    $Name = ""
}

# Helper Functions
function Write-OmniLog {
    param(
        [string]$ActionType,
        [string]$Status,
        [string]$PackageManager,
        [string]$PackageName
    )
    $logDir = Join-Path $env:USERPROFILE ".omniget"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $logFile = Join-Path $logDir "history.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$ActionType] [$Status] [$PackageManager] $PackageName"
    Add-Content -Path $logFile -Value $logLine
}

function Broadcast-EnvChange {
    $code = @"
    using System;
    using System.Runtime.InteropServices;
    public class WinAPI {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, IntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
    }
"@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
    $result = [IntPtr]::Zero
    [WinAPI]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [IntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
}

function Invoke-ParallelPM {
    param(
        [scriptblock]$ScriptBlock
    )
    $runspaces = @()
    foreach ($pm in $activePriority) {
        $rsp = [powershell]::Create()
        $null = $rsp.AddScript($ScriptBlock)
        $null = $rsp.AddArgument($pm)
        $null = $rsp.AddArgument($Name)
        $null = $rsp.AddArgument($RemainingArgs)
        $rsp.Runspace.SessionStateProxy.SetVariable("DryRun", $DryRun)
        $rsp.Runspace.SessionStateProxy.SetVariable("wgFlags", $wgFlags)
        $rsp.Runspace.SessionStateProxy.SetVariable("chFlags", $chFlags)
        $rsp.Runspace.SessionStateProxy.SetVariable("scFlags", $scFlags)
        $asyncResult = $rsp.BeginInvoke()
        $runspaces += [PSCustomObject]@{
            Instance = $rsp
            AsyncResult = $asyncResult
            PM = $pm
        }
    }
    foreach ($r in $runspaces) {
        while (-not $r.AsyncResult.IsCompleted) {
            Start-Sleep -Milliseconds 50
        }
        try {
            $output = $r.Instance.EndInvoke($r.AsyncResult)
            if ($output) {
                foreach ($line in $output) {
                    if ($null -ne $line) { Write-Host $line }
                }
            }
        } catch {
            Write-Error "Error executing query for $($r.PM): $_"
        }
        $r.Instance.Dispose()
    }
}

# Config file path
$configFile = Join-Path $env:USERPROFILE ".omniget_config.json"
$userScopeInstall = $true

# Pre-load UserScopeInstall setting if config exists
if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($null -ne $config.UserScopeInstall) {
            $userScopeInstall = [bool]$config.UserScopeInstall
        }
    } catch {}
}

# Admin elevation check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$wgFlags = @("--silent", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")
if (-not $isAdmin -and $userScopeInstall) {
    $wgFlags += @("--scope", "user")
}
$chFlags = @("-y", "--silent")
if (-not $isAdmin) {
    $chFlags = @()
}
$scFlags = @()

if ($null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0) {
    $wgFlags += $RemainingArgs
    $chFlags += $RemainingArgs
    $scFlags += $RemainingArgs
}

# Tool Detection
$availablePMs = @()
if (Get-Command winget -ErrorAction SilentlyContinue) { $availablePMs += "winget" }
if (Get-Command choco -ErrorAction SilentlyContinue) { $availablePMs += "choco" }
if (Get-Command scoop -ErrorAction SilentlyContinue) { $availablePMs += "scoop" }
if (Get-Command pip -ErrorAction SilentlyContinue) { $availablePMs += "pip" }
if (Get-Command npm -ErrorAction SilentlyContinue) { $availablePMs += "npm" }
if (Get-Command cargo -ErrorAction SilentlyContinue) { $availablePMs += "cargo" }
if (Get-Command nuget -ErrorAction SilentlyContinue) { $availablePMs += "nuget" }
$hasWsl = [bool](Get-Command wsl -ErrorAction SilentlyContinue)

if ($availablePMs.Count -eq 0) {
    Write-Host "[ERROR] No supported package managers found! You must have WinGet, Chocolatey, or Scoop installed." -ForegroundColor Red
    return
}

# Priority Configuration Wizard
function Invoke-PriorityWizard {
    Write-Host "`nWelcome to OmniGet Configuration Wizard!" -ForegroundColor Cyan
    Write-Host "Let's set your package manager priority order." -ForegroundColor White
    
    # Suggest other package managers if missing
    $missingPMs = @()
    foreach ($m in @("winget", "choco", "scoop", "pip", "npm", "cargo", "nuget")) {
        if (-not (Get-Command $m -ErrorAction SilentlyContinue)) { $missingPMs += $m }
    }
    if ($missingPMs.Count -gt 0) {
        Write-Host "`nNote: The following package managers are not currently installed on your system:" -ForegroundColor Gray
        foreach ($pm in $missingPMs) {
            Write-Host "  - $pm (Install via: omniget bootstrap $pm)" -ForegroundColor DarkGray
        }
    }
    
    $priority = @()
    $remaining = $availablePMs | Select-Object -Unique
    
    while ($remaining.Count -gt 0) {
        $remStr = $remaining -join ', '
        Write-Host "`nAvailable to select: $remStr" -ForegroundColor Yellow
        $cCount = $priority.Count + 1
        $choice = Read-Host "Which one should be priority $cCount ? (type name)"
        $choiceLower = $choice.Trim().ToLower()
        if ($remaining -contains $choiceLower) {
            $priority += $choiceLower
            $remaining = $remaining | Where-Object { $_ -ne $choiceLower }
        }
        else {
            Write-Host "Invalid choice. Please type one of the available names." -ForegroundColor Red
        }
    }

    # Prompt for user scope installs
    $userScopeVal = $true
    $ans = Read-Host "`nEnable User-Scope silent installs for WinGet (Bypasses UAC prompts)? [Y]es / [N]o (default: Yes)"
    if ($ans.Trim() -ne "") {
        if ($ans -match '^[nN]') { $userScopeVal = $false }
    }

    $configData = @{ 
        "Priority" = $priority
        "UserScopeInstall" = $userScopeVal
    }
    $configData | ConvertTo-Json | Set-Content $configFile -Force
    Write-Host "Priority and settings saved successfully!" -ForegroundColor Green
    
    $script:userScopeInstall = $userScopeVal
    return $priority
}

$configPriority = @()
if (-not (Test-Path $configFile)) {
    if ($actionLower -match "ui|gui|config|help") { $configPriority = $availablePMs } else { $configPriority = Invoke-PriorityWizard }
} else {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $configPriority = $config.Priority
        if ($null -ne $config.UserScopeInstall) {
            $userScopeInstall = [bool]$config.UserScopeInstall
        }
    } catch {
        if ($actionLower -match "ui|gui|config|help") { $configPriority = $availablePMs } else { $configPriority = Invoke-PriorityWizard }
    }
}

$activePriority = $configPriority | Where-Object { $availablePMs -contains $_ }
if ($activePriority.Count -eq 0) { $activePriority = $availablePMs }

# Overrides via flags
if ($TargetPM -ne "") {
    if ($availablePMs -contains $TargetPM) {
        $activePriority = @($TargetPM)
        Write-Host "(--pm flag active: Forcing execution strictly via $TargetPM)" -ForegroundColor DarkGray
    } else {
        Write-Host "[ERROR] Specified package manager '$TargetPM' is not installed or invalid." -ForegroundColor Red
        return
    }
}

if ($NoCascade -and $activePriority.Count -gt 0) {
    $activePriority = @($activePriority[0])
    Write-Host "(--no-cascade flag active: Limiting execution strictly to primary manager '$($activePriority[0])')" -ForegroundColor DarkGray
}

if ($DryRun) {
    Write-Host "[DRY-RUN] Execution disabled. Displaying planned actions only.`n" -ForegroundColor Yellow
}

# Main Command Routing
switch ($actionLower) {
    "config" {
        if ($Name.ToLower() -eq "show" -or $Name -eq "") {
            Write-Host "`nOmniGet Current Configuration" -ForegroundColor Cyan
            Write-Host "Configuration File: $configFile" -ForegroundColor DarkGray
            Write-Host "Priority Cascade Order:" -ForegroundColor White
            $i = 1
            foreach ($pm in $configPriority) {
                Write-Host "  $i. $pm" -ForegroundColor Yellow
                $i++
            }
            $scopeStr = if ($userScopeInstall) { "Enabled (User Scope / No-UAC)" } else { "Disabled (System Scope / UAC prompts allowed)" }
            Write-Host "User-Scope Silent Installs: $scopeStr" -ForegroundColor White
            Write-Host ""
        }
        elseif ($Name.ToLower() -eq "reset") {
            if (Test-Path $configFile) {
                Remove-Item $configFile -Force
                Write-Host "Configuration file removed. Resetting..." -ForegroundColor Yellow
            }
            Invoke-PriorityWizard | Out-Null
        }
        else { Write-Host "Invalid config command. Use: 'omniget config show' or 'omniget config reset'" -ForegroundColor Red }
    }
    "ui" {
        $uiRunning = $true
        $ESC = [char]27
        $scriptPath = if ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { "omniget" }
        
        while ($uiRunning) {
            Clear-Host
            Write-Host "$ESC`[36m+============================================+$ESC`[0m"
            Write-Host "$ESC`[36m|           OmniGet Interactive TUI          |$ESC`[0m"
            Write-Host "$ESC`[36m+============================================+$ESC`[0m"
            Write-Host ""
            Write-Host "$ESC`[33m1.$ESC`[0m Install an application"
            Write-Host "$ESC`[33m2.$ESC`[0m Upgrade an application"
            Write-Host "$ESC`[33m3.$ESC`[0m Uninstall an application"
            Write-Host "$ESC`[33m4.$ESC`[0m View outdated applications"
            Write-Host "$ESC`[33m5.$ESC`[0m Upgrade ALL applications on system"
            Write-Host "$ESC`[33m6.$ESC`[0m Configuration Menu (Show/Reset)"
            Write-Host "$ESC`[33m7.$ESC`[0m Batch Install packages"
            Write-Host "$ESC`[33m8.$ESC`[0m Batch Upgrade packages"
            Write-Host "$ESC`[31m0.$ESC`[0m Exit TUI"
            Write-Host ""
            
            $choice = Read-Host -Prompt "Select an option [0-8]"
            
            switch ($choice) {
                "1" { Write-Host ""; $pkg = Read-Host "Enter App to install"; if ($pkg) { & $scriptPath install $pkg } }
                "2" { Write-Host ""; $pkg = Read-Host "Enter App to upgrade"; if ($pkg) { & $scriptPath upgrade $pkg } }
                "3" { Write-Host ""; $pkg = Read-Host "Enter App to uninstall"; if ($pkg) { & $scriptPath uninstall $pkg } }
                "4" { Write-Host ""; & $scriptPath outdated }
                "5" { Write-Host ""; & $scriptPath upgrade all }
                "6" { Write-Host ""; & $scriptPath config show }
                "7" {
                    Write-Host ""
                    $searchTerm = Read-Host "Enter App search query"
                    if ($searchTerm) {
                        Write-Host "Searching packages..." -ForegroundColor Cyan
                        $results = @()
                        foreach ($pm in $activePriority) {
                            if ($pm -eq "winget") {
                                $raw = winget search $searchTerm --disable-interactivity 2>$null
                                foreach ($line in $raw) {
                                    if ($line -match '^\s*([^\s].*?)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}') {
                                        $results += [PSCustomObject]@{ Id = $matches[2].Trim(); Source = "winget"; Selected = $false }
                                    }
                                }
                            }
                            elseif ($pm -eq "choco") {
                                $raw = choco search $searchTerm --limit-output 2>$null
                                foreach ($line in $raw) {
                                    if ($line -match '^([^\|]+)\|') {
                                        $results += [PSCustomObject]@{ Id = $matches[1].Trim(); Source = "choco"; Selected = $false }
                                    }
                                }
                            }
                            elseif ($pm -eq "scoop") {
                                $raw = scoop search $searchTerm 2>$null
                                foreach ($line in $raw) {
                                    if ($line -match '^\s*([a-zA-Z0-9\-\._]+)\s') {
                                        $results += [PSCustomObject]@{ Id = $matches[1].Trim(); Source = "scoop"; Selected = $false }
                                    }
                                }
                            }
                        }
                        $uniqueResults = $results | Group-Object Id | ForEach-Object { $_.Group[0] }
                        
                        if ($uniqueResults.Count -eq 0) {
                            Write-Host "No packages found." -ForegroundColor Yellow
                        } else {
                            $batchRunning = $true
                            while ($batchRunning) {
                                Clear-Host
                                Write-Host "=== Batch Install Search Results ===" -ForegroundColor Cyan
                                Write-Host "Enter package numbers to toggle selection (e.g. '1' or '1,3')." -ForegroundColor Gray
                                Write-Host "Enter 'install' to install selected, or '0' to cancel.`n" -ForegroundColor Gray
                                
                                $i = 1
                                foreach ($r in $uniqueResults) {
                                    $chk = if ($r.Selected) { "[x]" } else { "[ ]" }
                                    Write-Host "  $chk $i. $($r.Id) ($($r.Source))" -ForegroundColor White
                                    $i++
                                }
                                Write-Host ""
                                $cmd = Read-Host "Command"
                                if ($cmd -eq "0") { $batchRunning = $false }
                                elseif ($cmd.ToLower() -eq "install") {
                                    $selected = $uniqueResults | Where-Object { $_.Selected }
                                    if ($selected.Count -eq 0) {
                                        Write-Host "No packages selected." -ForegroundColor Yellow
                                        Start-Sleep -Seconds 1
                                        continue
                                    }
                                    foreach ($s in $selected) {
                                        Write-Host "`n---> Batch Installing $($s.Id) via $($s.Source)..." -ForegroundColor Cyan
                                        & $scriptPath install $($s.Id) --pm $($s.Source)
                                    }
                                    $batchRunning = $false
                                }
                                else {
                                    $parts = $cmd -split ','
                                    foreach ($p in $parts) {
                                        if ([int]::TryParse($p.Trim(), [ref]$idx)) {
                                            if ($idx -ge 1 -and $idx -le $uniqueResults.Count) {
                                                $uniqueResults[$idx - 1].Selected = -not $uniqueResults[$idx - 1].Selected
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                "8" {
                    Write-Host "Scanning for outdated packages..." -ForegroundColor Cyan
                    $outdatedList = @()
                    foreach ($pm in $activePriority) {
                        if ($pm -eq "winget") {
                            $raw = winget upgrade --disable-interactivity 2>$null
                            foreach ($line in $raw) {
                                if ($line -match '^\s*([^\s].*?)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}') {
                                    $outdatedList += [PSCustomObject]@{ Id = $matches[2].Trim(); Source = "winget"; Selected = $false }
                                }
                            }
                        }
                        elseif ($pm -eq "choco") {
                            $raw = choco outdated --limit-output 2>$null
                            foreach ($line in $raw) {
                                if ($line -match '^([^\|]+)\|') {
                                    $outdatedList += [PSCustomObject]@{ Id = $matches[1].Trim(); Source = "choco"; Selected = $false }
                                }
                            }
                        }
                        elseif ($pm -eq "scoop") {
                            $raw = scoop status 2>$null
                            foreach ($line in $raw) {
                                if ($line -match '^\s*([a-zA-Z0-9\-\._]+)\s+\(') {
                                    $outdatedList += [PSCustomObject]@{ Id = $matches[1].Trim(); Source = "scoop"; Selected = $false }
                                }
                            }
                        }
                    }
                    $uniqueOutdated = $outdatedList | Group-Object Id | ForEach-Object { $_.Group[0] }
                    
                    if ($uniqueOutdated.Count -eq 0) {
                        Write-Host "All packages are up-to-date!" -ForegroundColor Green
                    } else {
                        $batchRunning = $true
                        while ($batchRunning) {
                            Clear-Host
                            Write-Host "=== Batch Upgrade Available Upgrades ===" -ForegroundColor Cyan
                            Write-Host "Enter package numbers to toggle selection (e.g. '1' or '1,3')." -ForegroundColor Gray
                            Write-Host "Enter 'upgrade' to upgrade selected, or '0' to cancel.`n" -ForegroundColor Gray
                            
                            $i = 1
                            foreach ($r in $uniqueOutdated) {
                                $chk = if ($r.Selected) { "[x]" } else { "[ ]" }
                                Write-Host "  $chk $i. $($r.Id) ($($r.Source))" -ForegroundColor White
                                $i++
                            }
                            Write-Host ""
                            $cmd = Read-Host "Command"
                            if ($cmd -eq "0") { $batchRunning = $false }
                            elseif ($cmd.ToLower() -eq "upgrade") {
                                $selected = $uniqueOutdated | Where-Object { $_.Selected }
                                if ($selected.Count -eq 0) {
                                    Write-Host "No packages selected." -ForegroundColor Yellow
                                    Start-Sleep -Seconds 1
                                    continue
                                }
                                foreach ($s in $selected) {
                                    Write-Host "`n---> Batch Upgrading $($s.Id) via $($s.Source)..." -ForegroundColor Cyan
                                    & $scriptPath upgrade $($s.Id) --pm $($s.Source)
                                }
                                $batchRunning = $false
                            }
                            else {
                                $parts = $cmd -split ','
                                foreach ($p in $parts) {
                                    if ([int]::TryParse($p.Trim(), [ref]$idx)) {
                                        if ($idx -ge 1 -and $idx -le $uniqueOutdated.Count) {
                                            $uniqueOutdated[$idx - 1].Selected = -not $uniqueOutdated[$idx - 1].Selected
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                "0" { $uiRunning = $false }
                default { Write-Host "Invalid option." -ForegroundColor Red }
            }
            if ($uiRunning) {
                Write-Host "`n$ESC`[90mPress Enter to return to menu...$ESC`[0m" -NoNewline
                $null = Read-Host
            }
        }
    }
    "gui" {
        Write-Host "OmniGet Graphical UI (GUI) is currently under development!" -ForegroundColor Magenta
        Write-Host "We recommend using the Terminal UI in the meantime:`n  omniget ui" -ForegroundColor Gray
    }
    "outdated" {
        Write-Host "Fetching outdated packages in parallel..." -ForegroundColor Cyan
        $outdatedBlock = {
            param($pm, $name, $remArgs)
            if ($pm -eq "winget") {
                Write-Output "`n[WinGet] Available Upgrades:"
                if ($DryRun) { Write-Output "[DRY-RUN] Executing: winget upgrade" }
                else { winget upgrade }
            }
            elseif ($pm -eq "choco") {
                Write-Output "`n[Chocolatey] Available Upgrades:"
                if ($DryRun) { Write-Output "[DRY-RUN] Executing: choco outdated" }
                else { choco outdated }
            }
            elseif ($pm -eq "scoop") {
                Write-Output "`n[Scoop] Available Upgrades:"
                if ($DryRun) { Write-Output "[DRY-RUN] Executing: scoop status" }
                else { scoop status }
            }
        }
        Invoke-ParallelPM -ScriptBlock $outdatedBlock
    }
    "all" {
        # Check conflicts before system-wide upgrade
        $chocoPackages = @()
        if ("choco" -in $activePriority) {
            $chocoRaw = choco list -lo 2>$null
            foreach ($line in $chocoRaw) {
                if ($line -match '^\s*([a-zA-Z0-9\-\._]+)\s+\d') {
                    $n = $matches[1]
                    if ($n -ne "chocolatey") { $chocoPackages += $n }
                }
            }
        }
        $conflicts = @()
        if ("winget" -in $activePriority -and $chocoPackages.Count -gt 0) {
            foreach ($pkg in $chocoPackages) {
                $wgSearch = winget list $pkg -q 2>$null | Select-String $pkg
                if ($wgSearch) { $conflicts += $pkg }
            }
        }

        if ($conflicts.Count -gt 0) {
            Write-Host "Conflict Alert: The following packages are installed via both WinGet and Chocolatey:" -ForegroundColor Yellow
            $highest = $activePriority | Where-Object { $_ -eq "winget" -or $_ -eq "choco" } | Select-Object -First 1
            foreach ($conflict in $conflicts) {
                Write-Host "  - $conflict" -ForegroundColor White
                Write-Host "  Recommendation: Keep $highest, uninstall the other." -ForegroundColor Cyan
                $ans = Read-Host "  Action? [W]inGet uninstall, [C]hoco uninstall, [S]kip"
                if ($ans -match '^w') {
                    if ($DryRun) { Write-Host "[DRY-RUN] winget uninstall $conflict" -ForegroundColor Yellow } else { winget uninstall $conflict }
                } elseif ($ans -match '^c') {
                    if ($DryRun) { Write-Host "[DRY-RUN] choco uninstall $conflict" -ForegroundColor Yellow } else { "y" | choco uninstall $conflict }
                }
            }
        }

        $apStr = $activePriority -join ' -> '
        Write-Host "Updating EVERYTHING acting in priority order: $apStr" -ForegroundColor Cyan
        $summary = @()
        
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "`n[WinGet]" -ForegroundColor Gray
                if ($DryRun) { 
                    Write-Host "[DRY-RUN] winget upgrade --all @wgFlags" -ForegroundColor Yellow
                    $summary += [PSCustomObject]@{ Manager = "WinGet"; Status = "Dry-Run" }
                } else {
                    winget upgrade --all @wgFlags
                    if ($LASTEXITCODE -eq 0 -or $?) { $summary += [PSCustomObject]@{ Manager = "WinGet"; Status = "Success" } }
                    else { $summary += [PSCustomObject]@{ Manager = "WinGet"; Status = "Failed" } }
                }
            }
            elseif ($pm -eq "choco") {
                Write-Host "`n[Chocolatey]" -ForegroundColor Gray
                if ($DryRun) { 
                    Write-Host "[DRY-RUN] y | choco upgrade all @chFlags" -ForegroundColor Yellow
                    $summary += [PSCustomObject]@{ Manager = "Chocolatey"; Status = "Dry-Run" }
                } else {
                    "y" | choco upgrade all @chFlags
                    if ($LASTEXITCODE -eq 0) { $summary += [PSCustomObject]@{ Manager = "Chocolatey"; Status = "Success" } }
                    else { $summary += [PSCustomObject]@{ Manager = "Chocolatey"; Status = "Failed" } }
                }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "`n[Scoop]" -ForegroundColor Gray
                if ($DryRun) { 
                    Write-Host "[DRY-RUN] scoop update *" -ForegroundColor Yellow
                    $summary += [PSCustomObject]@{ Manager = "Scoop"; Status = "Dry-Run" }
                } else {
                    scoop update
                    scoop update * @scFlags
                    if ($?) { $summary += [PSCustomObject]@{ Manager = "Scoop"; Status = "Success" } }
                    else { $summary += [PSCustomObject]@{ Manager = "Scoop"; Status = "Failed" } }
                }
            }
        }

        # Summary Table
        Write-Host "`n=== OmniGet System Upgrade Summary ===" -ForegroundColor Cyan
        foreach ($s in $summary) {
            $color = if ($s.Status -eq "Success") { "Green" } elseif ($s.Status -eq "Failed") { "Red" } else { "Yellow" }
            $msg = " {0,-15} |  {1}" -f $s.Manager, $s.Status
            Write-Host $msg -ForegroundColor $color
        }
        Write-Host "======================================`n" -ForegroundColor Cyan
    }
    "install" {
        if ($Name -eq "") { Write-Host "Please specify a package name to install." -ForegroundColor Red; return }
        $success = $false
        $selectedPM = ""
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "Attempting to install '$Name' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: winget install $Name --exact $wgFlags" -ForegroundColor Yellow; $success = $true; $selectedPM = "winget"; break }
                winget install $Name --exact @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; $selectedPM = "winget"; break }
            }
            elseif ($pm -eq "choco") {
                Write-Host "Attempting to install '$Name' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: choco install $Name $chFlags" -ForegroundColor Yellow; $success = $true; $selectedPM = "choco"; break }
                "y" | choco install $Name @chFlags
                if ($LASTEXITCODE -eq 0) { 
                    $success = $true; $selectedPM = "choco"
                    if ("winget" -in $availablePMs) { winget pin add --name $Name -e -q 2>$null }
                    break 
                }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "Attempting to install '$Name' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: scoop install $Name $scFlags" -ForegroundColor Yellow; $success = $true; $selectedPM = "scoop"; break }
                scoop install $Name @scFlags
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "scoop"; break }
            }
            elseif ($pm -eq "pip") {
                Write-Host "Attempting to install '$Name' via pip..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: pip install $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "pip"; break }
                pip install $Name
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "pip"; break }
            }
            elseif ($pm -eq "npm") {
                Write-Host "Attempting to install '$Name' via npm..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: npm install -g $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "npm"; break }
                npm install -g $Name
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "npm"; break }
            }
            elseif ($pm -eq "cargo") {
                Write-Host "Attempting to install '$Name' via cargo..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: cargo install $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "cargo"; break }
                cargo install $Name
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "cargo"; break }
            }
            elseif ($pm -eq "nuget") {
                Write-Host "Attempting to install '$Name' via nuget..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: nuget install $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "nuget"; break }
                nuget install $Name
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "nuget"; break }
            }
        }

        if (-not $success) {
            Write-OmniLog -ActionType "INSTALL" -Status "FAILED" -PackageManager ($activePriority -join ',') -PackageName $Name
            Write-Host "Failed to install '$Name' on Windows using configured PMs." -ForegroundColor Red
            if ($hasWsl -and -not $DryRun) {
                Write-Host "Package not found in Windows. Checking WSL..." -ForegroundColor Cyan
                $distrosRaw = wsl.exe --list --quiet 2>$null
                if ($distrosRaw) {
                    $distros = ($distrosRaw -replace '\x00', '') -split '\r?\n' | Where-Object { $_.Trim() -ne '' }
                    if ($distros.Count -gt 0) {
                        $ans = Read-Host "Would you like to install '$Name' in WSL instead? [Y]es / [N]o"
                        if ($ans -match '^y') {
                            $targetDistro = $distros[0]
                            Write-Host "[WSL: $targetDistro] Installing '$Name'..." -ForegroundColor Magenta
                            $shCmd = 'if command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y ' + $Name + '; elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm ' + $Name + '; elif command -v dnf >/dev/null; then sudo dnf install -y ' + $Name + '; elif command -v zypper >/dev/null; then sudo zypper install -y ' + $Name + '; else echo "Unknown package manager"; exit 1; fi'
                            wsl.exe -d $targetDistro -e sh -c "$shCmd"
                        }
                    }
                }
            } elseif ($hasWsl -and $DryRun) {
                Write-Host "[DRY-RUN] Would fallback to WSL interactive wizard here." -ForegroundColor Yellow
            }
        } else {
            if (-not $DryRun) {
                Write-OmniLog -ActionType "INSTALL" -Status "SUCCESS" -PackageManager $selectedPM -PackageName $Name
                Write-Host "'$Name' installed successfully!" -ForegroundColor Green
            }
        }
    }
    "upgrade" {
        if ($Name -eq "") { Write-Host "Please specify a package name." -ForegroundColor Red; return }
        $success = $false
        $selectedPM = ""
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Updating '$Name' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco upgrade $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "choco"; break }
                "y" | choco upgrade $Name @chFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; $selectedPM = "choco"; break }
            }
            elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Updating '$Name' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop update $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "scoop"; break }
                scoop update $Name @scFlags
                if ($?) { $success = $true; $selectedPM = "scoop"; break }
            }
            elseif ($pm -eq "winget") {
                Write-Host "Updating '$Name' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget upgrade $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "winget"; break }
                winget upgrade $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; $selectedPM = "winget"; break }
            }
            elseif ($pm -eq "pip") {
                Write-Host "Updating '$Name' via pip..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] pip install --upgrade $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "pip"; break }
                pip install --upgrade $Name
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "pip"; break }
            }
            elseif ($pm -eq "npm") {
                Write-Host "Updating '$Name' via npm..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] npm update -g $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "npm"; break }
                npm update -g $Name
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; $selectedPM = "npm"; break }
            }
        }
        if (-not $success) {
            Write-OmniLog -ActionType "UPGRADE" -Status "FAILED" -PackageManager ($activePriority -join ',') -PackageName $Name
            Write-Host "Failed to update '$Name'." -ForegroundColor Red
        } else {
            if (-not $DryRun) { Write-OmniLog -ActionType "UPGRADE" -Status "SUCCESS" -PackageManager $selectedPM -PackageName $Name }
        }
    }
    "uninstall" {
        if ($Name -eq "") { Write-Host "Please specify a package name to uninstall." -ForegroundColor Red; return }
        if ($Name.ToLower() -eq "omniget") {
            $uninstPath = Join-Path $env:LOCALAPPDATA "OmniGet\OmniGetUninstall.exe"
            if (Test-Path $uninstPath) {
                Write-Host "Launching Native OmniGet Uninstaller..." -ForegroundColor Cyan
                Start-Process -FilePath $uninstPath -NoNewWindow -Wait
                return
            }
        }

        $success = $false
        $selectedPM = ""
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Removing '$Name' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco uninstall $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "choco"; break }
                "y" | choco uninstall $Name @chFlags
                if ("winget" -in $availablePMs) { winget pin remove --name $Name -q 2>$null }
                $success = $true; $selectedPM = "choco"; break
            }
            elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Removing '$Name' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop uninstall $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "scoop"; break }
                scoop uninstall $Name @scFlags
                $success = $true; $selectedPM = "scoop"; break
            }
            elseif ($pm -eq "winget") {
                Write-Host "Removing '$Name' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget uninstall $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "winget"; break }
                winget uninstall $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; $selectedPM = "winget"; break }
            }
            elseif ($pm -eq "pip") {
                Write-Host "Removing '$Name' via pip..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] pip uninstall -y $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "pip"; break }
                pip uninstall -y $Name
                $success = $true; $selectedPM = "pip"; break
            }
            elseif ($pm -eq "npm") {
                Write-Host "Removing '$Name' via npm..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] npm uninstall -g $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "npm"; break }
                npm uninstall -g $Name
                $success = $true; $selectedPM = "npm"; break
            }
            elseif ($pm -eq "cargo") {
                Write-Host "Removing '$Name' via cargo..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] cargo uninstall $Name" -ForegroundColor Yellow; $success = $true; $selectedPM = "cargo"; break }
                cargo uninstall $Name
                $success = $true; $selectedPM = "cargo"; break
            }
        }
        if (-not $success) {
            Write-OmniLog -ActionType "UNINSTALL" -Status "FAILED" -PackageManager ($activePriority -join ',') -PackageName $Name
            Write-Host "Failed to uninstall '$Name'." -ForegroundColor Red
        } else {
            if (-not $DryRun) { Write-OmniLog -ActionType "UNINSTALL" -Status "SUCCESS" -PackageManager $selectedPM -PackageName $Name }
        }
    }
    "search" {
        if ($Name -eq "") { Write-Host "Please specify a package name to search." -ForegroundColor Red; return }
        Write-Host "Searching for '$Name' in parallel across managers..." -ForegroundColor Cyan
        $searchBlock = {
            param($pm, $name, $remArgs)
            if ($pm -eq "winget") {
                Write-Output "`n[WinGet] Searching for '$name'..."
                if ($DryRun) { Write-Output "[DRY-RUN] winget search $name $remArgs" }
                else { if ($remArgs) { winget search $name @remArgs } else { winget search $name } }
            }
            elseif ($pm -eq "choco") {
                Write-Output "`n[Chocolatey] Searching for '$name'..."
                if ($DryRun) { Write-Output "[DRY-RUN] choco search $name $remArgs" }
                else { if ($remArgs) { choco search $name @remArgs } else { choco search $name } }
            }
            elseif ($pm -eq "scoop") {
                Write-Output "`n[Scoop] Searching for '$name'..."
                if ($DryRun) { Write-Output "[DRY-RUN] scoop search $name $remArgs" }
                else { if ($remArgs) { scoop search $name @remArgs } else { scoop search $name } }
            }
            elseif ($pm -eq "npm") {
                Write-Output "`n[NPM] Searching for '$name'..."
                if ($DryRun) { Write-Output "[DRY-RUN] npm search $name" }
                else { npm search $name }
            }
            elseif ($pm -eq "pip") {
                Write-Output "`n[PIP] Note: 'pip search' is deprecated. Listing matching installed packages:"
                pip list | Select-String $name
            }
            elseif ($pm -eq "cargo") {
                Write-Output "`n[Cargo] Searching for '$name'..."
                if ($DryRun) { Write-Output "[DRY-RUN] cargo search $name" }
                else { cargo search $name }
            }
        }
        Invoke-ParallelPM -ScriptBlock $searchBlock
    }
    "list" {
        Write-Host "Fetching installed packages in parallel across managers..." -ForegroundColor Cyan
        $listBlock = {
            param($pm, $name, $remArgs)
            if ($pm -eq "winget") {
                Write-Output "`n[WinGet] Installed Packages:"
                if ($DryRun) { Write-Output "[DRY-RUN] winget list $name" }
                else { if ($name -eq "") { winget list } else { winget list $name } }
            }
            elseif ($pm -eq "choco") {
                Write-Output "`n[Chocolatey] Installed Packages:"
                if ($DryRun) { Write-Output "[DRY-RUN] choco list $name" }
                else { if ($name -eq "") { choco list -lo } else { choco list $name } }
            }
            elseif ($pm -eq "scoop") {
                Write-Output "`n[Scoop] Installed Packages:"
                if ($DryRun) { Write-Output "[DRY-RUN] scoop list" }
                else { scoop list }
            }
            elseif ($pm -eq "npm") {
                Write-Output "`n[NPM] Installed Packages (Global):"
                npm list -g --depth=0
            }
            elseif ($pm -eq "pip") {
                Write-Output "`n[PIP] Installed Packages:"
                pip list
            }
            elseif ($pm -eq "cargo") {
                Write-Output "`n[Cargo] Installed Packages:"
                cargo install --list
            }
        }
        Invoke-ParallelPM -ScriptBlock $listBlock
    }
    "info" {
        if ($Name -eq "") { Write-Host "Please specify a package name." -ForegroundColor Red; return }
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet] Info for '$Name'..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget show $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($RemainingArgs) { winget show $Name @RemainingArgs } else { winget show $Name } }
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey] Info for '$Name'..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco info $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($RemainingArgs) { choco info $Name @RemainingArgs } else { choco info $Name } }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop] Info for '$Name'..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop info $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($RemainingArgs) { scoop info $Name @RemainingArgs } else { scoop info $Name } }
            }
        }
    }
    "doctor" {
        Write-Host "OmniGet Conflict Doctor" -ForegroundColor Cyan
        $chocoPackages = @()
        if ("choco" -in $activePriority) {
            $chocoRaw = choco list -lo 2>$null
            foreach ($line in $chocoRaw) {
                if ($line -match '^\s*([a-zA-Z0-9\-\._]+)\s+\d') {
                    $n = $matches[1]
                    if ($n -ne "chocolatey") { $chocoPackages += $n }
                }
            }
        }
        $conflicts = @()
        if ("winget" -in $activePriority -and $chocoPackages.Count -gt 0) {
            $cCount = $chocoPackages.count
            Write-Host "Comparing $cCount Choco packages against WinGet... This may take a moment." -ForegroundColor Cyan
            foreach ($pkg in $chocoPackages) {
                $wgSearch = winget list $pkg -q 2>$null | Select-String $pkg
                if ($wgSearch) { $conflicts += $pkg }
            }
        }

        if ($conflicts.Count -gt 0) {
            $cfCount = $conflicts.Count
            Write-Host "Found $cfCount potential conflicts (installed in both WinGet and Choco):" -ForegroundColor Yellow
            $highest = $activePriority | Where-Object { $_ -eq "winget" -or $_ -eq "choco" } | Select-Object -First 1
            foreach ($conflict in $conflicts) {
                Write-Host "- $conflict" -ForegroundColor White
                Write-Host "  Priority Recommendation: Keep $highest, uninstall the other." -ForegroundColor Cyan
                $ans = Read-Host "  Action? [W]inGet uninstall, [C]hoco uninstall, [S]kip"
                if ($ans -match '^w') { 
                    if ($DryRun) { Write-Host "[DRY-RUN] winget uninstall $conflict" -ForegroundColor Yellow } else { winget uninstall $conflict }
                } elseif ($ans -match '^c') { 
                    if ($DryRun) { Write-Host "[DRY-RUN] choco uninstall $conflict" -ForegroundColor Yellow } else { "y" | choco uninstall $conflict }
                }
            }
        } else {
            Write-Host "System package configuration is healthy! No duplicates found." -ForegroundColor Green
        }

        # PATH Doctor checks
        $checkSystem = ($RemainingArgs -contains "--system" -or $Name -eq "--system")
        
        if ($checkSystem) {
            Write-Host "`nAuditing System PATH health..." -ForegroundColor Cyan
            $sysPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $sysEntries = ($sysPath -split ';') | Where-Object { $_.Trim() -ne "" }
            $sysDead = @()
            $sysDuplicates = @()
            $seenSys = @{}
            foreach ($entry in $sysEntries) {
                $cleaned = $entry.Trim()
                if (-not (Test-Path $cleaned)) { $sysDead += $cleaned }
                if ($seenSys.ContainsKey($cleaned)) { $sysDuplicates += $cleaned }
                else { $seenSys[$cleaned] = $true }
            }
            
            if ($sysDead.Count -gt 0 -or $sysDuplicates.Count -gt 0) {
                if ($isAdmin) {
                    Write-Host "`n[System PATH Issues Found]" -ForegroundColor Yellow
                    foreach ($d in $sysDead) { Write-Host "  - DEAD PATH: $d" -ForegroundColor Red }
                    foreach ($d in $sysDuplicates) { Write-Host "  - DUPLICATE PATH: $d" -ForegroundColor Yellow }
                    
                    $ans = Read-Host "  Prune dead and duplicate System paths now? [Y]es / [N]o"
                    if ($ans -match '^y') {
                        $filtered = $sysEntries | Where-Object { $_ -notin $sysDead } | Group-Object | ForEach-Object { $_.Name }
                        $newPath = $filtered -join ';'
                        if ($DryRun) { Write-Host "[DRY-RUN] Set System Path = $newPath" -ForegroundColor Yellow }
                        else {
                            [System.Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                            Broadcast-EnvChange
                            Write-Host "System PATH cleaned!" -ForegroundColor Green
                        }
                    }
                } else {
                    Write-Host "`n[System PATH Issues Found] (Run as Admin to prune)" -ForegroundColor Yellow
                    foreach ($d in $sysDead) { Write-Host "  - DEAD PATH: $d" -ForegroundColor Red }
                    foreach ($d in $sysDuplicates) { Write-Host "  - DUPLICATE PATH: $d" -ForegroundColor Yellow }
                }
            } else {
                Write-Host "System PATH is healthy!" -ForegroundColor Green
            }
            $totalSysLength = $sysPath.Length
            if ($totalSysLength -gt 1500) { Write-Host "Warning: System PATH length ($totalSysLength chars) is approaching the 2048 limit." -ForegroundColor Yellow }
        } else {
            Write-Host "`nAuditing User PATH health..." -ForegroundColor Cyan
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $userEntries = ($userPath -split ';') | Where-Object { $_.Trim() -ne "" }
            $userDead = @()
            $userDuplicates = @()
            $seenUser = @{}
            foreach ($entry in $userEntries) {
                $cleaned = $entry.Trim()
                if (-not (Test-Path $cleaned)) { $userDead += $cleaned }
                if ($seenUser.ContainsKey($cleaned)) { $userDuplicates += $cleaned }
                else { $seenUser[$cleaned] = $true }
            }
            
            if ($userDead.Count -gt 0 -or $userDuplicates.Count -gt 0) {
                Write-Host "`n[User PATH Issues Found]" -ForegroundColor Yellow
                foreach ($d in $userDead) { Write-Host "  - DEAD PATH: $d" -ForegroundColor Red }
                foreach ($d in $userDuplicates) { Write-Host "  - DUPLICATE PATH: $d" -ForegroundColor Yellow }
                
                $ans = Read-Host "  Prune dead and duplicate User paths now? [Y]es / [N]o"
                if ($ans -match '^y') {
                    $filtered = $userEntries | Where-Object { $_ -notin $userDead } | Group-Object | ForEach-Object { $_.Name }
                    $newPath = $filtered -join ';'
                    if ($DryRun) { Write-Host "[DRY-RUN] Set User Path = $newPath" -ForegroundColor Yellow }
                    else {
                        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Broadcast-EnvChange
                        Write-Host "User PATH cleaned!" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "User PATH is healthy!" -ForegroundColor Green
            }
            
            $totalUserLength = $userPath.Length
            if ($totalUserLength -gt 1500) { Write-Host "Warning: User PATH length ($totalUserLength chars) is approaching the 2048 limit." -ForegroundColor Yellow }
            
            Write-Host "`nNote: System PATH was not audited. Run 'omniget doctor --system' to check and prune System PATH." -ForegroundColor Gray
        }
    }
    "history" {
        $logFile = Join-Path $env:USERPROFILE ".omniget\history.log"
        if (Test-Path $logFile) {
            Get-Content $logFile
        } else {
            Write-Host "No installation history found." -ForegroundColor Yellow
        }
    }
    "export" {
        if ($Name -eq "") { Write-Host "Please specify a file path to export to." -ForegroundColor Red; return }
        $filePath = $Name
        Write-Host "Exporting installed packages to $filePath..." -ForegroundColor Cyan
        
        $packages = @()
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                $list = winget list --disable-interactivity 2>$null
                foreach ($line in $list) {
                    if ($line -match '^\s*([^\s].*?)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}(\w+)') {
                        $pId = $matches[2].Trim()
                        $pSrc = $matches[4].Trim()
                        if ($pSrc -ieq "winget" -or $pSrc -ieq "msstore") {
                            $packages += [PSCustomObject]@{ Id = $pId; Manager = "winget" }
                        }
                    }
                }
            }
            elseif ($pm -eq "choco") {
                $list = choco list -lo 2>$null
                foreach ($line in $list) {
                    if ($line -match '^([^\|]+)\|') {
                        $pId = $matches[1].Trim()
                        if ($pId -ne "chocolatey") {
                            $packages += [PSCustomObject]@{ Id = $pId; Manager = "choco" }
                        }
                    }
                }
            }
            elseif ($pm -eq "scoop") {
                $list = scoop list 2>$null
                foreach ($line in $list) {
                    if ($line -match '^\s*([a-zA-Z0-9\-\._]+)\s+(\S+)\s+(\S+)') {
                        $pId = $matches[1].Trim()
                        $packages += [PSCustomObject]@{ Id = $pId; Manager = "scoop" }
                    }
                }
            }
        }

        $uniquePackages = $packages | Group-Object Id | ForEach-Object { $_.Group[0] }

        if ($filePath.EndsWith(".txt", [System.StringComparison]::OrdinalIgnoreCase)) {
            $txtLines = $uniquePackages | ForEach-Object { $_.Id }
            $txtLines | Set-Content -Path $filePath -Force
            Write-Host "Successfully exported $($uniquePackages.Count) packages to TXT list: $filePath" -ForegroundColor Green
        } else {
            $json = [PSCustomObject]@{
                omniget_version = $OmniGetVersion
                packages = $uniquePackages
            }
            $json | ConvertTo-Json -Depth 5 | Set-Content -Path $filePath -Force
            Write-Host "Successfully exported $($uniquePackages.Count) packages to JSON list: $filePath" -ForegroundColor Green
        }
    }
    "import" {
        if ($Name -eq "") { Write-Host "Please specify a file path to import." -ForegroundColor Red; return }
        $filePath = $Name
        if (-not (Test-Path $filePath)) { Write-Host "File not found: $filePath" -ForegroundColor Red; return }
        
        Write-Host "Importing packages from $filePath..." -ForegroundColor Cyan
        
        if ($filePath.EndsWith(".txt", [System.StringComparison]::OrdinalIgnoreCase)) {
            $txtLines = Get-Content $filePath | Where-Object { $_.Trim() -ne "" }
            Write-Host "Found $($txtLines.Count) packages to install." -ForegroundColor Yellow
            foreach ($pkg in $txtLines) {
                Write-Host "`n---> Installing $pkg..." -ForegroundColor Cyan
                & $MyInvocation.MyCommand.Path install $pkg
            }
        } else {
            try {
                $data = Get-Content $filePath -Raw | ConvertFrom-Json
                $packages = $data.packages
                Write-Host "Found $($packages.Count) packages to install." -ForegroundColor Yellow
                foreach ($pkg in $packages) {
                    Write-Host "`n---> Installing $($pkg.Id) via $($pkg.Manager)..." -ForegroundColor Cyan
                    if ($pkg.Manager -in $availablePMs) {
                        & $MyInvocation.MyCommand.Path install $($pkg.Id) --pm $($pkg.Manager)
                    } else {
                        & $MyInvocation.MyCommand.Path install $($pkg.Id)
                    }
                }
            } catch {
                Write-Host "Failed to parse JSON file: $_" -ForegroundColor Red
            }
        }
    }
    "sync" {
        if ($Name -eq "") { Write-Host "Please specify a file path to sync." -ForegroundColor Red; return }
        $filePath = $Name
        if (-not (Test-Path $filePath)) { Write-Host "File not found: $filePath" -ForegroundColor Red; return }
        
        Write-Host "Synchronizing system package state with $filePath..." -ForegroundColor Cyan
        
        $targetIds = @()
        $targetManagerMap = @{}
        
        if ($filePath.EndsWith(".txt", [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetIds = Get-Content $filePath | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
        } else {
            try {
                $data = Get-Content $filePath -Raw | ConvertFrom-Json
                foreach ($pkg in $data.packages) {
                    $targetIds += $pkg.Id
                    $targetManagerMap[$pkg.Id] = $pkg.Manager
                }
            } catch {
                Write-Host "Failed to parse JSON file: $_" -ForegroundColor Red
                return
            }
        }
        
        $currentPackages = @()
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                $list = winget list --disable-interactivity 2>$null
                foreach ($line in $list) {
                    if ($line -match '^\s*([^\s].*?)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}(\w+)') {
                        $pId = $matches[2].Trim()
                        $pSrc = $matches[4].Trim()
                        if ($pSrc -ieq "winget" -or $pSrc -ieq "msstore") {
                            $currentPackages += [PSCustomObject]@{ Id = $pId; Manager = "winget" }
                        }
                    }
                }
            }
            elseif ($pm -eq "choco") {
                $list = choco list -lo 2>$null
                foreach ($line in $list) {
                    if ($line -match '^([^\|]+)\|') {
                        $pId = $matches[1].Trim()
                        if ($pId -ne "chocolatey") {
                            $currentPackages += [PSCustomObject]@{ Id = $pId; Manager = "choco" }
                        }
                    }
                }
            }
            elseif ($pm -eq "scoop") {
                $list = scoop list 2>$null
                foreach ($line in $list) {
                    if ($line -match '^\s*([a-zA-Z0-9\-\._]+)\s+(\S+)\s+(\S+)') {
                        $pId = $matches[1].Trim()
                        $currentPackages += [PSCustomObject]@{ Id = $pId; Manager = "scoop" }
                    }
                }
            }
        }
        
        $currentIds = $currentPackages | ForEach-Object { $_.Id }
        $missingIds = $targetIds | Where-Object { $_ -notin $currentIds }
        $extraneousPackages = $currentPackages | Where-Object { $_.Id -notin $targetIds }
        
        Write-Host "Found $($missingIds.Count) packages to install and $($extraneousPackages.Count) packages to uninstall." -ForegroundColor Yellow
        
        foreach ($pkg in $missingIds) {
            Write-Host "`n---> [SYNC] Installing missing package: $pkg" -ForegroundColor Green
            if ($targetManagerMap.ContainsKey($pkg)) {
                $pm = $targetManagerMap[$pkg]
                & $MyInvocation.MyCommand.Path install $pkg --pm $pm
            } else {
                & $MyInvocation.MyCommand.Path install $pkg
            }
        }
        
        foreach ($pkg in $extraneousPackages) {
            Write-Host "`n---> [SYNC] Uninstalling extraneous package: $($pkg.Id) via $($pkg.Manager)" -ForegroundColor Red
            & $MyInvocation.MyCommand.Path uninstall $($pkg.Id) --pm $($pkg.Manager)
        }
        
        Write-Host "`nSystem synchronization complete!" -ForegroundColor Green
    }
    "pin" {
        $subCmd = $Name.ToLower()
        $pkgName = $RemainingArgs[0]
        
        if ($subCmd -eq "list") {
            Write-Host "Listing pinned packages across active managers..." -ForegroundColor Cyan
            foreach ($pm in $activePriority) {
                if ($pm -eq "winget") {
                    Write-Host "`n[WinGet] Pinned Packages:" -ForegroundColor Cyan
                    winget pin list
                }
                elseif ($pm -eq "choco") {
                    Write-Host "`n[Chocolatey] Pinned Packages:" -ForegroundColor Yellow
                    choco pin list
                }
                elseif ($pm -eq "scoop") {
                    Write-Host "`n[Scoop] Held Packages:" -ForegroundColor Green
                    scoop status | Select-String "held"
                }
            }
        }
        elseif ($subCmd -eq "add" -or $subCmd -eq "hold") {
            if ([string]::IsNullOrEmpty($pkgName)) { Write-Host "Please specify a package name to pin." -ForegroundColor Red; return }
            Write-Host "Pinning package '$pkgName'..." -ForegroundColor Cyan
            foreach ($pm in $activePriority) {
                if ($pm -eq "winget") { winget pin add --name $pkgName -e }
                elseif ($pm -eq "choco") { choco pin add -n $pkgName }
                elseif ($pm -eq "scoop") { scoop hold $pkgName }
            }
        }
        elseif ($subCmd -eq "remove" -or $subCmd -eq "unhold") {
            if ([string]::IsNullOrEmpty($pkgName)) { Write-Host "Please specify a package name to unpin." -ForegroundColor Red; return }
            Write-Host "Unpinning package '$pkgName'..." -ForegroundColor Cyan
            foreach ($pm in $activePriority) {
                if ($pm -eq "winget") { winget pin remove --name $pkgName }
                elseif ($pm -eq "choco") { choco pin remove -n $pkgName }
                elseif ($pm -eq "scoop") { scoop unhold $pkgName }
            }
        }
        else {
            Write-Host "Invalid pin command. Use: 'omniget pin list', 'omniget pin add <pkg>', or 'omniget pin remove <pkg>'" -ForegroundColor Red
        }
    }
    "env" {
        $subCmd = $Name.ToLower()
        $varName = $RemainingArgs[0]
        $varValue = $RemainingArgs[1]
        
        $targetScope = "User"
        if ($RemainingArgs -contains "--system") {
            $targetScope = "Machine"
            $varValue = ($RemainingArgs | Where-Object { $_ -ne "--system" })[1]
        }
        
        if ($subCmd -eq "show" -or $subCmd -eq "") {
            Write-Host "`nEnvironment Variables (Scope: User)" -ForegroundColor Cyan
            $userVars = [System.Environment]::GetEnvironmentVariables("User")
            foreach ($k in ($userVars.Keys | Sort-Object)) {
                $val = $userVars[$k]
                if ($val.Length -gt 60) { $val = $val.Substring(0, 57) + "..." }
                Write-Host ("  {0,-20} = {1}" -f $k, $val) -ForegroundColor Yellow
            }
            
            Write-Host "`nEnvironment Variables (Scope: System)" -ForegroundColor Cyan
            $sysVars = [System.Environment]::GetEnvironmentVariables("Machine")
            foreach ($k in ($sysVars.Keys | Sort-Object)) {
                $val = $sysVars[$k]
                if ($val.Length -gt 60) { $val = $val.Substring(0, 57) + "..." }
                Write-Host ("  {0,-20} = {1}" -f $k, $val) -ForegroundColor Green
            }
            Write-Host ""
        }
        elseif ($subCmd -eq "set" -or $subCmd -eq "add") {
            if ([string]::IsNullOrEmpty($varName)) { Write-Host "Specify a variable name." -ForegroundColor Red; return }
            if ($null -eq $varValue) { $varValue = "" }
            
            if ($targetScope -eq "Machine" -and -not $isAdmin) {
                Write-Host "Modifying System-level variables requires administrator elevation." -ForegroundColor Red
                return
            }
            
            Write-Host "Setting Environment Variable '$varName' = '$varValue' ($targetScope Scope)..." -ForegroundColor Cyan
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would set variable in registry and broadcast environment update." -ForegroundColor Yellow
            } else {
                [System.Environment]::SetEnvironmentVariable($varName, $varValue, $targetScope)
                [System.Environment]::SetEnvironmentVariable($varName, $varValue, "Process")
                Broadcast-EnvChange
                Write-Host "Successfully set and broadcasted variable!" -ForegroundColor Green
            }
        }
        elseif ($subCmd -eq "remove" -or $subCmd -eq "delete") {
            if ([string]::IsNullOrEmpty($varName)) { Write-Host "Specify a variable name." -ForegroundColor Red; return }
            
            if ($targetScope -eq "Machine" -and -not $isAdmin) {
                Write-Host "Modifying System-level variables requires administrator elevation." -ForegroundColor Red
                return
            }
            
            Write-Host "Removing Environment Variable '$varName' ($targetScope Scope)..." -ForegroundColor Cyan
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would remove variable and broadcast environment update." -ForegroundColor Yellow
            } else {
                [System.Environment]::SetEnvironmentVariable($varName, $null, $targetScope)
                [System.Environment]::SetEnvironmentVariable($varName, $null, "Process")
                Broadcast-EnvChange
                Write-Host "Successfully removed and broadcasted variable!" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Invalid env command. Use: 'omniget env show', 'omniget env set <name> <value> [--system]', or 'omniget env remove <name> [--system]'" -ForegroundColor Red
        }
    }
    "path" {
        $subCmd = $Name.ToLower()
        $folderPath = $RemainingArgs[0]
        $targetScope = "User"
        if ($RemainingArgs -contains "--system") {
            $targetScope = "Machine"
            $folderPath = ($RemainingArgs | Where-Object { $_ -ne "--system" -and $_ -ne "--prepend" })[0]
        }
        $prepend = $false
        if ($RemainingArgs -contains "--prepend") {
            $prepend = $true
            $folderPath = ($RemainingArgs | Where-Object { $_ -ne "--system" -and $_ -ne "--prepend" })[0]
        }

        if ($subCmd -eq "show" -or $subCmd -eq "") {
            Write-Host "`nEnvironment PATH (User Scope)" -ForegroundColor Cyan
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            foreach ($entry in ($userPath -split ';')) {
                if ($entry.Trim() -ne "") { Write-Host "  $entry" -ForegroundColor Yellow }
            }
            
            Write-Host "`nEnvironment PATH (System Scope)" -ForegroundColor Cyan
            $sysPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            foreach ($entry in ($sysPath -split ';')) {
                if ($entry.Trim() -ne "") { Write-Host "  $entry" -ForegroundColor Green }
            }
            Write-Host ""
        }
        elseif ($subCmd -eq "add") {
            if ([string]::IsNullOrEmpty($folderPath)) { Write-Host "Specify a folder path." -ForegroundColor Red; return }
            $fullPath = [System.IO.Path]::GetFullPath($folderPath)
            
            if ($targetScope -eq "Machine" -and -not $isAdmin) {
                Write-Host "Modifying System PATH requires administrator elevation." -ForegroundColor Red
                return
            }
            
            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", $targetScope)
            $pathsList = ($currentPath -split ';') | Where-Object { $_.Trim() -ne "" }
            
            if ($pathsList -contains $fullPath) {
                Write-Host "Path '$fullPath' already exists in PATH ($targetScope Scope)." -ForegroundColor Yellow
                return
            }
            
            Write-Host "Adding '$fullPath' to PATH ($targetScope Scope)..." -ForegroundColor Cyan
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would append/prepend path and broadcast change." -ForegroundColor Yellow
            } else {
                if ($prepend) {
                    $newPath = $fullPath + ";" + $currentPath
                } else {
                    $newPath = $currentPath
                    if ($newPath -and -not $newPath.EndsWith(";")) { $newPath += ";" }
                    $newPath += $fullPath
                }
                [System.Environment]::SetEnvironmentVariable("Path", $newPath, $targetScope)
                Broadcast-EnvChange
                Write-Host "Successfully added path to environment!" -ForegroundColor Green
            }
        }
        elseif ($subCmd -eq "remove" -or $subCmd -eq "delete") {
            if ([string]::IsNullOrEmpty($folderPath)) { Write-Host "Specify a folder path." -ForegroundColor Red; return }
            $fullPath = [System.IO.Path]::GetFullPath($folderPath)
            
            if ($targetScope -eq "Machine" -and -not $isAdmin) {
                Write-Host "Modifying System PATH requires administrator elevation." -ForegroundColor Red
                return
            }
            
            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", $targetScope)
            $pathsList = ($currentPath -split ';') | Where-Object { $_.Trim() -ne "" }
            
            if ($pathsList -notcontains $fullPath) {
                Write-Host "Path '$fullPath' was not found in PATH ($targetScope Scope)." -ForegroundColor Yellow
                return
            }
            
            Write-Host "Removing '$fullPath' from PATH ($targetScope Scope)..." -ForegroundColor Cyan
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would remove path and broadcast change." -ForegroundColor Yellow
            } else {
                $filteredPaths = $pathsList | Where-Object { $_ -ne $fullPath }
                $newPath = $filteredPaths -join ';'
                [System.Environment]::SetEnvironmentVariable("Path", $newPath, $targetScope)
                Broadcast-EnvChange
                Write-Host "Successfully removed path from environment!" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Invalid path command. Use: 'omniget path show', 'omniget path add <dir> [--system] [--prepend]', or 'omniget path remove <dir> [--system]'" -ForegroundColor Red
        }
    }
    "profile" {
        $subCmd = $Name.ToLower()
        $profileName = $RemainingArgs[0]
        if ([string]::IsNullOrEmpty($profileName)) { Write-Host "Please specify a profile name." -ForegroundColor Red; return }
        
        $profileFile = Join-Path $env:USERPROFILE ".omniget_profile_$($profileName).json"
        
        if ($subCmd -eq "save") {
            Write-Host "Saving current environment configuration to profile '$profileName'..." -ForegroundColor Cyan
            $userVars = [System.Environment]::GetEnvironmentVariables("User")
            
            $profileData = @{}
            foreach ($k in $userVars.Keys) {
                $profileData[$k] = $userVars[$k]
            }
            
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would save profile to $profileFile" -ForegroundColor Yellow
            } else {
                $profileData | ConvertTo-Json -Depth 5 | Set-Content -Path $profileFile -Force
                Write-Host "Successfully saved profile to $profileFile!" -ForegroundColor Green
            }
        }
        elseif ($subCmd -eq "switch" -or $subCmd -eq "load") {
            if (-not (Test-Path $profileFile)) { Write-Host "Profile '$profileName' does not exist ($profileFile)." -ForegroundColor Red; return }
            Write-Host "Loading environment profile '$profileName'..." -ForegroundColor Cyan
            
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would load profile, set environment variables, and broadcast change." -ForegroundColor Yellow
            } else {
                try {
                    $profileData = Get-Content $profileFile -Raw | ConvertFrom-Json
                    
                    $currentVars = [System.Environment]::GetEnvironmentVariables("User")
                    foreach ($k in $currentVars.Keys) {
                        if (-not $profileData.psobject.Properties[$k]) {
                            [System.Environment]::SetEnvironmentVariable($k, $null, "User")
                        }
                    }
                    
                    foreach ($prop in $profileData.psobject.Properties) {
                        [System.Environment]::SetEnvironmentVariable($prop.Name, $prop.Value, "User")
                    }
                    
                    Broadcast-EnvChange
                    Write-Host "Successfully switched to profile '$profileName'!" -ForegroundColor Green
                } catch {
                    Write-Host "Failed to load profile: $_" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "Invalid profile command. Use: 'omniget profile save <name>' or 'omniget profile switch <name>'" -ForegroundColor Red
        }
    }
    "alias" {
        $subCmd = $Name.ToLower()
        $aliasName = $RemainingArgs[0]
        $aliasCommand = $RemainingArgs[1]
        
        $profilePath = $PROFILE
        
        if ($subCmd -eq "list") {
            Write-Host "Listing OmniGet-managed custom aliases in profile..." -ForegroundColor Cyan
            if (Test-Path $profilePath) {
                $content = Get-Content $profilePath
                $inBlock = $false
                foreach ($line in $content) {
                    if ($line -match '# <OMNIGET_ALIAS_START>') { $inBlock = $true; continue }
                    if ($line -match '# <OMNIGET_ALIAS_END>') { $inBlock = $false; continue }
                    if ($inBlock) {
                        if ($line -match 'function\s+(\S+)\s*\{\s*(.*?)\s*\}') {
                            Write-Host "  $($matches[1]) -> $($matches[2])" -ForegroundColor Yellow
                        }
                    }
                }
            } else {
                Write-Host "No PowerShell profile file found." -ForegroundColor Yellow
            }
        }
        elseif ($subCmd -eq "add") {
            if ([string]::IsNullOrEmpty($aliasName) -or [string]::IsNullOrEmpty($aliasCommand)) {
                Write-Host "Usage: omniget alias add <name> <command>" -ForegroundColor Red
                return
            }
            Write-Host "Adding alias '$aliasName' -> '$aliasCommand' persistently to PowerShell profile..." -ForegroundColor Cyan
            
            $aliasBlock = "`n# <OMNIGET_ALIAS_START>`nfunction $aliasName { $aliasCommand `$args }`n# <OMNIGET_ALIAS_END>"
            
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would append alias block to $profilePath" -ForegroundColor Yellow
            } else {
                $dir = Split-Path $profilePath
                if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
                if (-not (Test-Path $profilePath)) { New-Item -Path $profilePath -ItemType File -Force | Out-Null }
                
                Add-Content -Path $profilePath -Value $aliasBlock
                Invoke-Expression "function $aliasName { $aliasCommand `$args }"
                Write-Host "Successfully registered alias! Run '. `$PROFILE' to reload if needed." -ForegroundColor Green
            }
        }
        elseif ($subCmd -eq "remove" -or $subCmd -eq "delete") {
            if ([string]::IsNullOrEmpty($aliasName)) { Write-Host "Specify alias name to remove." -ForegroundColor Red; return }
            Write-Host "Removing alias '$aliasName' from profile..." -ForegroundColor Cyan
            
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would remove alias block from $profilePath" -ForegroundColor Yellow
            } else {
                if (Test-Path $profilePath) {
                    $content = Get-Content $profilePath -Raw
                    $regex = '(?s)\r?\n# <OMNIGET_ALIAS_START>\r?\nfunction\s+' + [regex]::Escape($aliasName) + '\s*\{.*?\r?\n# <OMNIGET_ALIAS_END>'
                    $newContent = $content -replace $regex, ''
                    Set-Content -Path $profilePath -Value $newContent -Force
                    Write-Host "Successfully removed alias from profile!" -ForegroundColor Green
                } else {
                    Write-Host "Profile not found." -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "Invalid alias command. Use: 'omniget alias list', 'omniget alias add <name> <command>', or 'omniget alias remove <name>'" -ForegroundColor Red
        }
    }
    "bootstrap" {
        $pmName = $Name.ToLower()
        if ([string]::IsNullOrEmpty($pmName)) { Write-Host "Please specify a package manager to bootstrap (choco | scoop | winget)." -ForegroundColor Red; return }
        
        if ($pmName -eq "scoop") {
            Write-Host "Bootstrapping Scoop..." -ForegroundColor Green
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would execute Scoop install script." -ForegroundColor Yellow
            } else {
                Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            }
        }
        elseif ($pmName -eq "choco" -or $pmName -eq "chocolatey") {
            if (-not $isAdmin) {
                Write-Host "Bootstrapping Chocolatey requires administrator privileges. Please run as Administrator." -ForegroundColor Red
                return
            }
            Write-Host "Bootstrapping Chocolatey..." -ForegroundColor Yellow
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would execute Chocolatey install script." -ForegroundColor Yellow
            } else {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            }
        }
        elseif ($pmName -eq "winget") {
            Write-Host "Bootstrapping WinGet..." -ForegroundColor Cyan
            if ($DryRun) {
                Write-Host "[DRY-RUN] Would download and install Microsoft DesktopAppInstaller MSIX bundle." -ForegroundColor Yellow
            } else {
                $tempPath = Join-Path $env:TEMP "winget.msixbundle"
                Write-Host "Downloading installer..." -ForegroundColor Gray
                Invoke-RestMethod -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $tempPath
                Write-Host "Installing package..." -ForegroundColor Gray
                Add-AppxPackage -Path $tempPath
                Remove-Item $tempPath -ErrorAction SilentlyContinue
                Write-Host "WinGet bootstrapping complete!" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Unknown package manager '$pmName'. Support choco, scoop, and winget." -ForegroundColor Red
        }
    }
    default {
        $chocoCommandMap = @{
            "show" = "info"; "settings" = "config"; "features" = "feature"; 
            "source" = "source"; "pin" = "pin"; "export" = "export"; "download" = "download";
            "hash" = $null; "validate" = $null; "import" = $null; "repair" = $null; "configure" = $null; "dscv3" = $null; "mcp" = $null
        }

        $scoopCommandMap = @{
            "show" = "info"; "source" = "bucket"; "pin" = "hold"; "settings" = "config";
            "export" = "export"; "import" = "import";
            "hash" = $null; "validate" = $null; "repair" = $null; "configure" = $null; "dscv3" = $null; "mcp" = $null; "download" = $null; "features" = $null
        }

        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "Running '$Action' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget $actionLower $Name $RemainingArgs" -ForegroundColor Yellow; $success = $true; break }
                if ($Name -eq "") { if ($RemainingArgs) { winget $actionLower @RemainingArgs } else { winget $actionLower } } else { if ($RemainingArgs) { winget $actionLower $Name @RemainingArgs } else { winget $actionLower $Name } }
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "choco") {
                $chocoCmd = if ($chocoCommandMap.ContainsKey($actionLower)) { $chocoCommandMap[$actionLower] } else { $actionLower }
                if ($null -eq $chocoCmd) { Write-Host "[Chocolatey] No eqv for '$Action'. Skipping." -ForegroundColor DarkGray; continue }
                Write-Host "Running '$chocoCmd' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco $chocoCmd $Name $RemainingArgs" -ForegroundColor Yellow; $success = $true; break }
                if ($Name -eq "") { if ($RemainingArgs) { choco $chocoCmd @RemainingArgs } else { choco $chocoCmd } } else { if ($RemainingArgs) { choco $chocoCmd $Name @RemainingArgs } else { choco $chocoCmd $Name } }
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "scoop") {
                $scoopCmd = if ($scoopCommandMap.ContainsKey($actionLower)) { $scoopCommandMap[$actionLower] } else { $scoopCommandMap[$actionLower] }
                if ($null -eq $scoopCmd) { Write-Host "[Scoop] No eqv for '$Action'. Skipping." -ForegroundColor DarkGray; continue }
                Write-Host "Running '$scoopCmd' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop $scoopCmd $Name $RemainingArgs" -ForegroundColor Yellow; $success = $true; break }
                if ($Name -eq "") { if ($RemainingArgs) { scoop $scoopCmd @RemainingArgs } else { scoop $scoopCmd } } else { if ($RemainingArgs) { scoop $scoopCmd $Name @RemainingArgs } else { scoop $scoopCmd $Name } }
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; break }
            }
        }
        if (-not $success -and -not $DryRun) {
            Write-Host "Command '$Action' failed or has no equivalent across all configured package managers." -ForegroundColor Red
        }
    }
}
