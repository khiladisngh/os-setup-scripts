# ============================================================================
# Windows Development Environment Setup Script
# ============================================================================
#
# Description: Complete installation and configuration script for a modern
#              development environment on Windows with PowerShell.
#
# Author:      Gishant
# Version:     1.0
# Date:        July 2025
#
# Features:
# - Colorful verbose logging with progress indicators.
# - Interactive prompts for user choices.
# - Proper installation order and dependency management.
# - Comprehensive error handling.
# - Modular design with categorized installations.
# - Detailed documentation and comments.
# - Creates a backup of existing configuration files.
#
# Usage: .\setup-windows.ps1
#
# Prerequisites:
# - Windows 10/11 with PowerShell 5.1+ or PowerShell Core 7+
# - Administrator privileges for some installations
# - An active internet connection
# - At least 10GB of free disk space is recommended
#
# ============================================================================

#Requires -Version 5.1

# --- Script Configuration ---
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# --- Global Variables ---
$script:TotalSteps = 16
$script:CurrentStep = 0
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:LogFile = Join-Path $ScriptDir "windows_setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:BackupDir = Join-Path $env:USERPROFILE ".config_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Enhanced logging function with timestamps and log levels
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'PROGRESS', 'HEADER')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp [$Level] $Message"
    
    switch ($Level) {
        'INFO' { 
            Write-Host "[$Level] $timestamp`: $Message" -ForegroundColor Blue
        }
        'SUCCESS' { 
            Write-Host "[$Level] $timestamp`: $Message" -ForegroundColor Green
        }
        'WARNING' { 
            Write-Host "[$Level] $timestamp`: $Message" -ForegroundColor Yellow
        }
        'ERROR' { 
            Write-Host "[$Level] $timestamp`: $Message" -ForegroundColor Red
        }
        'PROGRESS' { 
            Write-Host "[$Level] $timestamp`: $Message" -ForegroundColor Magenta
        }
        'HEADER' {
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║ $Message" -ForegroundColor Cyan
            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    
    # Write to log file
    $logEntry | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
}

# Progress bar function
function Show-Progress {
    param(
        [int]$Current,
        [int]$Total
    )
    
    $percentage = [math]::Round(($Current / $Total) * 100)
    Write-Progress -Activity "Windows Development Environment Setup" -Status "Step $Current of $Total" -PercentComplete $percentage
}

# Step progress function
function Step-Next {
    $script:CurrentStep++
    Show-Progress -Current $script:CurrentStep -Total $script:TotalSteps
}

# Interactive confirmation function
function Confirm-Action {
    param(
        [string]$Message,
        [string]$Default = 'N'
    )
    
    $prompt = if ($Default -eq 'Y') { " (Y/n): " } else { " (y/N): " }
    
    do {
        $response = Read-Host "$Message$prompt"
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $Default
        }
        
        switch ($response.ToUpper()) {
            'Y' { return $true }
            'YES' { return $true }
            'N' { return $false }
            'NO' { return $false }
            default { Write-Host "Please answer yes or no." -ForegroundColor Red }
        }
    } while ($true)
}

# Check if a command exists
function Test-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Create backup directory
function New-BackupDirectory {
    Write-Log -Level INFO -Message "Creating backup directory at $script:BackupDir"
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
}

