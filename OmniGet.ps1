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
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$Name,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

# 1. Detect Installed Tools
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$hasChoco = [bool](Get-Command choco -ErrorAction SilentlyContinue)
$hasScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
$hasWsl = [bool](Get-Command wsl -ErrorAction SilentlyContinue)

$availablePMs = @()
if ($hasWinget) { $availablePMs += "winget" }
if ($hasChoco) { $availablePMs += "choco" }
if ($hasScoop) { $availablePMs += "scoop" }

if ($availablePMs.Count -eq 0) {
    Write-Host "❌ [ERROR] No supported package managers found! You must have WinGet, Chocolatey, or Scoop installed." -ForegroundColor Red
    return
}

# Fix PowerShell positional binding for things like 'omniget install --silent nodejs'
if (-not [string]::IsNullOrWhiteSpace($Name) -and $Name.StartsWith("-")) {
    $RemainingArgs = @($Name) + @($RemainingArgs | Where-Object { $null -ne $_ })
    $Name = ""
}

if ([string]::IsNullOrWhiteSpace($Name) -and $RemainingArgs) {
    $newRemaining = @()
    foreach ($arg in $RemainingArgs) {
        if ([string]::IsNullOrWhiteSpace($Name) -and -not $arg.StartsWith("-")) {
            $Name = $arg
        } else {
            $newRemaining += $arg
        }
    }
    $RemainingArgs = $newRemaining
}

$actionLower = $Action.ToLower()

# Map aliases
if ($actionLower -eq "update") { $actionLower = "upgrade" }
if ($actionLower -eq "remove") { $actionLower = "uninstall" }

# Handle 'update all'
if ($actionLower -eq "upgrade" -and ($Name -ieq "all" -or $RemainingArgs -contains "--all" -or $RemainingArgs -contains "-all")) {
    $actionLower = "all"
    $RemainingArgs = @($RemainingArgs | Where-Object { $_ -ne "--all" -and $_ -ne "-all" })
    $Name = ""
}

# Setup Default Flags
$wgFlags = @("--silent", "--accept-package-agreements", "--accept-source-agreements")
$chFlags = @("-y", "--silent")
$scFlags = @()

if ($null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0) {
    $wgFlags += $RemainingArgs
    $chFlags += $RemainingArgs
    $scFlags += $RemainingArgs
}

# 2. Configuration Management
$configFile = Join-Path $env:USERPROFILE ".omniget_config.json"

function Run-PriorityWizard {
    Write-Host "`n👋 Welcome to OmniGet First Run / Config!" -ForegroundColor Cyan
    Write-Host "Let's set your package manager priority order." -ForegroundColor White
    $priority = @()
    $remaining = $availablePMs | Select-Object -Unique
    
    while ($remaining.Count -gt 0) {
        Write-Host "Available to select: $($remaining -join ', ')" -ForegroundColor Yellow
        $choice = Read-Host "Which one should be priority $($priority.Count + 1)? (type name)"
        $choiceLower = $choice.Trim().ToLower()
        if ($remaining -contains $choiceLower) {
            $priority += $choiceLower
            $remaining = $remaining | Where-Object { $_ -ne $choiceLower }
        } else {
            Write-Host "⚠️ Invalid choice. Please type one of the available names." -ForegroundColor Red
        }
    }
    $configData = @{ "Priority" = $priority }
    $configData | ConvertTo-Json | Set-Content $configFile -Force
    Write-Host "✅ Priority saved!" -ForegroundColor Green
    return $priority
}

if ($actionLower -eq "priority") {
    Run-PriorityWizard | Out-Null
    return
}

if (-not (Test-Path $configFile)) {
    $configPriority = Run-PriorityWizard
} else {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $configPriority = $config.Priority
    } catch {
        $configPriority = Run-PriorityWizard
    }
}

$activePriority = $configPriority | Where-Object { $availablePMs -contains $_ }
if ($activePriority.Count -eq 0) { $activePriority = $availablePMs }

