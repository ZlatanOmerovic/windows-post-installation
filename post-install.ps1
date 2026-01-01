#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automated software installation script for Windows
.DESCRIPTION
    Downloads and installs latest versions of common development tools and applications silently
.NOTES
    This script MUST be run as Administrator
    Requires Windows 10 1809 or later (for winget)
#>

# ============================================================================
# ADMINISTRATOR CHECK
# ============================================================================
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "        Windows Software Installation Script                   " -ForegroundColor Cyan
Write-Host "        MUST BE RUN AS ADMINISTRATOR                           " -ForegroundColor Yellow
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script is NOT running as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run this script as Administrator:" -ForegroundColor Yellow
    Write-Host "  1. Right-click on the script file" -ForegroundColor Yellow
    Write-Host "  2. Select 'Run with PowerShell'" -ForegroundColor Yellow
    Write-Host "  3. Click 'Yes' when prompted for admin access" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

Write-Host "[OK] Running as Administrator" -ForegroundColor Green
Write-Host ""

# Set error action preference
$ErrorActionPreference = 'Continue'

# Track if restart is needed
$script:needsRestart = $false

# ============================================================================
# WSL2 INSTALLATION
# ============================================================================
function Install-WSL2 {
    Write-Host "=== Checking WSL2 Status ===" -ForegroundColor Cyan
    
    try {
        # Check if WSL is already installed
        $wslStatus = wsl --status 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] WSL is already installed" -ForegroundColor Green
            
            # Check if it's WSL2
            $wslVersion = wsl --list --verbose 2>&1
            if ($wslVersion -match "Version 2" -or $wslVersion -match "WSL 2") {
                Write-Host "[OK] WSL2 is already enabled and configured" -ForegroundColor Green
                return $true
            }
        }
    }
    catch {
        Write-Host "[INFO] WSL not detected, proceeding with installation..." -ForegroundColor Cyan
    }
    
    Write-Host "[INFO] Enabling WSL and Virtual Machine Platform features..." -ForegroundColor Cyan
    
    try {
        # Enable WSL feature
        $wslFeature = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction Stop
        
        # Enable Virtual Machine Platform (required for WSL2)
        $vmFeature = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction Stop
        
        if ($wslFeature.RestartNeeded -or $vmFeature.RestartNeeded) {
            Write-Host "[WARNING] WSL features enabled, but a system restart is required" -ForegroundColor Yellow
            $script:needsRestart = $true
        }
        
        # Download and install WSL2 kernel update
        Write-Host "[INFO] Downloading WSL2 Linux kernel update..." -ForegroundColor Cyan
        $kernelUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
        $kernelInstaller = "$env:TEMP\wsl_update_x64.msi"
        
        Invoke-WebRequest -Uri $kernelUrl -OutFile $kernelInstaller -UseBasicParsing
        
        Write-Host "[INFO] Installing WSL2 kernel update..." -ForegroundColor Cyan
        Start-Process msiexec.exe -ArgumentList "/i `"$kernelInstaller`" /quiet /norestart" -Wait -NoNewWindow
        
        # Set WSL2 as default version
        Write-Host "[INFO] Setting WSL2 as default version..." -ForegroundColor Cyan
        wsl --set-default-version 2
        
        # Clean up
        Remove-Item $kernelInstaller -Force -ErrorAction SilentlyContinue
        
        Write-Host "[OK] WSL2 has been installed and configured successfully" -ForegroundColor Green
        Write-Host "[INFO] Note: You may need to restart your computer for WSL2 to work properly" -ForegroundColor Cyan
        
        return $true
    }
    catch {
        Write-Host "[WARNING] Failed to install WSL2: $_" -ForegroundColor Yellow
        Write-Host "[INFO] You can manually install WSL2 later by running: wsl --install" -ForegroundColor Cyan
        return $false
    }
}

# ============================================================================
# CHECK WINGET
# ============================================================================
function Test-WingetInstalled {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# INSTALL WINGET
# ============================================================================
function Install-Winget {
    Write-Host "[INFO] winget is not installed. Installing winget..." -ForegroundColor Cyan
    
    try {
        # Download latest winget package from GitHub
        Write-Host "[INFO] Downloading winget installer..." -ForegroundColor Cyan
        
        # Get latest release info
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $downloadUrl = ($releases.assets | Where-Object { $_.name -match "\.msixbundle$" }).browser_download_url
        
        if (-not $downloadUrl) {
            throw "Could not find winget installer package"
        }
        
        $installerPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
        
        # Download ALL required dependencies
        Write-Host "[INFO] Downloading required dependencies..." -ForegroundColor Cyan
        
        # 1. VCLibs dependency (required for both Win10 and Win11)
        $vcLibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $vcLibsPath = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Invoke-WebRequest -Uri $vcLibsUrl -OutFile $vcLibsPath -UseBasicParsing
        
        # 2. UI.Xaml dependency (required for both Win10 and Win11)
        $uiXamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
        $uiXamlPath = "$env:TEMP\Microsoft.UI.Xaml.2.8.x64.appx"
        Invoke-WebRequest -Uri $uiXamlUrl -OutFile $uiXamlPath -UseBasicParsing
        
        # 3. WindowsAppRuntime dependency (CRITICAL - required for latest winget)
        Write-Host "[INFO] Downloading Windows App Runtime..." -ForegroundColor Cyan
        $appRuntimeUrl = "https://aka.ms/windowsappsdk/1.8/latest/windowsappruntimeinstall-x64.exe"
        $appRuntimePath = "$env:TEMP\WindowsAppRuntimeInstall.exe"
        Invoke-WebRequest -Uri $appRuntimeUrl -OutFile $appRuntimePath -UseBasicParsing
        
        # Install WindowsAppRuntime first (required dependency)
        Write-Host "[INFO] Installing Windows App Runtime..." -ForegroundColor Cyan
        Start-Process -FilePath $appRuntimePath -ArgumentList "--quiet" -Wait -NoNewWindow
        
        # Install VCLibs dependency
        Write-Host "[INFO] Installing VCLibs..." -ForegroundColor Cyan
        Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue
        
        # Install UI.Xaml dependency
        Write-Host "[INFO] Installing UI.Xaml..." -ForegroundColor Cyan
        Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue
        
        # Install winget
        Write-Host "[INFO] Installing winget (App Installer)..." -ForegroundColor Cyan
        Add-AppxPackage -Path $installerPath
        
        # Clean up
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        Remove-Item $vcLibsPath -Force -ErrorAction SilentlyContinue
        Remove-Item $uiXamlPath -Force -ErrorAction SilentlyContinue
        Remove-Item $appRuntimePath -Force -ErrorAction SilentlyContinue
        
        Write-Host "[OK] winget has been installed successfully" -ForegroundColor Green
        Write-Host "[INFO] Please close and reopen PowerShell, then run this script again" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 0
    }
    catch {
        Write-Host "[ERROR] Failed to install winget: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install winget manually:" -ForegroundColor Yellow
        Write-Host "1. Open Microsoft Store" -ForegroundColor Yellow
        Write-Host "2. Search for 'App Installer'" -ForegroundColor Yellow
        Write-Host "3. Install or Update it" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Or download from: https://github.com/microsoft/winget-cli/releases" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

# ============================================================================
# INSTALL PACKAGE
# ============================================================================
function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$Name
    )
    
    Write-Host "[INFO] Installing $Name..." -ForegroundColor Cyan
    try {
        winget install --id $PackageId --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $Name installed successfully" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "[WARNING] $Name installation completed with warnings" -ForegroundColor Yellow
            return $true
        }
    }
    catch {
        Write-Host "[ERROR] Failed to install $Name : $_" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================
Write-Host "=== Starting Software Installation ===" -ForegroundColor Cyan
Write-Host "This may take 30-60 minutes depending on your internet connection" -ForegroundColor Cyan
Write-Host ""

# Check for winget
if (-not (Test-WingetInstalled)) {
    Install-Winget
    # After installing winget, the script will exit and user needs to restart PowerShell
}

# Install/Enable WSL2 (required for Docker Desktop)
Write-Host ""
Install-WSL2
Write-Host ""

# Update winget sources
Write-Host "[INFO] Updating winget sources..." -ForegroundColor Cyan
winget source update

# Define software packages
$packages = @(
    @{Id = "RARLab.WinRAR"; Name = "WinRAR"},
    @{Id = "7zip.7zip"; Name = "7-Zip"},
    @{Id = "Git.Git"; Name = "Git for Windows"},
    @{Id = "Google.Chrome"; Name = "Google Chrome"},
    @{Id = "Brave.Brave"; Name = "Brave Browser"},
    @{Id = "Mozilla.Firefox"; Name = "Mozilla Firefox"},
    @{Id = "OpenJS.NodeJS"; Name = "Node.js LTS"},
    @{Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal"},
    @{Id = "JetBrains.Toolbox"; Name = "JetBrains Toolbox"},
    @{Id = "VideoLAN.VLC"; Name = "VLC Media Player"},
    @{Id = "Discord.Discord"; Name = "Discord"},
    @{Id = "Postman.Postman"; Name = "Postman"},
    @{Id = "WinSCP.WinSCP"; Name = "WinSCP"},
    @{Id = "PuTTY.PuTTY"; Name = "PuTTY"},
    @{Id = "qBittorrent.qBittorrent"; Name = "qBittorrent"},
    @{Id = "PeterPawlowski.foobar2000"; Name = "foobar2000"},
    @{Id = "Docker.DockerDesktop"; Name = "Docker Desktop"},
    @{Id = "Rakuten.Viber"; Name = "Viber"},
    @{Id = "WhatsApp.WhatsApp"; Name = "WhatsApp Desktop"},
    @{Id = "SublimeHQ.SublimeText.4"; Name = "Sublime Text 4"},
    @{Id = "Valve.Steam"; Name = "Steam"}
)

# Install each package
$successCount = 0
$failCount = 0

foreach ($package in $packages) {
    if (Install-WingetPackage -PackageId $package.Id -Name $package.Name) {
        $successCount++
    }
    else {
        $failCount++
    }
    Write-Host "" # Blank line for readability
}

# Install Visual Studio Community (Note: 2026 does not exist yet, using 2022)
Write-Host "[WARNING] Note: Visual Studio Community 2026 does not exist yet. Installing Visual Studio Community 2022..." -ForegroundColor Yellow
if (Install-WingetPackage -PackageId "Microsoft.VisualStudio.2022.Community" -Name "Visual Studio Community 2022") {
    $successCount++
}
else {
    $failCount++
}

# Install PHP
Write-Host "[INFO] Installing PHP..." -ForegroundColor Cyan
Write-Host "[INFO] Downloading latest PHP..." -ForegroundColor Cyan

try {
    # Create PHP directory
    $phpDir = "C:\php"
    if (-not (Test-Path $phpDir)) {
        New-Item -ItemType Directory -Path $phpDir -Force | Out-Null
    }

    # Download PHP (latest stable)
    $phpUrl = "https://windows.php.net/downloads/releases/latest/php-8.3-nts-Win32-vs16-x64-latest.zip"
    $phpZip = "$env:TEMP\php.zip"
    
    Invoke-WebRequest -Uri $phpUrl -OutFile $phpZip -UseBasicParsing
    
    # Extract PHP
    Expand-Archive -Path $phpZip -DestinationPath $phpDir -Force
    
    # Add PHP to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$phpDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$phpDir", "Machine")
        Write-Host "[OK] PHP installed and added to PATH at $phpDir" -ForegroundColor Green
        $successCount++
    }
    
    # Clean up
    Remove-Item $phpZip -Force
}
catch {
    Write-Host "[ERROR] Failed to install PHP: $_" -ForegroundColor Red
    $failCount++
}

Write-Host ""

# Install JetBrains IDEs directly
Write-Host "=== Installing JetBrains IDEs ===" -ForegroundColor Cyan
Write-Host "[INFO] Installing IDEs directly (JetBrains Toolbox is also installed for manual management)" -ForegroundColor Cyan
Write-Host ""

$jetbrainsIDEs = @(
    @{Id = "JetBrains.WebStorm"; Name = "WebStorm"},
    @{Id = "JetBrains.PHPStorm"; Name = "PhpStorm"},
    @{Id = "JetBrains.Rider"; Name = "Rider"},
    @{Id = "JetBrains.RustRover"; Name = "RustRover"},
    @{Id = "JetBrains.CLion"; Name = "CLion"},
    @{Id = "JetBrains.DataGrip"; Name = "DataGrip"}
)

foreach ($ide in $jetbrainsIDEs) {
    if (Install-WingetPackage -PackageId $ide.Id -Name $ide.Name) {
        $successCount++
    }
    else {
        $failCount++
    }
    Write-Host ""
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "=== Installation Summary ===" -ForegroundColor Cyan
Write-Host "[OK] Successfully installed: $successCount packages" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "[WARNING] Failed installations: $failCount packages" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "IMPORTANT NOTES:" -ForegroundColor Cyan
if ($script:needsRestart) {
    Write-Host "[WARNING] SYSTEM RESTART REQUIRED for WSL2 to function properly" -ForegroundColor Yellow
    Write-Host ""
}
Write-Host "1. WSL2 has been installed/enabled (required for Docker Desktop)" -ForegroundColor White
Write-Host "2. Some applications may require a system restart to function properly" -ForegroundColor White
Write-Host "3. PHP has been installed to C:\php and added to PATH" -ForegroundColor White
Write-Host "4. You may need to restart your terminal/PowerShell to use updated PATH" -ForegroundColor White
Write-Host "5. JetBrains IDEs require activation/licensing" -ForegroundColor White
Write-Host "6. JetBrains Toolbox is installed and can be used to manage IDE updates" -ForegroundColor White
Write-Host ""

if ($script:needsRestart) {
    Write-Host "===============================================================" -ForegroundColor Yellow
    Write-Host "  PLEASE RESTART YOUR COMPUTER NOW" -ForegroundColor Yellow
    Write-Host "  WSL2 and some applications require a restart to work" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "[OK] Installation process complete!" -ForegroundColor Green
