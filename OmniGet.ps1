<#
    .SYNOPSIS
    A universal wrapper for Windows package managers (WinGet, Chocolatey, Scoop).

    .DESCRIPTION
    The 'omniget' command provides a unified interface to install, update, remove, search, and manage packages across your entire Windows ecosystem. 
    It cascades through installed package managers based on your custom configuration order.
    If a package manager is not installed, it safely skips it.

    .EXAMPLE
    omniget install nodejs
    omniget install vlc --version 3.0.0
    omniget update all
    omniget search powertoys
    omniget list
    omniget priority
    omniget doctor
    #>
$Action = ""
$Name = ""
$RemainingArgs = @()

foreach ($a in $args) {
    if ($Action -eq "" -and -not $a.StartsWith("-")) {
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
    
    Write-Host "The omniget command line utility enables installing applications and other packages from the command line while elegantly cascading through installed package managers.`n"
    
    Write-Host "usage: omniget [<command>] [<package_name>] [<options>]`n" 

    Write-Host "The following commands are natively enhanced by OmniGet:" -ForegroundColor Yellow
    Write-Host "  install    Installs the given package across configured package managers"
    Write-Host "  upgrade    Shows and performs available upgrades"
    Write-Host "  uninstall  Uninstalls the given package"
    Write-Host "  search     Find and show basic info of packages"
    Write-Host "  list       Display installed packages"
    Write-Host "  info       Shows information about a package"
    Write-Host "  doctor     [OmniGet] Scans for duplicated packages across managers"
    Write-Host "  priority   [OmniGet] Configure your package manager priority order`n"
    
    Write-Host "Standard WinGet commands (passed through):" -ForegroundColor White
    Write-Host "  show, source, hash, validate, settings, features, export, import, pin, configure, download, repair, dscv3, mcp`n"

    Write-Host "The following options are available:" -ForegroundColor Yellow
    Write-Host "  -v,--version                Display the version of the tool"
    Write-Host "  --info                      Display general info of the tool"
    Write-Host "  -?,--help                   Shows help about the selected command"
    Write-Host "  (All other WinGet/Choco/Scoop options are dynamically passed through to the respective installer)`n"
}

$actionLower = $Action.ToLower().Trim()
$OmniGetVersion = "v1.0.1"

# Commands that act like global flags
if ($actionLower -in @("-v", "--version") -or $RemainingArgs -contains "-v" -or $RemainingArgs -contains "--version") {
    Write-Host "OmniGet $OmniGetVersion" -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) { 
        $wVer = winget --version
        Write-Host "WinGet: $wVer" -ForegroundColor DarkGray
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $cVer = choco -v | Select-Object -First 1
        Write-Host "Chocolatey: $cVer" -ForegroundColor DarkGray
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $sVer = scoop -v | Select-Object -First 1
        Write-Host "Scoop: $sVer" -ForegroundColor DarkGray
    }
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

# Normalize aliases — OmniGet shorthands + WinGet built-in command aliases
if ($actionLower -eq "update")  { $actionLower = "upgrade" }
if ($actionLower -eq "remove")  { $actionLower = "uninstall" }
if ($actionLower -eq "view")    { $actionLower = "show" }    # WinGet alias for 'show'
if ($actionLower -eq "find")    { $actionLower = "search" }  # WinGet alias for 'search'

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
    Write-Host ""
    Write-Host "Welcome to OmniGet First Run / Config!" -ForegroundColor Cyan
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
    Write-Host "Priority saved!" -ForegroundColor Green
    return $priority
}

if ($actionLower -eq "priority") {
    Invoke-PriorityWizard | Out-Null
    return
}

$configPriority = @()
if (-not (Test-Path $configFile)) {
    $configPriority = Invoke-PriorityWizard
}
else {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $configPriority = $config.Priority
    }
    catch {
        $configPriority = Run-PriorityWizard
    }
}

$activePriority = $configPriority | Where-Object { $availablePMs -contains $_ }
if ($activePriority.Count -eq 0) { $activePriority = $availablePMs }

