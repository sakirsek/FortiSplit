# =============================================================================
# FortiSplit - Intelligent VPN Split Tunneling & DNS Fixer for FortiClient
# =============================================================================
#
# When FortiClient VPN connects, it often hijacks ALL internet traffic (0.0.0.0/0)
# and overrides DNS settings. This causes slow browsing, blocks local network
# access, and routes everything through the corporate tunnel.
#
# FortiSplit fixes this by:
#   1. Detecting your local network adapter (Wi-Fi or Ethernet) automatically.
#   2. Detecting the active FortiClient VPN adapter automatically.
#   3. Removing the VPN's default route so general internet bypasses VPN.
#   4. Removing any VPN-injected routes that conflict with your local subnet.
#   5. Adding explicit routes for corporate networks through the VPN tunnel.
#   6. Restoring your preferred DNS servers on the local adapter.
#
# Usage:
#   .\FortiSplit.ps1                  # Run with default settings
#   .\FortiSplit.ps1 -SkipDnsRestore  # Run without modifying DNS
#
# Author  : sakirsek
# Version : 2.0.0
# License : MIT
# Requires: Administrator privileges, PowerShell 5.1+
# Repo    : https://github.com/sakirsek/FortiSplit
# =============================================================================

param(
    [switch]$SkipDnsRestore
)

# ============================================================================
#  SELF-ELEVATION — Automatically request Administrator privileges
# ============================================================================

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs
    }
    catch {
        Write-Host "[FAIL] Could not obtain Administrator privileges." -ForegroundColor Red
        Write-Host "       Right-click the script and select 'Run as Administrator'." -ForegroundColor Red
        Wait-KeyPress
    }
    exit
}

# ============================================================================
#  USER CONFIGURATION — Edit these values to match your environment
# ============================================================================

# Corporate/internal networks that MUST go through the VPN tunnel.
# Add or remove entries as needed for your organization.
$TARGET_NETWORKS = @(
    @{ IP = "10.0.0.0";  Mask = "255.0.0.0" }          # Class A private (most common)
    # @{ IP = "172.16.0.0"; Mask = "255.240.0.0" }      # Class B private - uncomment if needed
    # @{ IP = "192.168.100.0"; Mask = "255.255.255.0" }  # Specific remote subnet - uncomment if needed
)

# DNS servers to restore on your local adapter after VPN hijacks them.
# Default: Google (8.8.8.8) + Cloudflare (1.1.1.1)
$PREFERRED_DNS = @("8.8.8.8", "1.1.1.1")

# Set to your local adapter name ONLY if auto-detection fails.
# Leave $null for automatic detection (recommended).
# Examples: "Wi-Fi", "Ethernet", "Ethernet 2"
$LOCAL_ADAPTER_OVERRIDE = $null

# ============================================================================
#  INTERNAL — No need to edit below this line
# ============================================================================

$SCRIPT_VERSION = "2.0.0"

# --- UI Helpers -----------------------------------------------------------

function Write-Banner {
    Write-Host ""
    Write-Host "    ______           __  _ _____       ___ __" -ForegroundColor Cyan
    Write-Host "   / ____/___  _____/ /_(_) ___/____  / (_) /_" -ForegroundColor Cyan
    Write-Host "  / /_  / __ \/ ___/ __/ /\__ \/ __ \/ / / __/" -ForegroundColor Cyan
    Write-Host " / __/ / /_/ / /  / /_/ /___/ / /_/ / / / /_" -ForegroundColor Cyan
    Write-Host "/_/    \____/_/   \__/_//____/ .___/_/_/\__/" -ForegroundColor Cyan
    Write-Host "                            /_/    v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Intelligent VPN Split Tunneling & DNS Fixer" -ForegroundColor DarkCyan
    Write-Host "  https://github.com/sakirsek/FortiSplit" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param([string]$Number, [string]$Message)
    Write-Host "  [$Number] " -ForegroundColor DarkYellow -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Detail {
    param([string]$Label, [string]$Value)
    Write-Host "      $Label : " -ForegroundColor Gray -NoNewline
    Write-Host $Value -ForegroundColor Green
}

function Write-Ok {
    param([string]$Message)
    Write-Host "      [OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Warn {
    param([string]$Message)
    Write-Host "      [!!] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "      [FAIL] " -ForegroundColor Red -NoNewline
    Write-Host $Message -ForegroundColor Red
}

function Wait-KeyPress {
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor Cyan -NoNewline
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Pause
    }
}

# --- Core Functions --------------------------------------------------------


