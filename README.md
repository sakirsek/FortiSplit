# FortiSplit: Intelligent VPN Split Tunneling & DNS Fixer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OS: Windows](https://img.shields.io/badge/OS-Windows-blue.svg)](https://www.microsoft.com/windows)
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://microsoft.com/powershell)

FortiClient VPN is notoriously aggressive — it hijacks **all** your internet traffic (`0.0.0.0/0`) and overrides your DNS settings. The result? Slow browsing, no local network access, and every single request routed through your company's tunnel.

**FortiSplit** is a lightweight PowerShell script that automates **split tunneling**. It restores your local internet and DNS while keeping corporate traffic (SAP, FTP, internal servers) strictly inside the VPN tunnel.

## 🚀 Key Features

| Feature | Description |
|---|---|
| **Automated Routing** | Routes only corporate IPs (e.g. `10.x.x.x`) through VPN; everything else goes to your local ISP |
| **DNS Leak Fix** | Restores your preferred DNS (Google / Cloudflare) while FortiClient is active |
| **Auto-Detection** | Language-independent detection (route-based) finds your local adapter and VPN automatically |
| **Local Subnet Cleanup** | Detects and removes VPN-injected routes that conflict with your home/office network |
| **Admin Auto-Escalation** | Requests Administrator privileges automatically if needed |
| **Configurable** | Simple variables at the top of the script — customize networks, DNS, and adapter |

## 🚀 Installation & Usage

### Quick Install (PowerShell)

Run this command in **PowerShell** to install FortiSplit globally:

```powershell
irm https://raw.githubusercontent.com/sakirsek/FortiSplit/main/install.ps1 | iex
```

**After installation, you can simply type this in any terminal (CMD or PowerShell):**

```bash
fortisplit
```

> [!TIP]
> If the command is not recognized immediately, please restart your terminal window to refresh the environment variables.

### Manual Installation

1. **Download** `FortiSplit.ps1` (or clone this repo).
2. **Connect** to your VPN via FortiClient.
3. **Wait** ~10 seconds for the connection to stabilize.
4. **Right-click** `FortiSplit.ps1` → **Run with PowerShell**.
5. Enjoy fast internet **and** working corporate resources simultaneously.

### PowerShell Terminal

```powershell
# Run with default settings
.\FortiSplit.ps1

# Run without DNS changes (keep VPN's DNS)
.\FortiSplit.ps1 -SkipDnsRestore
```

## ⚙️ How It Works

When you run FortiSplit, it performs these steps in order:

```
┌─────────────────────────────────────────────────┐
│ 1. Detect local adapter (via internet route)    │
│ 2. Detect FortiClient VPN adapter               │
│ 3. Set local adapter to HIGH priority (metric 5) │
│ 4. Remove VPN's default route (0.0.0.0/0)       │
│ 5. Clean up VPN routes conflicting with LAN      │
│ 6. Add corporate network routes through VPN      │
│ 7. Restore DNS servers on local adapter          │
└─────────────────────────────────────────────────┘
```

**Before FortiSplit:** All traffic → VPN → Corporate firewall → Internet (slow)  
**After FortiSplit:** Corporate traffic → VPN | Everything else → Direct internet (fast)

## 📝 Configuration

Open `FortiSplit.ps1` and edit the **User Configuration** section at the top:

### Corporate Networks

Define which IP ranges should go through the VPN tunnel:

```powershell
$TARGET_NETWORKS = @(
    @{ IP = "10.0.0.0";  Mask = "255.0.0.0" }          # Most common corporate range
    # @{ IP = "172.16.0.0"; Mask = "255.240.0.0" }      # Uncomment if needed
    # @{ IP = "192.168.100.0"; Mask = "255.255.255.0" }  # Specific remote subnet
)
```

### DNS Servers

Choose your preferred DNS providers:

```powershell
$PREFERRED_DNS = @("8.8.8.8", "1.1.1.1")  # Google + Cloudflare (default)
# $PREFERRED_DNS = @("9.9.9.9", "149.112.112.112")  # Quad9 (privacy-focused)
# $PREFERRED_DNS = @("208.67.222.222", "208.67.220.220")  # OpenDNS
```

### Adapter Override

If auto-detection doesn't work for your setup:

```powershell
$LOCAL_ADAPTER_OVERRIDE = $null       # Auto-detect (recommended)
# $LOCAL_ADAPTER_OVERRIDE = "Wi-Fi"   # Force Wi-Fi
# $LOCAL_ADAPTER_OVERRIDE = "Ethernet" # Force Ethernet
```

## 🔧 Troubleshooting

| Problem | Solution |
|---|---|
| "No active FortiClient VPN adapter found" | Connect to VPN first, wait ~10 seconds, then run the script |
| "No active local network adapter found" | Ensure you are connected to the internet. The script now uses your active internet route to find the adapter, so it works even if your adapter has a non-English name. |
| Script closes immediately | Right-click → "Run with PowerShell" or run from a PowerShell terminal |
| DNS not resolving after script | Try running `ipconfig /flushdns` manually, or restart your browser |
| Corporate app stopped working | Make sure the app's IP range is listed in `$TARGET_NETWORKS` |
| Script needs to run after every VPN reconnect | Yes — FortiClient resets routes on each connection. Consider creating a shortcut or scheduled task |

## 📋 Requirements

- **OS:** Windows 10 / 11
- **PowerShell:** 5.1 or later (pre-installed on Windows 10+)
- **Privileges:** Administrator (auto-requested)
- **VPN Client:** FortiClient (any version)

## ⚠️ Security Disclaimer

This script modifies local routing tables and DNS settings. These changes are temporary and reset when you disconnect VPN or reboot. However, **ensure this complies with your company's IT security policy** before use. The author is not responsible for any security breaches or policy violations.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to:

1. **Fork** this repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