# Backup a file if it exists
function Backup-File {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        Write-Log -Level INFO -Message "Backing up $FilePath to $script:BackupDir"
        Copy-Item -Path $FilePath -Destination $script:BackupDir -Force
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Install package via winget
function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$PackageName = $PackageId
    )
    
    Write-Log -Level INFO -Message "Installing $PackageName via winget..."
    try {
        $result = winget install --id $PackageId --silent --accept-source-agreements --accept-package-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Level SUCCESS -Message "$PackageName installed successfully"
        }
        elseif ($result -match "already installed") {
            Write-Log -Level INFO -Message "$PackageName is already installed"
        }
        else {
            Write-Log -Level WARNING -Message "winget returned exit code $LASTEXITCODE for $PackageName"
            Write-Log -Level INFO -Message "Output: $result"
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to install $PackageName`: $($_.Exception.Message)"
        throw
    }
}

# Install package via Chocolatey
function Install-ChocolateyPackage {
    param(
        [string]$PackageName
    )
    
    Write-Log -Level INFO -Message "Installing $PackageName via Chocolatey..."
    try {
        choco install $PackageName -y
        Write-Log -Level SUCCESS -Message "$PackageName installed successfully"
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to install $PackageName`: $($_.Exception.Message)"
        throw
    }
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# 1. Check Requirements
function Test-Requirements {
    Write-Log -Level HEADER -Message "STEP 1/16: CHECKING SYSTEM REQUIREMENTS"
    
    # Check Windows version
    $osInfo = Get-ComputerInfo
    $windowsVersion = $osInfo.WindowsVersion
    Write-Log -Level INFO -Message "Windows Version: $windowsVersion"
    
    if ($windowsVersion -lt 1909) {
        Write-Log -Level WARNING -Message "This script is optimized for Windows 10 version 1909 or later"
        if (-not (Confirm-Action -Message "Continue anyway?")) {
            exit 1
        }
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Log -Level INFO -Message "PowerShell Version: $psVersion"
    
    # Check internet connection
    Write-Log -Level INFO -Message "Checking internet connection..."
    try {
        Test-NetConnection -ComputerName "google.com" -Port 80 -InformationLevel Quiet | Out-Null
        Write-Log -Level SUCCESS -Message "Internet connection verified"
    }
    catch {
        Write-Log -Level ERROR -Message "No internet connection detected. Please connect to the internet and try again."
        exit 1
    }
    
    # Check available disk space
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB
    Write-Log -Level INFO -Message "Available disk space: $([math]::Round($freeSpace, 2)) GB"
    
    if ($freeSpace -lt 10) {
        Write-Log -Level WARNING -Message "Less than 10GB of free space available"
        if (-not (Confirm-Action -Message "Continue anyway?")) {
            exit 1
        }
    }
    
    Write-Log -Level SUCCESS -Message "System requirements check passed"
    Step-Next
}

# 2. Install Package Managers
function Install-PackageManagers {
    Write-Log -Level HEADER -Message "STEP 2/16: PACKAGE MANAGERS"
    
    # Install/Update winget if needed
    if (-not (Test-Command 'winget')) {
        Write-Log -Level INFO -Message "Installing winget..."
        try {
            # Download and install App Installer from Microsoft Store
            Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
            Write-Log -Level INFO -Message "Please complete winget installation manually and re-run this script"
            exit 0
        }
        catch {
            Write-Log -Level ERROR -Message "Failed to install winget. Please install manually from Microsoft Store."
            exit 1
        }
    }
    else {
        Write-Log -Level INFO -Message "winget is already installed"
    }
    
    # Install Chocolatey
    if (-not (Test-Command 'choco')) {
        Write-Log -Level INFO -Message "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log -Level SUCCESS -Message "Chocolatey installed successfully"
    }
    else {
        Write-Log -Level INFO -Message "Chocolatey is already installed"
    }
    
    # Install Scoop
    if (-not (Test-Command 'scoop')) {
        Write-Log -Level INFO -Message "Installing Scoop..."
        try {
            # Ensure proper execution policy
            $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
            if ($currentPolicy -eq 'Restricted') {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            }
            
            # Enable TLS 1.2 for the download
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            
            # Install Scoop
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            Write-Log -Level SUCCESS -Message "Scoop installed successfully"
        }
        catch {
            Write-Log -Level WARNING -Message "Failed to install Scoop: $($_.Exception.Message)"
            Write-Log -Level INFO -Message "You can install Scoop manually later by running: iex (irm get.scoop.sh)"
        }
    }
    else {
        Write-Log -Level INFO -Message "Scoop is already installed"
    }
    
    Step-Next
}

# 3. Install PowerShell 7
function Install-PowerShell7 {
    Write-Log -Level HEADER -Message "STEP 3/16: POWERSHELL 7"
    
    if (Test-Command 'pwsh') {
        Write-Log -Level INFO -Message "PowerShell 7 is already installed"
    }
    else {
        Write-Log -Level INFO -Message "Installing PowerShell 7..."
        Install-WingetPackage -PackageId "Microsoft.PowerShell" -PackageName "PowerShell 7"
    }
    
    Step-Next
}

# 4. Install Oh My Posh and Configure PowerShell
function Install-OhMyPosh {
    Write-Log -Level HEADER -Message "STEP 4/16: OH MY POSH & POWERSHELL CONFIGURATION"
    
    # Install Oh My Posh
    if (-not (Test-Command 'oh-my-posh')) {
        Write-Log -Level INFO -Message "Installing Oh My Posh..."
        Install-WingetPackage -PackageId "JanDeDobbeleer.OhMyPosh" -PackageName "Oh My Posh"
    }
    else {
        Write-Log -Level INFO -Message "Oh My Posh is already installed"
    }
    
    # Install PowerShell modules
    Write-Log -Level INFO -Message "Installing PowerShell modules..."
    $modules = @(
        'PSReadLine',
        'Terminal-Icons',
        'z',
        'PSFzf',
        'posh-git'
    )
    
    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Log -Level INFO -Message "Installing module: $module"
            Install-Module -Name $module -Force -Scope CurrentUser
        }
        else {
            Write-Log -Level INFO -Message "Module $module is already installed"
        }
    }
    
    # Create PowerShell profile
    Write-Log -Level INFO -Message "Configuring PowerShell profile..."
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path -Parent $profilePath
    
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    Backup-File -FilePath $profilePath
    
    $profileContent = @'