# Main Command Routing
switch ($actionLower) {
    "doctor" {
        Write-Host "OmniGet Conflict Doctor" -ForegroundColor Cyan
        Write-Host "Scanning for duplicated packages across package managers..." -ForegroundColor DarkGray
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
            Write-Host "Comparing $cCount Chocolatey packages against WinGet database... This may take a moment." -ForegroundColor Cyan
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
                if ($ans -match '^w') { winget uninstall $conflict }
                elseif ($ans -match '^c') { "y" | choco uninstall $conflict }
            }
        }
        else {
            Write-Host "System is healthy! No duplicates found." -ForegroundColor Green
        }
    }
    "all" {
        $apStr = $activePriority -join ' -> '
        Write-Host "Updating EVERYTHING acting in priority order: $apStr" -ForegroundColor Cyan
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet]" -ForegroundColor Gray
                winget upgrade --all @wgFlags
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey]" -ForegroundColor Gray
                "y" | choco upgrade all @chFlags
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop]" -ForegroundColor Gray
                scoop update
                scoop update * @scFlags
            }
        }
    }
    "install" {
        if ($Name -eq "") {
            Write-Host "Please specify a package name to install." -ForegroundColor Red
            return
        }
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "Attempting to install '$Name' via WinGet..." -ForegroundColor Cyan
                winget install $Name --exact @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "choco") {
                Write-Host "Attempting to install '$Name' via Chocolatey..." -ForegroundColor Yellow
                "y" | choco install $Name @chFlags
                if ($LASTEXITCODE -eq 0) { 
                    $success = $true
                    if ("winget" -in $availablePMs) {
                        Write-Host "[Intelligent Pinning] Pinning '$Name' in WinGet to prevent future conflicts..." -ForegroundColor Magenta
                        winget pin add --name $Name -e -q 2>$null
                    }
                    break 
                }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "Attempting to install '$Name' via Scoop..." -ForegroundColor Green
                scoop install $Name @scFlags
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; break }
            }
        }

        if (-not $success) {
            Write-Host "Failed to install '$Name' natively on Windows." -ForegroundColor Red
            if ($hasWsl) {
                Write-Host "Package not found in Windows. Checking WSL..." -ForegroundColor Cyan
                $distrosRaw = wsl.exe --list --quiet 2>$null
                if ($distrosRaw) {
                    $distros = ($distrosRaw -replace '\x00', '') -split '\r?\n' | Where-Object { $_.Trim() -ne '' }
                    if ($distros.Count -gt 0) {
                        $ans = Read-Host "Would you like to install '$Name' in WSL instead? [Y]es / [N]o"
                        if ($ans -match '^y') {
                            $targetDistros = @()
                            if ($distros.Count -gt 1) {
                                Write-Host "Found multiple WSL distributions:" -ForegroundColor Yellow
                                for ($i = 0; $i -lt $distros.Count; $i++) {
                                    $idx = $i + 1
                                    Write-Host "$idx. $($distros[$i])"
                                }
                                $ansDistro = Read-Host "Which ones? (number, comma-separated, or 'all')"
                                if ($ansDistro.ToLower() -eq 'all') {
                                    $targetDistros = $distros
                                }
                                else {
                                    $indices = $ansDistro -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
                                    foreach ($i in $indices) {
                                        if ($i -ge 0 -and $i -lt $distros.Count) { $targetDistros += $distros[$i] }
                                    }
                                }
                            }
                            else {
                                $targetDistros = $distros
                            }
                            
                            foreach ($d in $targetDistros) {
                                Write-Host "[WSL: $d] Detecting package manager and installing '$Name'..." -ForegroundColor Magenta
                                $shCmd = 'if command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y ' + $Name + '; elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm ' + $Name + '; elif command -v dnf >/dev/null; then sudo dnf install -y ' + $Name + '; elif command -v zypper >/dev/null; then sudo zypper install -y ' + $Name + '; else echo "Unknown package manager"; exit 1; fi'
                                wsl.exe -d $d -e sh -c "$shCmd"
                            }
                            $success = $true 
                        }
                    }
                }
            }
        }
        else {
            Write-Host "'$Name' installed successfully!" -ForegroundColor Green
        }
    }
    "upgrade" {
        if ($Name -eq "") {
            Write-Host "Please specify a package name to upgrade." -ForegroundColor Red
            return
        }
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Updating '$Name' via Chocolatey..." -ForegroundColor Yellow
                "y" | choco upgrade $Name @chFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Updating '$Name' via Scoop..." -ForegroundColor Green
                scoop update $Name @scFlags
                if ($?) { $success = $true; break }
            }
            elseif ($pm -eq "winget") {
                Write-Host "Updating '$Name' via WinGet..." -ForegroundColor Cyan
                winget upgrade $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
        }
        if (-not $success) {
            Write-Host "Failed to update '$Name'." -ForegroundColor Red
        }
    }
    "uninstall" {
        if ($Name -eq "") {
            Write-Host "Please specify a package name to uninstall." -ForegroundColor Red
            return
        }
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Removing '$Name' via Chocolatey..." -ForegroundColor Yellow
                "y" | choco uninstall $Name @chFlags
                if ("winget" -in $availablePMs) {
                    Write-Host "[Intelligent Pinning] Removing WinGet pin for '$Name'..." -ForegroundColor Magenta
                    winget pin remove --name $Name -q 2>$null
                }
                $success = $true; break
            }
            elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "Removing '$Name' via Scoop..." -ForegroundColor Green
                scoop uninstall $Name @scFlags
                $success = $true; break
            }
            elseif ($pm -eq "winget") {
                Write-Host "Removing '$Name' via WinGet..." -ForegroundColor Cyan
                winget uninstall $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
        }
        if (-not $success) {
            Write-Host "Failed to uninstall '$Name'." -ForegroundColor Red
        }
    }
    "search" {
        if ($Name -eq "") {
            Write-Host "Please specify a package name to search." -ForegroundColor Red
            return
        }
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet] Searching for '$Name'..." -ForegroundColor Cyan
                if ($RemainingArgs) { winget search $Name @RemainingArgs } else { winget search $Name }
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey] Searching for '$Name'..." -ForegroundColor Yellow
                if ($RemainingArgs) { choco search $Name @RemainingArgs } else { choco search $Name }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop] Searching for '$Name'..." -ForegroundColor Green
                if ($RemainingArgs) { scoop search $Name @RemainingArgs } else { scoop search $Name }
            }
        }
    }
    "list" {
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet] Installed Packages..." -ForegroundColor Cyan
                if ($Name -eq "") { if ($RemainingArgs) { winget list @RemainingArgs } else { winget list } } else { if ($RemainingArgs) { winget list $Name @RemainingArgs } else { winget list $Name } }
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey] Installed Packages..." -ForegroundColor Yellow
                if ($Name -eq "") { if ($RemainingArgs) { choco list @RemainingArgs } else { choco list } } else { if ($RemainingArgs) { choco list $Name @RemainingArgs } else { choco list $Name } }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop] Installed Packages..." -ForegroundColor Green
                scoop list
            }
        }
    }
    "info" {
        if ($Name -eq "") {
            Write-Host "Please specify a package name." -ForegroundColor Red
            return
        }
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "[WinGet] Info for '$Name'..." -ForegroundColor Cyan
                if ($RemainingArgs) { winget show $Name @RemainingArgs } else { winget show $Name }
            }
            elseif ($pm -eq "choco") {
                Write-Host "[Chocolatey] Info for '$Name'..." -ForegroundColor Yellow
                if ($RemainingArgs) { choco info $Name @RemainingArgs } else { choco info $Name }
            }
            elseif ($pm -eq "scoop") {
                Write-Host "[Scoop] Info for '$Name'..." -ForegroundColor Green
                if ($RemainingArgs) { scoop info $Name @RemainingArgs } else { scoop info $Name }
            }
        }
    }
    default {
        # Translation maps: WinGet command -> Chocolatey/Scoop equivalent ($null = no equivalent, skip gracefully)
        # ─── Chocolatey command translation map ────────────────────────────────
        # Keys: WinGet/OmniGet command  |  Value: Choco equivalent ($null = skip)
        $chocoCommandMap = @{
            # Shared commands with different names
            "show"      = "info"        # winget show     → choco info
            "settings"  = "config"      # winget settings → choco config
            "features"  = "feature"     # winget features → choco feature
            # Shared commands — same name in choco (listed for clarity)
            "source"    = "source"
            "pin"       = "pin"
            "export"    = "export"
            "download"  = "download"
            # Choco-native commands — pass straight through (not in map = pass-as-is)
            # "apikey", "new", "pack", "push", "template" → handled by else { $actionLower }
            # WinGet-only — no Chocolatey equivalent, skip gracefully
            "hash"      = $null
            "validate"  = $null
            "import"    = $null
            "repair"    = $null
            "configure" = $null
            "dscv3"     = $null
            "mcp"       = $null
        }

        # ─── Scoop command translation map ──────────────────────────────────────
        # Keys: WinGet/OmniGet command  |  Value: Scoop equivalent ($null = skip)
        $scoopCommandMap = @{
            # Shared commands with different names
            "show"      = "info"        # winget show     → scoop info
            "source"    = "bucket"      # winget source   → scoop bucket
            "pin"       = "hold"        # winget pin      → scoop hold
            "settings"  = "config"      # winget settings → scoop config
            # Shared commands — same name in scoop (listed for clarity)
            "export"    = "export"
            "import"    = "import"
            # Scoop-native commands — pass straight through (not in map = pass-as-is)
            # "bucket", "cache", "checkup", "cleanup", "home", "hold",
            # "unhold", "status", "cat", "prefix", "alias", "shim",
            # "virustotal" → handled by else { $actionLower }
            # WinGet-only — no Scoop equivalent, skip gracefully
            "hash"      = $null
            "validate"  = $null
            "repair"    = $null
            "configure" = $null
            "dscv3"     = $null
            "mcp"       = $null
            "download"  = $null         # scoop has no direct download command
            "features"  = $null
        }

        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "Running '$Action' via WinGet..." -ForegroundColor Cyan
                # Only pass user-supplied flags here — NOT the auto-injected install flags
                if ($Name -eq "") { if ($RemainingArgs) { winget $actionLower @RemainingArgs } else { winget $actionLower } } else { if ($RemainingArgs) { winget $actionLower $Name @RemainingArgs } else { winget $actionLower $Name } }
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "choco") {
                $chocoCmd = if ($chocoCommandMap.ContainsKey($actionLower)) { $chocoCommandMap[$actionLower] } else { $actionLower }
                if ($null -eq $chocoCmd) {
                    Write-Host "[Chocolatey] No equivalent for '$Action'. Skipping." -ForegroundColor DarkGray
                    continue
                }
                if ($chocoCmd -ne $actionLower) { Write-Host "[Chocolatey] Mapping '$Action' -> '$chocoCmd'..." -ForegroundColor DarkGray }
                Write-Host "Running '$chocoCmd' via Chocolatey..." -ForegroundColor Yellow
                if ($Name -eq "") { if ($RemainingArgs) { choco $chocoCmd @RemainingArgs } else { choco $chocoCmd } } else { if ($RemainingArgs) { choco $chocoCmd $Name @RemainingArgs } else { choco $chocoCmd $Name } }
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
            elseif ($pm -eq "scoop") {
                $scoopCmd = if ($scoopCommandMap.ContainsKey($actionLower)) { $scoopCommandMap[$actionLower] } else { $actionLower }
                if ($null -eq $scoopCmd) {
                    Write-Host "[Scoop] No equivalent for '$Action'. Skipping." -ForegroundColor DarkGray
                    continue
                }
                if ($scoopCmd -ne $actionLower) { Write-Host "[Scoop] Mapping '$Action' -> '$scoopCmd'..." -ForegroundColor DarkGray }
                Write-Host "Running '$scoopCmd' via Scoop..." -ForegroundColor Green
                if ($Name -eq "") { if ($RemainingArgs) { scoop $scoopCmd @RemainingArgs } else { scoop $scoopCmd } } else { if ($RemainingArgs) { scoop $scoopCmd $Name @RemainingArgs } else { scoop $scoopCmd $Name } }
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; break }
            }
        }
        if (-not $success) {
            Write-Host "Command '$Action' failed or has no equivalent across all configured package managers." -ForegroundColor Red
        }
    }
}
