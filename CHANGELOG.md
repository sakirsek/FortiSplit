# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0] - 2026-04-14

### Added
- Automatic local adapter detection (Wi-Fi, Ethernet, or any connected physical adapter)
- Automatic local subnet detection and VPN conflict cleanup
- `$TARGET_NETWORKS` configuration for corporate IP ranges
- `$PREFERRED_DNS` configuration for DNS servers
- `$LOCAL_ADAPTER_OVERRIDE` option for manual adapter selection
- `-SkipDnsRestore` parameter to skip DNS changes
- Comment-based help (`Get-Help .\FortiSplit.ps1`)
- ASCII banner and color-coded step output
- Detailed error handling with `try/catch` blocks
- How It Works, Troubleshooting, and Configuration sections in README

### Changed
- All comments and messages translated from Turkish to English
- Refactored from flat script to modular functions
- Local subnet routes (192.168.x.x) are now auto-detected instead of hardcoded
- VPN adapter detection widened to any adapter with "Fortinet" in its description

### Removed
- Hardcoded Wi-Fi adapter name
- Hardcoded 192.168.1.0 and 192.168.0.0 route deletions

## [1.0.0] - 2026-04-13

### Added
- Initial release
- Basic split tunneling for FortiClient VPN
- Wi-Fi and VPN adapter detection by name/description
- Metric adjustment, default route removal, DNS override