# PowerShell Profile Configuration
# Generated by Windows Development Environment Setup Script

# Import Modules
Import-Module Terminal-Icons
Import-Module z
Import-Module PSFzf
Import-Module posh-git

# PSReadLine Configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key Ctrl+d -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Oh My Posh Configuration
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\robbyrussell.omp.json" | Invoke-Expression

# PSFzf Configuration
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

# Environment Variables
$env:EDITOR = 'code'  # or 'notepad', 'vim', etc.

# Custom Functions
function ll { Get-ChildItem -Force }
function la { Get-ChildItem -Force -Hidden }
function which($command) { Get-Command -Name $command -ErrorAction SilentlyContinue }
function mkcd($dir) { New-Item -ItemType Directory -Path $dir -Force; Set-Location $dir }
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }

# Git Aliases
function gs { git status }
function ga { git add $args }
function gc { git commit -m $args }
function gp { git push }
function gpl { git pull }
function gd { git diff }
function gl { git log --oneline --graph --decorate }
function gco { git checkout $args }
function gcb { git checkout -b $args }

# Load custom aliases if they exist
if (Test-Path "$env:USERPROFILE\.aliases.ps1") {
    . "$env:USERPROFILE\.aliases.ps1"
}
'@
    
    $profileContent | Out-File -FilePath $profilePath -Encoding UTF8 -Force
    Write-Log -Level SUCCESS -Message "PowerShell profile configured"
    
    Step-Next
}

# 5. Install Development Tools
function Install-DevelopmentTools {
    Write-Log -Level HEADER -Message "STEP 5/16: DEVELOPMENT TOOLS"
    
    # Install Git
    if (-not (Test-Command 'git')) {
        Install-WingetPackage -PackageId "Git.Git" -PackageName "Git"
    }
    else {
        Write-Log -Level INFO -Message "Git is already installed"
    }
    
    # Install GitHub CLI
    if (-not (Test-Command 'gh')) {
        Install-WingetPackage -PackageId "GitHub.cli" -PackageName "GitHub CLI"
    }
    else {
        Write-Log -Level INFO -Message "GitHub CLI is already installed"
    }
    
    # Install Visual Studio Code
    if (-not (Test-Command 'code')) {
        Install-WingetPackage -PackageId "Microsoft.VisualStudioCode" -PackageName "Visual Studio Code"
    }
    else {
        Write-Log -Level INFO -Message "Visual Studio Code is already installed"
    }
    
    Step-Next
}

