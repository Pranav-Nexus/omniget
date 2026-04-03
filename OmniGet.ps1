<#
    .SYNOPSIS
    A universal wrapper for Windows package managers (WinGet, Chocolatey, Scoop).

    .DESCRIPTION
    The 'omniget' command provides a unified interface to install, update, remove, search, and manage packages across your entire Windows ecosystem. 
    It elegantly cascades through installed package managers (WinGet -> Chocolatey -> Scoop) to find and manage your software.
    If a package manager is not installed, it safely skips it.

    .EXAMPLE
    omniget install nodejs
    omniget install vlc --version 3.0.0
    omniget update all
    omniget search powertoys
    omniget list
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

# 1. Detect Installed Package Managers
# Ensures that even if a user doesn't have Chocolatey or Scoop, they won't get errors.
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$hasChoco = [bool](Get-Command choco -ErrorAction SilentlyContinue)
$hasScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)

if (-not ($hasWinget -or $hasChoco -or $hasScoop)) {
    Write-Host "❌ [ERROR] No supported package managers found! You must have WinGet, Chocolatey, or Scoop installed." -ForegroundColor Red
    return
}

# Fix PowerShell positional binding for things like 'omniget install --silent nodejs' where '--silent' gets bound to $Name
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

# Map our common aliases to their official counterparts
if ($actionLower -eq "update") { $actionLower = "upgrade" }
if ($actionLower -eq "remove") { $actionLower = "uninstall" }

# Handle 'update all' edge case natively parsing '--all' correctly
if ($actionLower -eq "upgrade" -and ($Name -ieq "all" -or $RemainingArgs -contains "--all" -or $RemainingArgs -contains "-all")) {
    $actionLower = "all"
    $RemainingArgs = @($RemainingArgs | Where-Object { $_ -ne "--all" -and $_ -ne "-all" })
    $Name = ""
}

# 2. Setup Default Flags for each ecosystem
$wgFlags = @("--silent", "--accept-package-agreements", "--accept-source-agreements")
$chFlags = @("-y", "--silent")
$scFlags = @()

# Pass through dynamic args (like --version, --interactive, etc.)
if ($null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0) {
    $wgFlags += $RemainingArgs
    $chFlags += $RemainingArgs
    $scFlags += $RemainingArgs
}