function Find-LocalAdapter {
    # Finds the active local network adapter (Wi-Fi or Ethernet).
    # Returns the ifIndex of the adapter, or $null if not found.

    # If user explicitly set an override, use that
    if ($LOCAL_ADAPTER_OVERRIDE) {
        $adapter = Get-NetIPInterface -InterfaceAlias $LOCAL_ADAPTER_OVERRIDE -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($adapter) {
            return @{
                Index = $adapter.ifIndex
                Name  = $LOCAL_ADAPTER_OVERRIDE
            }
        }
        Write-Warn "Override adapter '$LOCAL_ADAPTER_OVERRIDE' not found. Falling back to auto-detect."
    }

    # Auto-detect: prefer Wi-Fi, then Ethernet, then any connected physical adapter
    $candidates = @("Wi-Fi", "Ethernet", "Ethernet 2", "Local Area Connection")

    foreach ($name in $candidates) {
        $iface = Get-NetIPInterface -InterfaceAlias $name -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($iface -and $iface.ConnectionState -eq "Connected") {
            return @{
                Index = $iface.ifIndex
                Name  = $name
            }
        }
    }

    # Last resort: find any connected physical adapter that is NOT Fortinet
    $fallback = Get-NetAdapter |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.InterfaceDescription -notlike "*Fortinet*" -and
            $_.InterfaceDescription -notlike "*Virtual*" -and
            $_.InterfaceDescription -notlike "*Loopback*"
        } | Select-Object -First 1

    if ($fallback) {
        $iface = Get-NetIPInterface -InterfaceIndex $fallback.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($iface) {
            return @{
                Index = $fallback.ifIndex
                Name  = $fallback.Name
            }
        }
    }

    return $null
}

function Find-VPNAdapter {
    # Finds the active FortiClient VPN adapter.
    # Returns the ifIndex, or $null if not found.
    $vpn = Get-NetAdapter |
        Where-Object {
            $_.InterfaceDescription -like "*Fortinet*" -and
            $_.Status -eq "Up"
        } | Select-Object -First 1

    if ($vpn) {
        return @{
            Index = $vpn.ifIndex
            Name  = $vpn.Name
        }
    }
    return $null
}

function Get-LocalSubnets {
    # Returns the subnets configured on the local adapter so we can
    # clean up any conflicting VPN-injected routes.
    param([int]$AdapterIndex)

    $addresses = Get-NetIPAddress -InterfaceIndex $AdapterIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $subnets = @()

    foreach ($addr in $addresses) {
        if ($addr.PrefixLength -and $addr.IPAddress) {
            $prefixLen = $addr.PrefixLength

            # Build subnet mask from prefix length
            $maskBinary = ("1" * $prefixLen).PadRight(32, "0")
            $o1 = [Convert]::ToInt32($maskBinary.Substring(0,  8), 2)
            $o2 = [Convert]::ToInt32($maskBinary.Substring(8,  8), 2)
            $o3 = [Convert]::ToInt32($maskBinary.Substring(16, 8), 2)
            $o4 = [Convert]::ToInt32($maskBinary.Substring(24, 8), 2)
            $mask = "$o1.$o2.$o3.$o4"

            # Calculate network address
            $ipParts   = $addr.IPAddress.Split(".")
            $maskParts = $mask.Split(".")
            $n1 = [int]$ipParts[0] -band [int]$maskParts[0]
            $n2 = [int]$ipParts[1] -band [int]$maskParts[1]
            $n3 = [int]$ipParts[2] -band [int]$maskParts[2]
            $n4 = [int]$ipParts[3] -band [int]$maskParts[3]
            $network = "$n1.$n2.$n3.$n4"

            $subnets += @{ Network = $network; Mask = $mask }
        }
    }

    return $subnets
}

