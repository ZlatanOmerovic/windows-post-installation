# Windows Software Installation Script

Automated PowerShell script to download and install the latest versions of common development tools and applications silently.

## Prerequisites

1. **Windows 10 (version 1809 or later) or Windows 11**
2. **Administrator privileges**
3. **Winget (Windows Package Manager)** - Usually pre-installed on Windows 10/11
   - If not installed, get it from Microsoft Store: "App Installer"
4. **Internet connection**

## Included Software

### Development Tools
- Git for Windows (includes Git Bash)
- Node.js (LTS version)
- PHP 8.3 CLI (added to PATH automatically)
- Visual Studio Community 2022
- Windows Terminal
- Postman
- Docker Desktop

### Web Browsers
- Google Chrome
- Brave Browser
- Mozilla Firefox

### JetBrains IDEs
- JetBrains Toolbox (for manual IDE management)
- WebStorm
- PhpStorm
- Rider
- RustRover
- CLion
- DataGrip

### Utilities
- WinRAR
- 7-Zip
- WinSCP
- PuTTY (full installer)
- qBittorrent

### Media & Communication
- VLC Media Player
- foobar2000
- Discord
- Viber
- WhatsApp Desktop

### Text Editors
- Sublime Text 4

### Gaming
- Steam

## How to Use

### Method 1: Run Directly (Recommended)

1. **Right-click** on `install-software.ps1`
2. Select **"Run with PowerShell"**
3. If prompted, click **"Yes"** to allow administrator access
4. Wait for the installation to complete (30-60 minutes depending on internet speed)

### Method 2: Run from PowerShell

1. Open **PowerShell** as **Administrator**:
   - Press `Win + X`
   - Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

2. Navigate to the script location:
   ```powershell
   cd C:\path\to\script\folder
   ```

3. If this is your first time running PowerShell scripts, you may need to allow script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. Run the script:
   ```powershell
   .\install-software.ps1
   ```

## What Happens During Installation

1. **Checks for winget** - Verifies Windows Package Manager is available
2. **Updates package sources** - Ensures latest package information
3. **Installs packages sequentially** - Shows progress for each application
4. **PHP special handling** - Downloads PHP, extracts to C:\php, adds to PATH
5. **JetBrains IDEs** - Installs each IDE directly (faster and more reliable than Toolbox automation)
6. **Summary report** - Shows successful and failed installations

## Important Notes

### After Installation

1. **Restart required**: Some applications (especially Docker, PHP, Git) may require a system restart
2. **Terminal restart**: You'll need to restart your terminal/PowerShell to use newly installed CLI tools
3. **Docker setup**: Docker Desktop requires WSL2. If not installed, you'll need to enable it:
   ```powershell
   wsl --install
   ```
4. **JetBrains licensing**: All JetBrains IDEs require activation (trial or paid license)
5. **PHP location**: C:\php (already added to PATH)

### Customization

To modify which software gets installed:

1. Open `install-software.ps1` in a text editor
2. Find the `$packages` array (around line 75)
3. Comment out (add `#` at the start) or remove packages you don't want
4. Save and run

Example:
```powershell
# @{Id = "Discord.Discord"; Name = "Discord"},  # Commented out - won't install
```

## Troubleshooting

### "winget is not installed"
- Install "App Installer" from Microsoft Store
- Or update Windows to the latest version

### "Installation failed" for specific packages
- Check your internet connection
- Some packages may be temporarily unavailable
- Try running the script again - it will skip already-installed packages

### "Execution policy" error
Run this command in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker won't start
1. Enable WSL2:
   ```powershell
   wsl --install
   ```
2. Restart your computer
3. Start Docker Desktop

### PHP not found in command line
1. Restart your terminal
2. Or manually add to PATH:
   ```powershell
   $env:Path += ";C:\php"
   ```

## Manual Installation Alternative

If you prefer to install packages one-by-one manually:

```powershell
# Example: Install just Chrome
winget install --id Google.Chrome

# Example: Install just Node.js
winget install --id OpenJS.NodeJS
```

## Uninstalling Software

To uninstall any package installed by this script:

```powershell
# Method 1: Using winget
winget uninstall "Application Name"

# Method 2: Using Windows Settings
# Settings > Apps > Installed apps > Find app > Uninstall
```

## Time Estimates

- **Fast internet (100+ Mbps)**: ~30-40 minutes
- **Medium internet (50 Mbps)**: ~45-60 minutes  
- **Slow internet (<25 Mbps)**: ~60-90 minutes

Visual Studio Community and Docker Desktop are the largest downloads.

## Security Considerations

- All software is downloaded from official sources via winget
- Winget verifies package signatures automatically
- Script requires Administrator privileges (necessary for software installation)
- Review the script before running if you have security concerns

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify you're running as Administrator
3. Ensure your Windows is up to date
4. Check that winget is properly installed

## License

This script is provided as-is. Individual software packages have their own licenses.

## Notes on Specific Software

### Visual Studio Community 2026
Note: This version doesn't exist yet. The script installs Visual Studio Community 2022 instead. When 2026 is released, update the package ID in the script.

### JetBrains Toolbox vs Direct IDE Installation
The script installs JetBrains IDEs directly rather than through Toolbox automation because:
- Direct installation is more reliable and scriptable
- Toolbox is primarily a GUI tool without robust CLI automation
- You can still use Toolbox after installation to manage updates and settings
- All IDEs will appear in Toolbox automatically once it's launched

### WinRAR
WinRAR is commercial software with a trial period. Consider using the free 7-Zip as an alternative.
