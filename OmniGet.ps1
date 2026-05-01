<#
    .SYNOPSIS
    A universal wrapper for Windows package managers (WinGet, Chocolatey, Scoop).

    .DESCRIPTION
    The 'omniget' command provides a unified interface to install, update, remove, search, and manage packages across your entire Windows ecosystem. 
    It cascades through installed package managers based on your custom configuration order.
    If a package manager is not installed, it safely skips it.

    .EXAMPLE
    omniget install nodejs
    omniget outdated
    omniget install vlc --version 3.0.0 --pm scoop
    omniget upgrade all --dry-run
    omniget search powertoys
    omniget ui
    omniget config show
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
    Write-Host "OmniGet Universal Package Manager Wrapper" -ForegroundColor Cyan
    Write-Host "A unified wrapper for WinGet, Chocolatey, and Scoop.`n"
    
    Write-Host "usage: omniget [<command>] [<package_name>] [<options>]`n" 

    Write-Host "The following commands are natively enhanced by OmniGet:" -ForegroundColor Yellow
    Write-Host "  install    Installs the given package across configured PMs"
    Write-Host "  upgrade    Shows and performs available upgrades (use 'all' for system update)"
    Write-Host "  uninstall  Uninstalls the given package"
    Write-Host "  search     Find and show basic info of packages"
    Write-Host "  list       Display installed packages"
    Write-Host "  info       Shows information about a package"
    Write-Host "  outdated   Shows all available upgrades across configured PMs"
    Write-Host "  doctor     Scans for duplicated packages across managers"
    Write-Host "  config     Manage priority settings ('show' or 'reset')"
    Write-Host "  ui         Launch Interactive Terminal UI (TUI)"
    Write-Host "  gui        Launch Graphical UI (GUI placeholder)`n"
    
    Write-Host "Standard WinGet commands (passed through):" -ForegroundColor White
    Write-Host "  show, source, hash, validate, settings, features, export, import, pin, configure, download, repair, dscv3, mcp`n"

    Write-Host "The following options are available:" -ForegroundColor Yellow
    Write-Host "  --dry-run                   Mock execution without installing or modifying anything"
    Write-Host "  --pm <winget|choco|scoop>   Force execution using only the specified package manager"
    Write-Host "  --no-cascade                Stop if the first package manager fails (no fallback)"
    Write-Host "  -v,--version                Display the version of the tool"
    Write-Host "  --info                      Display general info of the tool"
    Write-Host "  -?,--help                   Shows help about the selected command"
}

$actionLower = $Action.ToLower().Trim()
$OmniGetVersion = "v1.0.0"

# Commands that act like global flags
if ($actionLower -in @("-v", "--version") -or $RemainingArgs -contains "-v" -or $RemainingArgs -contains "--version") {
    Write-Host "OmniGet $OmniGetVersion" -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) { $wVer = winget --version | Select-Object -First 1; Write-Host "WinGet: $wVer" -ForegroundColor DarkGray }
    if (Get-Command choco -ErrorAction SilentlyContinue) { $cVer = choco -v | Select-Object -First 1; Write-Host "Chocolatey: $cVer" -ForegroundColor DarkGray }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { $sVer = scoop -v | Select-Object -First 1; Write-Host "Scoop: $sVer" -ForegroundColor DarkGray }
    return
}

if ($RemainingArgs -contains "--info" -or ($actionLower -eq "info" -and $Name -eq "")) {
    Write-Host "OmniGet System Information ($OmniGetVersion)" -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) { winget --info }
    if (Get-Command choco -ErrorAction SilentlyContinue) { Write-Host "`n[Chocolatey]" -ForegroundColor Yellow; choco info chocolatey 2>$null }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { Write-Host "`n[Scoop]" -ForegroundColor Green; scoop info scoop 2>$null }
    return
}

# If empty action or help
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

$wgFlags = @("--silent", "--accept-package-agreements", "--accept-source-agreements")
$chFlags = @("-y", "--silent")
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
$hasWsl = [bool](Get-Command wsl -ErrorAction SilentlyContinue)

if ($availablePMs.Count -eq 0) {
    Write-Host "[ERROR] No supported package managers found! You must have WinGet, Chocolatey, or Scoop installed." -ForegroundColor Red
    return
}

# Priority Configuration
$configFile = Join-Path $env:USERPROFILE ".omniget_config.json"

