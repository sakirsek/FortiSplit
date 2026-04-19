# =============================================================================
# FortiSplit - Installation Script
# =============================================================================
# This script:
# 1. Creates a local folder for FortiSplit
# 2. Downloads the main script from GitHub
# 3. Creates a CMD wrapper for global access
# 4. Adds the folder to the User PATH
# =============================================================================

$ErrorActionPreference = "Stop"

$installDir = Join-Path $env:USERPROFILE ".fortisplit"
$psPath = Join-Path $installDir "FortiSplit.ps1"
$cmdPath = Join-Path $installDir "fortisplit.cmd"
$repoUrl = "https://raw.githubusercontent.com/sakirsek/FortiSplit/main/FortiSplit.ps1"

Write-Host ""
Write-Host "  ______           __  _ _____       ___ __" -ForegroundColor Cyan
Write-Host " / ____/___  _____/ /_(_) ___/____  / (_) /_" -ForegroundColor Cyan
Write-Host "/ /_  / __ \/ ___/ __/ /\__ \/ __ \/ / / __/" -ForegroundColor Cyan
Write-Host "/ __/ / /_/ / /  / /_/ /___/ / /_/ / / / /_" -ForegroundColor Cyan
Write-Host "/_/    \____/_/   \__/_//____/ .___/_/_/\__/" -ForegroundColor Cyan
Write-Host "                            /_/    Installer" -ForegroundColor Cyan
Write-Host ""

# 1. Create directory
if (-not (Test-Path $installDir)) {
    Write-Host "  [1/4] Creating directory: $installDir" -ForegroundColor Gray
    New-Item -Path $installDir -ItemType Directory | Out-Null
} else {
    Write-Host "  [1/4] Directory already exists: $installDir" -ForegroundColor Gray
}

# 2. Download script
Write-Host "  [2/4] Downloading FortiSplit.ps1 from GitHub..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $psPath -UseBasicParsing
} catch {
    Write-Host "        [FAIL] Could not download script from GitHub." -ForegroundColor Red
    Write-Host "               URL: $repoUrl" -ForegroundColor Red
    Write-Host "               Ensure you have internet access and the repo is public." -ForegroundColor Red
    exit 1
}

# 3. Create CMD wrapper
Write-Host "  [3/4] Creating global 'fortisplit' command wrapper..." -ForegroundColor Gray
$cmdContent = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FortiSplit.ps1" %*
"@
$cmdContent | Out-File -FilePath $cmdPath -Encoding ascii

# 4. Add to PATH
Write-Host "  [4/4] Updating User PATH environment variable..." -ForegroundColor Gray
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($currentPath -notlike "*$installDir*") {
    if ([string]::IsNullOrWhiteSpace($currentPath)) {
        $newPath = $installDir
    } else {
        $newPath = "$currentPath;$installDir".Replace(";;", ";")
    }
    
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    
    $env:PATH += ";$installDir"
    
    Write-Host "        [OK] Added to User PATH." -ForegroundColor Green
    Write-Host "        [!!] IMPORTANT: You can use 'fortisplit' in THIS window now!" -ForegroundColor Cyan
    Write-Host "        [!!] Note: Other open windows will still need a restart." -ForegroundColor Yellow
} else {
    Write-Host "        [OK] Already in PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "Installation Complete!" -ForegroundColor Cyan
Write-Host "You can now use 'fortisplit' directly in this terminal." -ForegroundColor White
Write-Host ""