# 3. Main Command Routing
switch ($actionLower) {
    "all" {
        Write-Host "🚀 Updating EVERYTHING across your system..." -ForegroundColor Cyan
            
        if ($hasWinget) {
            Write-Host "`n[WinGet]" -ForegroundColor Gray
            winget upgrade --all @wgFlags
        }
        if ($hasChoco) {
            Write-Host "`n[Chocolatey]" -ForegroundColor Gray
            "y" | choco upgrade all @chFlags
        }
        if ($hasScoop) {
            Write-Host "`n[Scoop]" -ForegroundColor Gray
            scoop update
            scoop update * @scFlags
        }
        break
    }
    "install" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name to install." -ForegroundColor Red
            return
        }

        $success = $false

        # Try Winget directly
        if ($hasWinget) {
            Write-Host "🔍 Attempting to install '$Name' via WinGet..." -ForegroundColor Cyan
            winget install $Name --exact @wgFlags
            if ($LASTEXITCODE -eq 0) {
                $success = $true
            }
            else {
                Write-Host "⚠️ Not found in WinGet or install failed." -ForegroundColor DarkGray
            }
        }

        # Fallback to Chocolatey
        if (-not $success -and $hasChoco) {
            Write-Host "🍫 Attempting to install '$Name' via Chocolatey..." -ForegroundColor Yellow
            "y" | choco install $Name @chFlags
            if ($LASTEXITCODE -eq 0) {
                $success = $true
                # Optionally try to tell Winget to track this choco package so we avoid duplicate versions
                if ($hasWinget) { winget pin add --name $Name -e -q 2>$null } 
            }
            else {
                Write-Host "⚠️ Not found in Chocolatey or install failed." -ForegroundColor DarkGray
            }
        }

        # Fallback to Scoop (excellent for local DEV tools)
        if (-not $success -and $hasScoop) {
            Write-Host "🥄 Attempting to install '$Name' via Scoop..." -ForegroundColor Green
            scoop install $Name @scFlags
            if ($LASTEXITCODE -eq 0 -or $?) {
                $success = $true
            }
            else {
                Write-Host "⚠️ Not found in Scoop or install failed." -ForegroundColor DarkGray
            }
        }

        if (-not $success) {
            Write-Host "`n❌ Failed to install '$Name' across all available package managers." -ForegroundColor Red
        }
        else {
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

        # Check Choco first (since it leaves strong local markers, we don't want winget overwriting its state)
        if ($hasChoco -and (choco list | Select-String -Pattern "^$([regex]::Escape($Name))\s" -Quiet)) {
            Write-Host "📦 Updating '$Name' via Chocolatey..." -ForegroundColor Yellow
            "y" | choco upgrade $Name @chFlags
            if ($LASTEXITCODE -eq 0) { $success = $true }
        }
            
        # Check Scoop
        if (-not $success -and $hasScoop -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
            Write-Host "🥄 Updating '$Name' via Scoop..." -ForegroundColor Green
            scoop update $Name @scFlags
            if ($?) { $success = $true }
        }

        # Check Winget
        if (-not $success -and $hasWinget) {
            Write-Host "🔍 Updating '$Name' via WinGet..." -ForegroundColor Cyan
            winget upgrade $Name @wgFlags
            if ($LASTEXITCODE -eq 0) { $success = $true }
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

        if ($hasChoco -and (choco list | Select-String -Pattern "^$([regex]::Escape($Name))\s" -Quiet)) {
            Write-Host "🗑️ Removing '$Name' via Chocolatey..." -ForegroundColor Yellow
            "y" | choco uninstall $Name @chFlags
            if ($hasWinget) { winget pin remove --name $Name -q 2>$null }
            $success = $true
        }
            
        if (-not $success -and $hasScoop -and (scoop list | Select-String -Pattern "^\s*$([regex]::Escape($Name))\s" -Quiet)) {
            Write-Host "🗑️ Removing '$Name' via Scoop..." -ForegroundColor Green
            scoop uninstall $Name @scFlags
            $success = $true
        }

        if (-not $success -and $hasWinget) {
            Write-Host "🗑️ Removing '$Name' via WinGet..." -ForegroundColor Cyan
            winget uninstall $Name @wgFlags
            if ($LASTEXITCODE -eq 0) { $success = $true }
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
            
        if ($hasWinget) {
            Write-Host "`n🔍 [WinGet] Searching for '$Name'..." -ForegroundColor Cyan
            if ($RemainingArgs) { winget search $Name @RemainingArgs } else { winget search $Name }
        }
        if ($hasChoco) {
            Write-Host "`n🔍 [Chocolatey] Searching for '$Name'..." -ForegroundColor Yellow
            if ($RemainingArgs) { choco search $Name @RemainingArgs } else { choco search $Name }
        }
        if ($hasScoop) {
            Write-Host "`n🔍 [Scoop] Searching for '$Name'..." -ForegroundColor Green
            if ($RemainingArgs) { scoop search $Name @RemainingArgs } else { scoop search $Name }
        }
        break
    }
    "list" {
        if ($hasWinget) {
            Write-Host "`n📋 [WinGet] Installed Packages..." -ForegroundColor Cyan
            if ([string]::IsNullOrWhiteSpace($Name)) {
                if ($RemainingArgs) { winget list @RemainingArgs } else { winget list }
            }
            else {
                if ($RemainingArgs) { winget list $Name @RemainingArgs } else { winget list $Name }
            }
        }
        if ($hasChoco) {
            Write-Host "`n📋 [Chocolatey] Installed Packages..." -ForegroundColor Yellow
            if ([string]::IsNullOrWhiteSpace($Name)) {
                if ($RemainingArgs) { choco list @RemainingArgs } else { choco list }
            }
            else {
                if ($RemainingArgs) { choco list $Name @RemainingArgs } else { choco list $Name }
            }
        }
        if ($hasScoop) {
            Write-Host "`n📋 [Scoop] Installed Packages..." -ForegroundColor Green
            scoop list  # Scoop list doesn't natively filter by specific package name reliably
        }
        break
    }
    "info" {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Host "⚠️ Please specify a package name." -ForegroundColor Red
            return
        }
            
        if ($hasWinget) {
            Write-Host "`nℹ️ [WinGet] Info for '$Name'..." -ForegroundColor Cyan
            if ($RemainingArgs) { winget show $Name @RemainingArgs } else { winget show $Name }
        }
        if ($hasChoco) {
            Write-Host "`nℹ️ [Chocolatey] Info for '$Name'..." -ForegroundColor Yellow
            if ($RemainingArgs) { choco info $Name @RemainingArgs } else { choco info $Name }
        }
        if ($hasScoop) {
            Write-Host "`nℹ️ [Scoop] Info for '$Name'..." -ForegroundColor Green
            if ($RemainingArgs) { scoop info $Name @RemainingArgs } else { scoop info $Name }
        }
        break
    }
    default {
        # Catch-all fallback for commands not hardcoded
        $success = $false
        if ($hasWinget) {
            Write-Host "🚀 Running '$Action' via WinGet..." -ForegroundColor Cyan
            if ([string]::IsNullOrWhiteSpace($Name)) {
                if ($wgFlags) { winget $actionLower @wgFlags } else { winget $actionLower }
            }
            else {
                if ($wgFlags) { winget $actionLower $Name @wgFlags } else { winget $actionLower $Name }
            }
            if ($LASTEXITCODE -eq 0) { $success = $true }
        }
            
        if (-not $success -and $hasChoco) {
            Write-Host "🍫 Running '$Action' via Chocolatey..." -ForegroundColor Yellow
            if ([string]::IsNullOrWhiteSpace($Name)) {
                if ($chFlags) { "y" | choco $actionLower @chFlags } else { "y" | choco $actionLower }
            }
            else {
                if ($chFlags) { "y" | choco $actionLower $Name @chFlags } else { "y" | choco $actionLower $Name }
            }
            if ($LASTEXITCODE -eq 0) { $success = $true }
        }

        if (-not $success -and $hasScoop) {
            Write-Host "🥄 Running '$Action' via Scoop..." -ForegroundColor Green
            if ([string]::IsNullOrWhiteSpace($Name)) {
                if ($scFlags) { scoop $actionLower @scFlags } else { scoop $actionLower }
            }
            else {
                if ($scFlags) { scoop $actionLower $Name @scFlags } else { scoop $actionLower $Name }
            }
            if ($LASTEXITCODE -eq 0 -or $?) { $success = $true }
        }

        if (-not $success) {
            Write-Host "❌ Command failed across all package managers or is unsupported." -ForegroundColor Red
        }
        break
    }
}