function Invoke-PriorityWizard {
    Write-Host "`nWelcome to OmniGet Configuration Wizard!" -ForegroundColor Cyan
    Write-Host "Let's set your package manager priority order." -ForegroundColor White
    $priority = @()
    $remaining = $availablePMs | Select-Object -Unique
    
    while ($remaining.Count -gt 0) {
        $remStr = $remaining -join ', '
        Write-Host "Available to select: $remStr" -ForegroundColor Yellow
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
    $configData = @{ "Priority" = $priority }
    $configData | ConvertTo-Json | Set-Content $configFile -Force
    Write-Host "Priority saved successfully!" -ForegroundColor Green
    return $priority
}

$configPriority = @()
if (-not (Test-Path $configFile)) {
    if ($actionLower -match "ui|gui|config|help") { $configPriority = $availablePMs } else { $configPriority = Invoke-PriorityWizard }
} else {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $configPriority = $config.Priority
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
            Write-Host "$ESC`[31m0.$ESC`[0m Exit TUI"
            Write-Host ""
            
            $choice = Read-Host -Prompt "Select an option [0-6]"
            
            switch ($choice) {
                "1" { Write-Host ""; $pkg = Read-Host "Enter App to install"; if ($pkg) { & $scriptPath install $pkg } }
                "2" { Write-Host ""; $pkg = Read-Host "Enter App to upgrade"; if ($pkg) { & $scriptPath upgrade $pkg } }
                "3" { Write-Host ""; $pkg = Read-Host "Enter App to uninstall"; if ($pkg) { & $scriptPath uninstall $pkg } }
                "4" { Write-Host ""; & $scriptPath outdated }
                "5" { Write-Host ""; & $scriptPath upgrade all }
                "6" { Write-Host ""; & $scriptPath config show }
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
        Write-Host "Fetching outdated packages across your system..." -ForegroundColor Cyan
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "`n[WinGet] Available Upgrades:" -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: winget upgrade" -ForegroundColor Yellow }
                else { winget upgrade }
            }
            elseif ($pm -eq "choco") {
                Write-Host "`n[Chocolatey] Available Upgrades:" -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: choco outdated" -ForegroundColor Yellow }
                else { choco outdated }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "`n[Scoop] Available Upgrades:" -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: scoop status" -ForegroundColor Yellow }
                else { scoop status }
            }
        }
    }
    "all" {
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

        # Color Coded Summary Table Output
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
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "Attempting to install '$Name' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: winget install $Name --exact $wgFlags" -ForegroundColor Yellow; $success = $true; break }
                winget install $Name --exact @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "choco") {
                Write-Host "Attempting to install '$Name' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: choco install $Name $chFlags" -ForegroundColor Yellow; $success = $true; break }
                "y" | choco install $Name @chFlags
                if ($LASTEXITCODE -eq 0) { 
                    $success = $true
                    if ("winget" -in $availablePMs) { winget pin add --name $Name -e -q 2>$null }
                    break 
                }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "Attempting to install '$Name' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] Executing: scoop install $Name $scFlags" -ForegroundColor Yellow; $success = $true; break }
                scoop install $Name @scFlags
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; break }
            }
        }

        if (-not $success) {
            Write-Host "Failed to install '$Name' on Windows using configured PMs." -ForegroundColor Red
            if ($hasWsl -and -not $DryRun) {
                # WSL Fallback unchanged ...
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
            if (-not $DryRun) { Write-Host "'$Name' installed successfully!" -ForegroundColor Green }
        }
    }
    "upgrade" {
        if ($Name -eq "") { Write-Host "Please specify a package name." -ForegroundColor Red; return }
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Updating '$Name' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco upgrade $Name" -ForegroundColor Yellow; $success = $true; break }
                "y" | choco upgrade $Name @chFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Updating '$Name' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop update $Name" -ForegroundColor Yellow; $success = $true; break }
                scoop update $Name @scFlags
                if ($?) { $success = $true; break }
            }
            elseif ($pm -eq "winget") {
                Write-Host "Updating '$Name' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget upgrade $Name" -ForegroundColor Yellow; $success = $true; break }
                winget upgrade $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
        }
        if (-not $success) { Write-Host "Failed to update '$Name'." -ForegroundColor Red }
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
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Removing '$Name' via Chocolatey..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco uninstall $Name" -ForegroundColor Yellow; $success = $true; break }
                "y" | choco uninstall $Name @chFlags
                if ("winget" -in $availablePMs) { winget pin remove --name $Name -q 2>$null }
                $success = $true; break
            }
            elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Removing '$Name' via Scoop..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop uninstall $Name" -ForegroundColor Yellow; $success = $true; break }
                scoop uninstall $Name @scFlags
                $success = $true; break
            }
            elseif ($pm -eq "winget") {
                Write-Host "Removing '$Name' via WinGet..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget uninstall $Name" -ForegroundColor Yellow; $success = $true; break }
                winget uninstall $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
        }
        if (-not $success) { Write-Host "Failed to uninstall '$Name'." -ForegroundColor Red }
    }
    "search" {
        if ($Name -eq "") { Write-Host "Please specify a package name to search." -ForegroundColor Red; return }
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet] Searching for '$Name'..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget search $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($RemainingArgs) { winget search $Name @RemainingArgs } else { winget search $Name } }
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey] Searching for '$Name'..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco search $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($RemainingArgs) { choco search $Name @RemainingArgs } else { choco search $Name } }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop] Searching for '$Name'..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop search $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($RemainingArgs) { scoop search $Name @RemainingArgs } else { scoop search $Name } }
            }
        }
    }
    "list" {
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet] Installed Packages..." -ForegroundColor Cyan
                if ($DryRun) { Write-Host "[DRY-RUN] winget list $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($Name -eq "") { if ($RemainingArgs) { winget list @RemainingArgs } else { winget list } } else { if ($RemainingArgs) { winget list $Name @RemainingArgs } else { winget list $Name } } }
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey] Installed Packages..." -ForegroundColor Yellow
                if ($DryRun) { Write-Host "[DRY-RUN] choco list $Name $RemainingArgs" -ForegroundColor Yellow }
                else { if ($Name -eq "") { if ($RemainingArgs) { choco list @RemainingArgs } else { choco list } } else { if ($RemainingArgs) { choco list $Name @RemainingArgs } else { choco list $Name } } }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop] Installed Packages..." -ForegroundColor Green
                if ($DryRun) { Write-Host "[DRY-RUN] scoop list" -ForegroundColor Yellow }
                else { scoop list }
            }
        }
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
            $chocoRaw = choco list -lo
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
            Write-Host "System is healthy! No duplicates found." -ForegroundColor Green
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
                $scoopCmd = if ($scoopCommandMap.ContainsKey($actionLower)) { $scoopCommandMap[$actionLower] } else { $actionLower }
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