function Set-SplitTunnel {
    # Main logic: reconfigures routing and DNS for split tunneling.
    param(
        [hashtable]$Local,
        [hashtable]$VPN
    )

    # -- Step 3: Set interface metrics (lower = higher priority) -----------
    Write-Step "3" "Setting interface priorities..."
    try {
        Set-NetIPInterface -InterfaceIndex $Local.Index -InterfaceMetric 5   -ErrorAction Stop
        Set-NetIPInterface -InterfaceIndex $VPN.Index   -InterfaceMetric 100 -ErrorAction Stop
        Write-Detail "Local ($($Local.Name))" "Metric 5  (high priority)"
        Write-Detail "VPN   ($($VPN.Name))"   "Metric 100 (low priority)"
    }
    catch {
        Write-Fail "Could not set interface metrics: $($_.Exception.Message)"
        return $false
    }

    # -- Step 4: Remove VPN's default route (free the internet) ------------
    Write-Step "4" "Removing VPN default route (0.0.0.0/0)..."
    $result = & route.exe delete "0.0.0.0" "if" "$($VPN.Index)" 2>&1
    Write-Ok "Default route via VPN removed."

    # -- Step 5: Clean up local subnet conflicts ---------------------------
    Write-Step "5" "Cleaning conflicting local subnet routes..."
    $localSubnets = Get-LocalSubnets -AdapterIndex $Local.Index

    if ($localSubnets.Count -eq 0) {
        Write-Warn "No local subnets detected - skipping conflict cleanup."
    }
    else {
        foreach ($subnet in $localSubnets) {
            $result = & route.exe delete "$($subnet.Network)" "mask" "$($subnet.Mask)" "if" "$($VPN.Index)" 2>&1
            Write-Ok "Removed VPN route for $($subnet.Network)/$($subnet.Mask)"
        }
    }

    # -- Step 6: Add corporate routes through VPN --------------------------
    Write-Step "6" "Adding corporate network routes through VPN tunnel..."
    foreach ($net in $TARGET_NETWORKS) {
        try {
            $result = & route.exe add "$($net.IP)" "mask" "$($net.Mask)" "0.0.0.0" "if" "$($VPN.Index)" 2>&1
            Write-Ok "$($net.IP) / $($net.Mask) -> VPN tunnel"
        }
        catch {
            Write-Fail "Could not add route for $($net.IP): $($_.Exception.Message)"
        }
    }

    # -- Step 7: Restore DNS (optional) ------------------------------------
    if ($SkipDnsRestore) {
        Write-Step "7" "DNS restoration skipped (-SkipDnsRestore)."
    }
    else {
        Write-Step "7" "Restoring DNS servers on local adapter..."
        try {
            Set-DnsClientServerAddress -InterfaceIndex $Local.Index -ServerAddresses $PREFERRED_DNS -ErrorAction Stop
            $null = ipconfig /flushdns 2>&1
            Write-Ok "DNS set to: $($PREFERRED_DNS -join ', ')"
            Write-Ok "DNS cache flushed."
        }
        catch {
            Write-Fail "Could not restore DNS: $($_.Exception.Message)"
        }
    }

    return $true
}

# ============================================================================
#  MAIN EXECUTION
# ============================================================================

Write-Banner

# -- Step 1: Detect local adapter ------------------------------------------
Write-Step "1" "Detecting local network adapter..."
$localAdapter = Find-LocalAdapter

if (-not $localAdapter) {
    Write-Fail "No active local network adapter found (Wi-Fi / Ethernet)."
    Write-Fail "Make sure your Wi-Fi or Ethernet is connected."
    Wait-KeyPress
    exit 1
}
Write-Detail "Adapter" $localAdapter.Name
Write-Detail "ifIndex" $localAdapter.Index

# -- Step 2: Detect VPN adapter --------------------------------------------
Write-Step "2" "Detecting FortiClient VPN adapter..."
$vpnAdapter = Find-VPNAdapter

if (-not $vpnAdapter) {
    Write-Fail "No active FortiClient VPN adapter found."
    Write-Fail "Connect to VPN first, wait ~10 seconds, then run this script."
    Wait-KeyPress
    exit 1
}
Write-Detail "Adapter" $vpnAdapter.Name
Write-Detail "ifIndex" $vpnAdapter.Index

# -- Run split tunnel logic ------------------------------------------------
Write-Host ""
$success = Set-SplitTunnel -Local $localAdapter -VPN $vpnAdapter

# -- Summary ---------------------------------------------------------------
Write-Host ""
if ($success) {
    Write-Host "  =============================================" -ForegroundColor DarkGreen
    Write-Host "   SPLIT TUNNELING ACTIVE                      " -ForegroundColor Green
    Write-Host "   Corporate traffic -> VPN tunnel             " -ForegroundColor Green
    Write-Host "   Everything else   -> Local internet         " -ForegroundColor Green
    Write-Host "  =============================================" -ForegroundColor DarkGreen
}
else {
    Write-Host "  =============================================" -ForegroundColor DarkRed
    Write-Host "   COMPLETED WITH ERRORS - Check output above  " -ForegroundColor Red
    Write-Host "  =============================================" -ForegroundColor DarkRed
}

Write-Host ""
Wait-KeyPress