# 6. Install Python Development Tools
function Install-PythonTools {
    Write-Log -Level HEADER -Message "STEP 6/16: PYTHON DEVELOPMENT TOOLS"
    
    # Install Python
    if (-not (Test-Command 'python')) {
        Install-WingetPackage -PackageId "Python.Python.3.12" -PackageName "Python 3.12"
    }
    else {
        Write-Log -Level INFO -Message "Python is already installed"
    }
    
    # Refresh environment variables
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Install Poetry
    if (-not (Test-Command 'poetry')) {
        Write-Log -Level INFO -Message "Installing Poetry..."
        try {
            (Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | python -
            Write-Log -Level SUCCESS -Message "Poetry installed successfully"
        }
        catch {
            Write-Log -Level WARNING -Message "Failed to install Poetry: $($_.Exception.Message)"
            Write-Log -Level INFO -Message "Continuing without Poetry..."
        }
    }
    else {
        Write-Log -Level INFO -Message "Poetry is already installed"
    }
    
    # Install uv
    if (-not (Test-Command 'uv')) {
        Write-Log -Level INFO -Message "Installing uv..."
        try {
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
            Write-Log -Level SUCCESS -Message "uv installed successfully"
        }
        catch {
            Write-Log -Level WARNING -Message "Failed to install uv: $($_.Exception.Message)"
            Write-Log -Level INFO -Message "Continuing without uv..."
        }
    }
    else {
        Write-Log -Level INFO -Message "uv is already installed"
    }
    
    Step-Next
}

# 7. Install Rust Development Environment
function Install-Rust {
    Write-Log -Level HEADER -Message "STEP 7/16: RUST DEVELOPMENT ENVIRONMENT"
    
    if (Test-Command 'rustc') {
        Write-Log -Level INFO -Message "Rust is already installed. Updating..."
        rustup update
    }
    else {
        Write-Log -Level INFO -Message "Installing Rust..."
        # Download and run rustup-init.exe
        $rustupPath = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest -Uri "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" -OutFile $rustupPath
        Start-Process -FilePath $rustupPath -ArgumentList "-y" -Wait
        Remove-Item $rustupPath
    }
    
    # Refresh environment variables
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    Write-Log -Level INFO -Message "Installing essential Rust components..."
    try {
        rustup component add rustfmt clippy rust-analyzer
        Write-Log -Level SUCCESS -Message "Rust components installed successfully"
    }
    catch {
        Write-Log -Level WARNING -Message "Failed to install some Rust components: $($_.Exception.Message)"
    }
    
    Step-Next
}

# 8. Install Go Development Environment
function Install-Go {
    Write-Log -Level HEADER -Message "STEP 8/16: GO DEVELOPMENT ENVIRONMENT"
    
    if (-not (Test-Command 'go')) {
        Install-WingetPackage -PackageId "GoLang.Go" -PackageName "Go"
    }
    else {
        Write-Log -Level INFO -Message "Go is already installed"
    }
    
    # Create Go workspace
    $goPath = "$env:USERPROFILE\go"
    if (-not (Test-Path $goPath)) {
        Write-Log -Level INFO -Message "Creating Go workspace at $goPath"
        New-Item -ItemType Directory -Path $goPath -Force | Out-Null
    }
    
    Step-Next
}

# 9. Install Node.js Development Environment
function Install-NodeJS {
    Write-Log -Level HEADER -Message "STEP 9/16: NODE.JS DEVELOPMENT ENVIRONMENT"
    
    if (-not (Test-Command 'node')) {
        Install-WingetPackage -PackageId "OpenJS.NodeJS" -PackageName "Node.js"
    }
    else {
        Write-Log -Level INFO -Message "Node.js is already installed"
    }
    
    # Refresh environment variables to pick up Node.js
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Install global npm packages
    if (Test-Command 'npm') {
        Write-Log -Level INFO -Message "Installing global npm packages..."
        $npmPackages = @(
            'typescript',
            'ts-node',
            '@types/node',
            'npm-check-updates',
            'nodemon'
        )
        
        foreach ($package in $npmPackages) {
            try {
                Write-Log -Level INFO -Message "Installing npm package: $package"
                npm install -g $package
                Write-Log -Level SUCCESS -Message "$package installed successfully"
            }
            catch {
                Write-Log -Level WARNING -Message "Failed to install $package`: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Log -Level WARNING -Message "npm command not found. Please restart PowerShell and install packages manually."
    }
    
    Step-Next
}

# 10. Install Modern CLI Tools
function Install-ModernCLITools {
    Write-Log -Level HEADER -Message "STEP 10/16: MODERN CLI TOOLS"
    
    # Install via winget
    $wingetTools = @(
        @{ Id = "BurntSushi.ripgrep.MSVC"; Name = "ripgrep" },
        @{ Id = "sharkdp.bat"; Name = "bat" },
        @{ Id = "sharkdp.fd"; Name = "fd" },
        @{ Id = "junegunn.fzf"; Name = "fzf" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "eza-community.eza"; Name = "eza" },
        @{ Id = "Clement.bottom"; Name = "bottom" },
        @{ Id = "dalance.procs"; Name = "procs" },
        @{ Id = "sharkdp.hexyl"; Name = "hexyl" },
        @{ Id = "dandavison.delta"; Name = "delta" }
    )
    
    foreach ($tool in $wingetTools) {
        if (-not (Test-Command $tool.Name)) {
            Install-WingetPackage -PackageId $tool.Id -PackageName $tool.Name
        }
        else {
            Write-Log -Level INFO -Message "$($tool.Name) is already installed"
        }
    }
    
    Step-Next
}

# 11. Install Container Tools
function Install-ContainerTools {
    Write-Log -Level HEADER -Message "STEP 11/16: CONTAINER TOOLS"
    
    if (-not (Confirm-Action -Message "Install Docker Desktop?")) {
        Write-Log -Level INFO -Message "Skipping container tools installation"
        Step-Next
        return
    }
    
    # Install Docker Desktop
    if (-not (Test-Command 'docker')) {
        Install-WingetPackage -PackageId "Docker.DockerDesktop" -PackageName "Docker Desktop"
        Write-Log -Level WARNING -Message "Docker Desktop requires a system restart to complete installation"
    }
    else {
        Write-Log -Level INFO -Message "Docker Desktop is already installed"
    }
    
    Step-Next
}

# 12. Install Fonts
function Install-Fonts {
    Write-Log -Level HEADER -Message "STEP 12/16: NERD FONTS INSTALLATION"
    
    # Create fonts directory
    $fontsDir = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Fonts"
    if (-not (Test-Path $fontsDir)) {
        New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null
    }
    
    # Enable TLS 1.2 for secure downloads
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    
    # Download and install FiraCode Nerd Font
    Write-Log -Level INFO -Message "Installing FiraCode Nerd Font..."
    $firaCodeUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip"
    $firaCodeZip = "$env:TEMP\FiraCode.zip"
    
    try {
        Invoke-WebRequest -Uri $firaCodeUrl -OutFile $firaCodeZip
        Expand-Archive -Path $firaCodeZip -DestinationPath $fontsDir -Force
        Remove-Item $firaCodeZip
        Write-Log -Level SUCCESS -Message "FiraCode Nerd Font installed"
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to install FiraCode Nerd Font: $($_.Exception.Message)"
    }
    
    # Download and install JetBrainsMono Nerd Font
    Write-Log -Level INFO -Message "Installing JetBrainsMono Nerd Font..."
    $jetBrainsUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
    $jetBrainsZip = "$env:TEMP\JetBrainsMono.zip"
    
    try {
        Invoke-WebRequest -Uri $jetBrainsUrl -OutFile $jetBrainsZip
        Expand-Archive -Path $jetBrainsZip -DestinationPath $fontsDir -Force
        Remove-Item $jetBrainsZip
        Write-Log -Level SUCCESS -Message "JetBrainsMono Nerd Font installed"
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to install JetBrainsMono Nerd Font: $($_.Exception.Message)"
    }
    
    Write-Log -Level INFO -Message "You may need to set the font in your terminal settings"
    Step-Next
}

# 13. Install Windows Terminal
function Install-WindowsTerminal {
    Write-Log -Level HEADER -Message "STEP 13/16: WINDOWS TERMINAL"
    
    if (-not (Get-AppxPackage -Name "Microsoft.WindowsTerminal")) {
        Install-WingetPackage -PackageId "Microsoft.WindowsTerminal" -PackageName "Windows Terminal"
    }
    else {
        Write-Log -Level INFO -Message "Windows Terminal is already installed"
    }
    
    # Configure Windows Terminal
    $terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $terminalSettingsPath) {
        Backup-File -FilePath $terminalSettingsPath
        Write-Log -Level INFO -Message "Windows Terminal settings backed up"
    }
    
    Step-Next
}

# 14. Install WSL2
function Install-WSL2 {
    Write-Log -Level HEADER -Message "STEP 14/16: WSL2 INSTALLATION"
    
    if (-not (Confirm-Action -Message "Install WSL2 with Ubuntu?")) {
        Write-Log -Level INFO -Message "Skipping WSL2 installation"
        Step-Next
        return
    }
    
    # Check if WSL is already installed
    if (Test-Command 'wsl') {
        Write-Log -Level INFO -Message "WSL is already installed"
    }
    else {
        Write-Log -Level INFO -Message "Installing WSL2..."
        if (Test-Administrator) {
            # Enable WSL and Virtual Machine Platform
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All
            
            # Download and install WSL2 kernel update
            $wslKernelUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
            $wslKernelMsi = "$env:TEMP\wsl_update_x64.msi"
            Invoke-WebRequest -Uri $wslKernelUrl -OutFile $wslKernelMsi
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $wslKernelMsi, "/quiet" -Wait
            Remove-Item $wslKernelMsi
            
            # Set WSL2 as default
            wsl --set-default-version 2
            
            # Install Ubuntu
            Install-WingetPackage -PackageId "Canonical.Ubuntu" -PackageName "Ubuntu"
            
            Write-Log -Level WARNING -Message "A system restart is required to complete WSL2 installation"
        }
        else {
            Write-Log -Level ERROR -Message "Administrator privileges required for WSL2 installation"
        }
    }
    
    Step-Next
}

# 15. Create Aliases File
function New-AliasesFile {
    Write-Log -Level HEADER -Message "STEP 15/16: CREATING ALIASES FILE"
    
    $aliasesPath = "$env:USERPROFILE\.aliases.ps1"
    Write-Log -Level INFO -Message "Creating comprehensive aliases file at $aliasesPath"
    Backup-File -FilePath $aliasesPath
    
    $aliasesContent = @'
# ============================================================================
# Comprehensive Aliases for Windows Development Environment
# Source this file from your PowerShell profile: `. "$env:USERPROFILE\.aliases.ps1"`
# ============================================================================

# --- Navigation & File Management ---
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ll { Get-ChildItem -Force }
function la { Get-ChildItem -Force -Hidden }
function ls { if (Test-Command 'eza') { eza --icons } else { Get-ChildItem } }
function tree { if (Test-Command 'eza') { eza --tree } else { tree } }
function cat { if (Test-Command 'bat') { bat --paging=never --style=plain $args } else { Get-Content $args } }
function grep { if (Test-Command 'rg') { rg $args } else { Select-String $args } }
function find { if (Test-Command 'fd') { fd $args } else { Get-ChildItem -Recurse -Name $args } }
function top { if (Test-Command 'btm') { btm } else { tasklist } }
function ps { if (Test-Command 'procs') { procs } else { Get-Process } }

# --- System & Package Management ---
function update { winget upgrade --all }
function install { winget install $args }
function search { winget search $args }

# --- Git ---
function g { git $args }
function gs { git status -s }
function ga { git add $args }
function gaa { git add -A }
function gc { git commit -m $args }
function gca { git commit --amend --no-edit }
function gp { git push }
function gpf { git push --force-with-lease }
function gpl { git pull }
function gd { if (Test-Command 'delta') { git diff | delta } else { git diff } }
function gl { git log --oneline --graph --decorate }
function gco { git checkout $args }
function gcb { git checkout -b $args }
function gbr { git branch }
function gcl { git clone $args }
function gsta { git stash }
function gstp { git stash pop }

# --- Docker ---
function dps { docker ps }
function dpsa { docker ps -a }
function di { docker images }
function dlogs { docker logs -f $args }
function dexec { docker exec -it $args }
function dcup { docker-compose up -d }
function dcdown { docker-compose down }

# --- Python ---
function py { python $args }
function po { poetry $args }
function poa { poetry add $args }
function por { poetry remove $args }
function poi { poetry install }
function pou { poetry update }
function porun { poetry run $args }
function poshell { poetry shell }

# --- Rust ---
function cc { cargo check }
function cb { cargo build }
function cbr { cargo build --release }
function cr { cargo run }
function ct { cargo test }
function cl { cargo clippy }
function cfmt { cargo fmt }

# --- Go ---
function gr { go run $args }
function gb { go build $args }
function gt { go test ./... }
function gti { go mod tidy }

# --- Node.js ---
function nr { npm run $args }
function ni { npm install $args }
function nig { npm install -g $args }
function nid { npm install --save-dev $args }
function nu { npm update }
function ncu { npm-check-updates }

# --- Utility Functions ---
function mkcd($dir) { 
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Location $dir 
}

function touch($file) {
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
    }
}

function which($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

function reload {
    . $PROFILE
}

function edit-profile {
    code $PROFILE
}

function edit-aliases {
    code "$env:USERPROFILE\.aliases.ps1"
}

# Get public IP
function Get-PublicIP {
    try {
        (Invoke-WebRequest -Uri "http://ifconfig.me/ip" -UseBasicParsing).Content.Trim()
    }
    catch {
        "Unable to retrieve public IP"
    }
}

# Start a simple HTTP server
function Start-HttpServer {
    param([int]$Port = 8000)
    
    if (Test-Command 'python') {
        python -m http.server $Port
    }
    else {
        Write-Host "Python is required to start HTTP server" -ForegroundColor Red
    }
}

# Create and open a new temporary file
function New-TempFile {
    $tempFile = [System.IO.Path]::GetTempFileName()
    if (Test-Command 'code') {
        code $tempFile
    }
    else {
        notepad $tempFile
    }
    return $tempFile
}
'@
    
    $aliasesContent | Out-File -FilePath $aliasesPath -Encoding UTF8 -Force
    Write-Log -Level SUCCESS -Message "Comprehensive aliases file created at $aliasesPath"
    
    Step-Next
}

# 16. Finalize Setup
function Complete-Setup {
    Write-Log -Level HEADER -Message "STEP 16/16: FINALIZING SETUP"
    
    # Configure Git to use delta for diffs
    if (Test-Command 'delta') {
        Write-Log -Level INFO -Message "Configuring Git to use delta for diffs..."
        try {
            git config --global core.pager "delta"
            git config --global interactive.diffFilter "delta --color-only"
            git config --global delta.navigate "true"
            git config --global delta.side-by-side "true"
            git config --global delta.line-numbers "true"
            Write-Log -Level SUCCESS -Message "Git configured to use delta"
        }
        catch {
            Write-Log -Level WARNING -Message "Failed to configure Git with delta: $($_.Exception.Message)"
        }
    }
    else {
        Write-Log -Level INFO -Message "Delta not found, skipping Git configuration"
    }
    
    # Refresh environment variables
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    Write-Log -Level SUCCESS -Message "All installation and configuration steps are complete!"
    Write-Host ""
    Write-Host "🎉 Windows Development Environment Setup is Finished! 🎉" -ForegroundColor Green
    Write-Host ""
    
    Write-Log -Level INFO -Message "A detailed log of this session is available at: $script:LogFile"
    
    Write-Host "IMPORTANT - PLEASE READ THE FOLLOWING:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer to ensure all changes take effect" -ForegroundColor Cyan
    Write-Host "2. Open a new PowerShell window and run '. `$PROFILE' to apply the new settings" -ForegroundColor Cyan
    Write-Host "3. Set your new Nerd Font in Windows Terminal settings" -ForegroundColor Cyan
    Write-Host "4. Authenticate with GitHub by running: 'gh auth login'" -ForegroundColor Cyan
    Write-Host "5. Review the generated ~/.aliases.ps1 file to familiarize yourself with the new shortcuts" -ForegroundColor Cyan
    Write-Host "6. If you installed WSL2, complete the Ubuntu setup by running 'wsl' in a new terminal" -ForegroundColor Cyan
    
    Step-Next
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================

function Main {
    Clear-Host
    Write-Host "Welcome to the Windows Development Environment Setup Script!" -ForegroundColor Cyan
    Write-Host "This script will install and configure a suite of modern development tools." -ForegroundColor White
    Write-Host "A log file will be created at: $script:LogFile" -ForegroundColor White
    Write-Host ""
    
    if (-not (Confirm-Action -Message "Do you want to begin the installation?" -Default 'Y')) {
        Write-Host "Installation aborted by user." -ForegroundColor Red
        exit 0
    }
    
    New-BackupDirectory
    
    # Check if running as administrator for certain operations
    if (-not (Test-Administrator)) {
        Write-Log -Level WARNING -Message "Not running as administrator. Some features may require elevation."
    }
    
    # Run Installation Steps
    try {
        Test-Requirements
        Install-PackageManagers
        Install-PowerShell7
        Install-OhMyPosh
        Install-DevelopmentTools
        Install-PythonTools
        Install-Rust
        Install-Go
        Install-NodeJS
        Install-ModernCLITools
        Install-ContainerTools
        Install-Fonts
        Install-WindowsTerminal
        Install-WSL2
        New-AliasesFile
        Complete-Setup
    }
    catch {
        Write-Log -Level ERROR -Message "An error occurred during installation: $($_.Exception.Message)"
        Write-Host "Installation failed. Please check the log file for details: $script:LogFile" -ForegroundColor Red
        exit 1
    }
}

# Start the Script
Main