# 3. Main Command Routing
switch ($actionLower) {
    "doctor" {
        Write-Host "🩺 OmniGet Conflict Doctor" -ForegroundColor Cyan
        Write-Host "Scanning for duplicated packages across package managers...`n" -ForegroundColor DarkGray
        
        $chocoPackages = @()
        if ("choco" -in $activePriority) {
            $chocoRaw = choco list -lo
            foreach ($line in $chocoRaw) {
                if ($line -match "^\s*([a-zA-Z0-9\-\._]+)\s+\d") {
                    $n = $matches[1]
                    if ($n -ne "chocolatey") { $chocoPackages += $n }
                }
            }
        }

        $conflicts = @()
        if ("winget" -in $activePriority -and $chocoPackages.Count -gt 0) {
            Write-Host "Comparing $($chocoPackages.count) Chocolatey packages against WinGet database... This may take a moment." -ForegroundColor Cyan
            foreach ($pkg in $chocoPackages) {
                $wgSearch = winget list $pkg -q 2>$null | Select-String $pkg
                if ($wgSearch) {
                    $conflicts += $pkg
                }
            }
        }

        if ($conflicts.Count -gt 0) {
            Write-Host "`n⚠️ Found $($conflicts.Count) potential conflicts (installed in both WinGet and Choco):" -ForegroundColor Yellow
            $highest = $activePriority | Where-Object { $_ -eq "winget" -or $_ -eq "choco" } | Select-Object -First 1
            
            foreach ($conflict in $conflicts) {
                Write-Host "`n- $conflict" -ForegroundColor White
                Write-Host "   💡 Priority Recommendation: Keep $highest, uninstall the other." -ForegroundColor Cyan
                $ans = Read-Host "   Action? [W]inGet uninstall, [C]hoco uninstall, [S]kip"
                if ($ans -match "^w") {
                    winget uninstall $conflict
                } elseif ($ans -match "^c") {
                    "y" | choco uninstall $conflict
                }
            }
        } else {
            Write-Host "`n✅ System is healthy! No duplicates found." -ForegroundColor Green
        }
        break
    }
    "all" {
        Write-Host "🚀 Updating EVERYTHING acting in priority order: $($activePriority -join ' -> ')" -ForegroundColor Cyan
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "`n[WinGet]" -ForegroundColor Gray
                winget upgrade --all @wgFlags
            } elseif ($pm -eq "choco") {
                Write-Host "`n[Chocolatey]" -ForegroundColor Gray
                "y" | choco upgrade all @chFlags
            } elseif ($pm -eq "scoop") {
                Write-Host "`n[Scoop]" -ForegroundColor Gray
                scoop update
                scoop update * @scFlags
            }
        }
        break
    }
    "install" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name to install." -ForegroundColor Red
            return
        }

        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "🔍 Attempting to install '$Name' via WinGet..." -ForegroundColor Cyan
                winget install $Name --exact @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            } elseif ($pm -eq "choco") {
                Write-Host "🍫 Attempting to install '$Name' via Chocolatey..." -ForegroundColor Yellow
                "y" | choco install $Name @chFlags
                if ($LASTEXITCODE -eq 0) { 
                    $success = $true
                    if ("winget" -in $availablePMs) {
                        Write-Host "📌 [Intelligent Pinning] Pinning '$Name' in WinGet to prevent future conflicts..." -ForegroundColor Magenta
                        winget pin add --name $Name -e -q 2>$null
                    }
                    break 
                }
            } elseif ($pm -eq "scoop") {
                Write-Host "🥄 Attempting to install '$Name' via Scoop..." -ForegroundColor Green
                scoop install $Name @scFlags
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; break }
            }
        }

        if (-not $success) {
            Write-Host "`n❌ Failed to install '$Name' natively on Windows." -ForegroundColor Red
            
            if ($hasWsl) {
                Write-Host "`n🐧 Package not found in Windows. Checking WSL..." -ForegroundColor Cyan
                $distrosRaw = wsl.exe --list --quiet 2>$null
                if ($distrosRaw) {
                    $distros = ($distrosRaw -replace "\x00", "") -split "`r`n" | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
                    
                    if ($distros.Count -gt 0) {
                        $ans = Read-Host "Would you like to install '$Name' in WSL instead? [Y]es / [N]o"
                        if ($ans -match "^y") {
                            $targetDistros = @()
                            if ($distros.Count -gt 1) {
                                Write-Host "`nFound multiple WSL distributions:" -ForegroundColor Yellow
                                for ($i=0; $i -lt $distros.Count; $i++) {
                                    Write-Host "$($i+1). $($distros[$i])"
                                }
                                $ansDistro = Read-Host "Which ones? (number, comma-separated, or 'all')"
                                if ($ansDistro.ToLower() -eq "all") {
                                    $targetDistros = $distros
                                } else {
                                    $indices = $ansDistro -split "," | ForEach-Object { [int]$_.Trim() - 1 }
                                    foreach ($i in $indices) {
                                        if ($i -ge 0 -and $i -lt $distros.Count) { $targetDistros += $distros[$i] }
                                    }
                                }
                            } else {
                                $targetDistros = $distros
                            }
                            
                            foreach ($d in $targetDistros) {
                                Write-Host "`n[WSL: $d] Detecting package manager & installing '$Name'..." -ForegroundColor Magenta
                                $shCmd = "if command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y $Name; elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm $Name; elif command -v dnf >/dev/null; then sudo dnf install -y $Name; elif command -v zypper >/dev/null; then sudo zypper install -y $Name; else echo 'Unknown package manager'; exit 1; fi"
                                wsl.exe -d $d -e sh -c $shCmd
                            }
                            $success = $true 
                        }
                    }
                }
            }
        } else {
            Write-Host "`n✅ '$Name' installed successfully!" -ForegroundColor Green
        }
        break
    }
    "upgrade" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name to upgrade, or use 'omniget update all'." -ForegroundColor Red
            return
        }
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "📦 Updating '$Name' via Chocolatey..." -ForegroundColor Yellow
                "y" | choco upgrade $Name @chFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            } elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "🥄 Updating '$Name' via Scoop..." -ForegroundColor Green
                scoop update $Name @scFlags
                if ($?) { $success = $true; break }
            } elseif ($pm -eq "winget") {
                Write-Host "🔍 Updating '$Name' via WinGet..." -ForegroundColor Cyan
                winget upgrade $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
        }
        if (-not $success) {
            Write-Host "❌ Failed to update '$Name'. It might not be installed, not supported, or no updates are available." -ForegroundColor Red
        }
        break
    }
    "uninstall" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name to uninstall." -ForegroundColor Red
            return
        }
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "choco" -and (choco list | Select-String -Pattern "^$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "🗑️ Removing '$Name' via Chocolatey..." -ForegroundColor Yellow
                "y" | choco uninstall $Name @chFlags
                if ("winget" -in $availablePMs) {
                    Write-Host "📌 [Intelligent Pinning] Removing WinGet pin for '$Name'..." -ForegroundColor Magenta
                    winget pin remove --name $Name -q 2>$null
                }
                $success = $true; break
            } elseif ($pm -eq "scoop" -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
                Write-Host "🗑️ Removing '$Name' via Scoop..." -ForegroundColor Green
                scoop uninstall $Name @scFlags
                $success = $true; break
            } elseif ($pm -eq "winget") {
                Write-Host "🗑️ Removing '$Name' via WinGet..." -ForegroundColor Cyan
                winget uninstall $Name @wgFlags
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            }
        }
        if (-not $success) {
            Write-Host "❌ Failed to uninstall '$Name' or it was not found on your system." -ForegroundColor Red
        }
        break
    }
    "search" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name to search." -ForegroundColor Red
            return
        }
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "`n🔍 [WinGet] Searching for '$Name'..." -ForegroundColor Cyan
                if ($RemainingArgs) { winget search $Name @RemainingArgs } else { winget search $Name }
            } elseif ($pm -eq "choco") {
                Write-Host "`n🔍 [Chocolatey] Searching for '$Name'..." -ForegroundColor Yellow
                if ($RemainingArgs) { choco search $Name @RemainingArgs } else { choco search $Name }
            } elseif ($pm -eq "scoop") {
                Write-Host "`n🔍 [Scoop] Searching for '$Name'..." -ForegroundColor Green
                if ($RemainingArgs) { scoop search $Name @RemainingArgs } else { scoop search $Name }
            }
        }
        break
    }
    "list" {
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "`n📋 [WinGet] Installed Packages..." -ForegroundColor Cyan
                if ([string]::IsNullOrWhiteSpace($Name)) { if ($RemainingArgs) { winget list @RemainingArgs } else { winget list } } else { if ($RemainingArgs) { winget list $Name @RemainingArgs } else { winget list $Name } }
            } elseif ($pm -eq "choco") {
                Write-Host "`n📋 [Chocolatey] Installed Packages..." -ForegroundColor Yellow
                if ([string]::IsNullOrWhiteSpace($Name)) { if ($RemainingArgs) { choco list @RemainingArgs } else { choco list } } else { if ($RemainingArgs) { choco list $Name @RemainingArgs } else { choco list $Name } }
            } elseif ($pm -eq "scoop") {
                Write-Host "`n📋 [Scoop] Installed Packages..." -ForegroundColor Green
                scoop list
            }
        }
        break
    }
    "info" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name." -ForegroundColor Red
            return
        }
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "`nℹ️ [WinGet] Info for '$Name'..." -ForegroundColor Cyan
                if ($RemainingArgs) { winget show $Name @RemainingArgs } else { winget show $Name }
            } elseif ($pm -eq "choco") {
                Write-Host "`nℹ️ [Chocolatey] Info for '$Name'..." -ForegroundColor Yellow
                if ($RemainingArgs) { choco info $Name @RemainingArgs } else { choco info $Name }
            } elseif ($pm -eq "scoop") {
                Write-Host "`nℹ️ [Scoop] Info for '$Name'..." -ForegroundColor Green
                if ($RemainingArgs) { scoop info $Name @RemainingArgs } else { scoop info $Name }
            }
        }
        break
    }
    default {
        $success = $false
        foreach ($pm in $activePriority) {
            if ($pm -eq "winget") {
                Write-Host "🚀 Running '$Action' via WinGet..." -ForegroundColor Cyan
                if ([string]::IsNullOrWhiteSpace($Name)) { if ($wgFlags) { winget $actionLower @wgFlags } else { winget $actionLower } } else { if ($wgFlags) { winget $actionLower $Name @wgFlags } else { winget $actionLower $Name } }
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            } elseif ($pm -eq "choco") {
                Write-Host "🍫 Running '$Action' via Chocolatey..." -ForegroundColor Yellow
                if ([string]::IsNullOrWhiteSpace($Name)) { if ($chFlags) { "y" | choco $actionLower @chFlags } else { "y" | choco $actionLower } } else { if ($chFlags) { "y" | choco $actionLower $Name @chFlags } else { "y" | choco $actionLower $Name } }
                if ($LASTEXITCODE -eq 0) { $success = $true; break }
            } elseif ($pm -eq "scoop") {
                Write-Host "🥄 Running '$Action' via Scoop..." -ForegroundColor Green
                if ([string]::IsNullOrWhiteSpace($Name)) { if ($scFlags) { scoop $actionLower @scFlags } else { scoop $actionLower } } else { if ($scFlags) { scoop $actionLower $Name @scFlags } else { scoop $actionLower $Name } }
                if ($LASTEXITCODE -eq 0 -or $?) { $success = $true; break }
            }
        }
        if (-not $success) {
            Write-Host "❌ Command failed across all package managers or is unsupported." -ForegroundColor Red
        }
        break
    }
}
