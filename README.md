# Smart 2FA CLI Manager (bash) <sup>v1.0.0</sup>

**Lightweight, offline, independent TOTP 2FA manager for Linux.**

No cloud, no phone required. Store your secrets locally, generate codes, create encrypted backups, and sync with Google Authenticator via QR codes.

---

## ⚠️ Disclaimer

**By using this software, you agree to the full disclaimer terms.**

**Summary:** Software provided "AS IS" without warranty. You assume all risks.

**Full legal disclaimer:** See [DISCLAIMER.md](DISCLAIMER.md)

---

## Installation

### Dependencies

```bash
# Arch Linux
sudo pacman -S oath-toolkit gnupg qrencode

# Debian/Ubuntu
sudo apt install oathtool gpg qrencode

# Fedora/RHEL
sudo dnf install oathtool gnupg2 qrencode
```

### Setup

1. Get the script from repository:
   ```bash
   cd ~
   git clone https://github.com/smartlegionlab/smart-2fa-cli-manager-bash.git
   cd smart-2fa-cli-manager-bash
   ```

   Or download directly:
   ```bash
   wget https://raw.githubusercontent.com/smartlegionlab/smart-2fa-cli-manager/main/2fa.sh
   ```

2. Install:
   ```bash
   chmod +x 2fa.sh
   sudo cp 2fa.sh /usr/local/bin/2fa
   ```

   Now you can use: `2fa init`

Or if you prefer to keep the original filename:
```bash
sudo cp 2fa.sh /usr/local/bin/2fa.sh
# Then use: 2fa.sh init
```

---

## Quick Start

```bash
# Initialize storage (creates encrypted ~/.2fa/secrets.gpg)
2fa init

# Add a service (secret from website QR code)
2fa add github JBSWY3DPEHPK3PXP

# Get TOTP code (auto-copies to clipboard)
2fa get github

# Show all services with current codes
2fa show-all

# Export QR code to phone (Google Authenticator / Aegis)
2fa qr github

# Create encrypted backup (saved to ~/.2fa/backups/)
2fa backup

# Restore from backup
2fa restore ~/.2fa/backups/secrets.2026-04-06.gpg

# Show version
2fa version

# Show author and repository info
2fa about
```

---

## Commands

| Command | Description |
|---------|-------------|
| `init` | Create encrypted storage |
| `add <service> <secret>` | Add a new service |
| `get <service>` | Generate TOTP code (copies to clipboard) |
| `list` | List all service names |
| `show-all` | List all services with current codes |
| `del <service>` | Delete a service |
| `show` | Show all secrets in plain text (⚠️ unsafe) |
| `qr <service>` | Show QR code to scan with phone |
| `backup` | Create encrypted backup with timestamp |
| `restore <file>` | Restore from encrypted backup |
| `about` | Show author, repository and license info |
| `version` | Show version number |
| `help` | Show help message |

---

## File Structure

```
~/.2fa/
├── secrets.gpg          # Encrypted master storage
└── backups/
    └── secrets.2026-04-06_14-30-00.gpg
```

---

## How It Works

- **Secrets are stored locally** in `~/.2fa/secrets.gpg` (AES-256 encrypted with GPG)
- **No internet connection required** - codes generated locally using `oathtool`
- **Backups are encrypted** with the same password
- **QR codes** let you import secrets into Google Authenticator / Aegis
- **Lost your phone?** Just re-scan QR codes from your Linux machine

---

## Security Notes

- Your GPG password is never stored
- Backup files are encrypted with the same password
- `2fa show` displays all secrets in plain text - use in secure environment only
- Keep backups in a safe place (encrypted USB drive, offline storage)

---

## Author & Repository

- **Author:** [@smartlegionlab](https://github.com/smartlegionlab/)
- **Repository:** [smartlegionlab/smart-2fa-cli-manager-bash](https://github.com/smartlegionlab/smart-2fa-cli-manager-bash)
- **License:** [BSD 3-Clause](LICENSE)

---
