#!/bin/bash

# ============================================
# Smart 2FA Manager - independent TOTP generator
# Version: v1.0.2
# Author: Alexander Suvorov
# Repository: https://github.com/smartlegionlab/smart-2fa-manager-bash
# License: BSD 3-Clause
# ============================================

CONFIG_DIR="$HOME/.2fa"
SECRETS_ENC="$CONFIG_DIR/secrets.gpg"
SECRETS_TMP="$CONFIG_DIR/secrets.tmp"
BACKUP_DIR="$CONFIG_DIR/backups"
VERSION="v1.0.2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_NAME="Smart 2FA Manager"

mkdir -p "$CONFIG_DIR"
mkdir -p "$BACKUP_DIR"

sanitize_service_name() {
    local name="$1"
    name=$(echo "$name" | tr ' ' '_')
    name=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]//g')
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    if [[ -z "$name" ]]; then
        echo ""
        return 1
    fi
    echo "$name"
    return 0
}

usage() {
    cat << EOF
Smart 2FA Manager v${VERSION} - Offline TOTP 2FA generator for Linux

Usage:
    2fa <command> [arguments]

Commands:
    add <service> <secret>     Add a new service
    get <service>              Get TOTP code (copies to clipboard)
    list                       List all service names
    show-all                   Show all services with current codes
    del <service>              Delete a service
    show                       Show unencrypted content (unsafe)
    backup                     Save encrypted backup with timestamp
    restore <file>             Restore from encrypted backup file
    init                       Initialize storage (create empty)
    qr <service>               Show QR code for phone
    about                      Show author and repository info
    version                    Show version number
    help                       Show this help message

Examples:
    2fa init
    2fa add github JBSWY3DPEHPK3PXP
    2fa get github
    2fa list
    2fa show-all
    2fa qr github
    2fa backup
    2fa restore ~/.2fa/backups/secrets.2026-04-06.gpg

File Structure:
    ~/.2fa/secrets.gpg          # Encrypted master storage
    ~/.2fa/backups/*.gpg        # Timestamped encrypted backups

Repository: https://github.com/smartlegionlab/smart-2fa-manager-bash
License: BSD 3-Clause
EOF
    exit 0
}

about() {
    cat << EOF
Smart 2FA Manager v${VERSION}

Author:  Alexander Suvorov
License: BSD 3-Clause
Repository: https://github.com/smartlegionlab/smart-2fa-manager-bash

Description:
    A lightweight, offline, and independent TOTP 2FA manager for Linux.
    No cloud, no phone required. Store your secrets locally, generate codes,
    create encrypted backups, and sync with Google Authenticator via QR codes.

Features:
    - No internet connection required
    - AES-256 encryption via GPG
    - Encrypted timestamped backups
    - QR code export for phone apps
    - Clipboard integration (xclip/wayland)
    - Simple service:secret format

Dependencies:
    - gpg (GNU Privacy Guard)
    - oathtool (OATH Toolkit)
    - qrencode (optional, for QR codes)
    - xclip or wl-copy (optional, for clipboard)

BSD 3-Clause License
    Copyright (c) 2026, Alexander Suvorov
    All rights reserved.
EOF
    exit 0
}

version() {
    echo "Smart 2FA Manager v${VERSION}"
    exit 0
}

get_gpg_pass() {
    echo -n "Enter password: "
    read -s GPG_PASS
    echo
}

decrypt_store() {
    if [[ ! -f "$SECRETS_ENC" ]]; then
        echo -e "${YELLOW}Storage does not exist. Run '2fa init'${NC}"
        return 1
    fi
    gpg --batch --yes --passphrase "$GPG_PASS" --decrypt "$SECRETS_ENC" 2>/dev/null > "$SECRETS_TMP"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERR] Wrong password or corrupted storage${NC}"
        rm -f "$SECRETS_TMP"
        return 1
    fi
    return 0
}

encrypt_store() {
    gpg --batch --yes --passphrase "$GPG_PASS" --symmetric --cipher-algo AES256 --output "$SECRETS_ENC" "$SECRETS_TMP" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERR] Error during encryption${NC}"
        return 1
    fi
    rm -f "$SECRETS_TMP"
    return 0
}

cmd_init() {
    if [[ -f "$SECRETS_ENC" ]]; then
        echo -e "${YELLOW}Storage already exists. Overwrite? (y/N)${NC}"
        read -r ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && exit 0
    fi
    echo -n "Create password: "
    read -s GPG_PASS
    echo
    echo -n "Repeat password: "
    read -s GPG_PASS2
    echo
    [[ "$GPG_PASS" != "$GPG_PASS2" ]] && echo -e "${RED}[ERR] Passwords do not match${NC}" && exit 1
    echo -n "" > "$SECRETS_TMP"
    encrypt_store
    echo -e "${GREEN}[OK] Storage created at $SECRETS_ENC${NC}"
}

cmd_add() {
    local service="$1"
    local secret="$2"
    [[ -z "$service" || -z "$secret" ]] && echo -e "${RED}[ERR] Usage: 2fa add <service> <secret>${NC}" && exit 1
    service=$(sanitize_service_name "$service")
    if [[ -z "$service" ]]; then
        echo -e "${RED}[ERR] Service name contains no valid characters (a-z, 0-9, _, -)${NC}"
        exit 1
    fi
    secret=$(echo "$secret" | tr -d '[:space:]' | tr 'a-z' 'A-Z')
    get_gpg_pass
    decrypt_store || exit 1

    if grep -qi "^$service:" "$SECRETS_TMP"; then
        echo -e "${YELLOW}[WARN] Service '$service' already exists. Replace? (y/N)${NC}"
        read -r ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && rm -f "$SECRETS_TMP" && exit 0
        sed -i "/^$service:/d" "$SECRETS_TMP"
        echo -e "${YELLOW}[OK] Replacing existing service${NC}"
    fi
    echo "$service:$secret" >> "$SECRETS_TMP"
    encrypt_store
    echo -e "${GREEN}[OK] ${APP_NAME}: Service '${service}' added successfully${NC}"
}

cmd_get() {
    local service="$1"
    [[ -z "$service" ]] && echo -e "${RED}[ERR] Usage: 2fa get <service>${NC}" && exit 1
    service=$(sanitize_service_name "$service")
    if [[ -z "$service" ]]; then
        echo -e "${RED}[ERR] Invalid service name${NC}"
        exit 1
    fi
    get_gpg_pass
    decrypt_store || exit 1
    local secret=$(grep -i "^$service:" "$SECRETS_TMP" | head -1 | cut -d: -f2- | tr -d '\n\r')
    rm -f "$SECRETS_TMP"
    if [[ -z "$secret" ]]; then
        echo -e "${RED}[ERR] Service '${service}' not found${NC}"
        exit 1
    fi
    local code=$(oathtool --totp -b "$secret" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERR] Code generation failed. Is the secret correct?${NC}"
        exit 1
    fi
    echo -e "${BLUE}${APP_NAME}${NC} - TOTP for ${GREEN}${service}${NC}: ${YELLOW}${code}${NC}"
    if command -v xclip &>/dev/null; then
        echo -n "$code" | xclip -selection clipboard
        echo -e "${YELLOW}[OK] Copied to clipboard${NC}"
    elif command -v wl-copy &>/dev/null; then
        echo -n "$code" | wl-copy
        echo -e "${YELLOW}[OK] Copied to clipboard${NC}"
    fi
}

cmd_list() {
    get_gpg_pass
    decrypt_store || exit 1
    local count=$(grep -c ":" "$SECRETS_TMP" 2>/dev/null || echo "0")
    echo -e "${BLUE}${APP_NAME}${NC} - ${GREEN}Saved services (${count})${NC}:"
    cut -d: -f1 "$SECRETS_TMP" | sort | sed 's/^/  - /'
    rm -f "$SECRETS_TMP"
}

cmd_show_all() {
    get_gpg_pass
    decrypt_store || exit 1

    echo -e "${BLUE}${APP_NAME}${NC} - ${GREEN}All services with current codes${NC}"
    echo -e "${GREEN}========================================${NC}"

    local total=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local service=$(echo "$line" | cut -d: -f1)
        local secret=$(echo "$line" | cut -d: -f2- | tr -d '\n\r')
        local code=$(oathtool --totp -b "$secret" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            printf "${GREEN}  %-20s${NC} : ${YELLOW}%s${NC}\n" "$service" "$code"
            ((total++))
        else
            printf "${RED}  %-20s${NC} : ${RED}[ERR] invalid secret${NC}\n" "$service"
        fi
    done < "$SECRETS_TMP"

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[OK] Total: $total service(s)${NC}"
    rm -f "$SECRETS_TMP"
}

cmd_del() {
    local service="$1"
    [[ -z "$service" ]] && echo -e "${RED}[ERR] Usage: 2fa del <service>${NC}" && exit 1
    service=$(sanitize_service_name "$service")
    if [[ -z "$service" ]]; then
        echo -e "${RED}[ERR] Invalid service name${NC}"
        exit 1
    fi
    get_gpg_pass
    decrypt_store || exit 1
    if ! grep -qi "^$service:" "$SECRETS_TMP"; then
        echo -e "${RED}[ERR] Service '${service}' not found${NC}"
        rm -f "$SECRETS_TMP"
        exit 1
    fi
    sed -i "/^$service:/d" "$SECRETS_TMP"
    encrypt_store
    echo -e "${GREEN}[OK] ${APP_NAME}: Service '${service}' deleted successfully${NC}"
}

cmd_show() {
    get_gpg_pass
    decrypt_store || exit 1
    echo -e "${YELLOW}[WARN] ${APP_NAME} - Unencrypted content (DO NOT SHOW ANYONE)${NC}"
    echo -e "${YELLOW}==============================================${NC}"
    cat "$SECRETS_TMP"
    echo -e "${YELLOW}==============================================${NC}"
    rm -f "$SECRETS_TMP"
}

cmd_backup() {
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local backup_file="$BACKUP_DIR/secrets.$timestamp.gpg"

    echo -e "${BLUE}${APP_NAME} - Creating backup${NC}"
    get_gpg_pass
    decrypt_store || exit 1

    gpg --batch --yes --passphrase "$GPG_PASS" --symmetric --cipher-algo AES256 --output "$backup_file" "$SECRETS_TMP" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERR] Error creating backup${NC}"
        rm -f "$SECRETS_TMP"
        exit 1
    fi

    rm -f "$SECRETS_TMP"
    echo -e "${GREEN}[OK] Backup saved: $backup_file${NC}"
}

cmd_restore() {
    local backup_file="$1"
    [[ -z "$backup_file" || ! -f "$backup_file" ]] && echo -e "${RED}[ERR] File not found: $backup_file${NC}" && exit 1

    echo -e "${BLUE}${APP_NAME} - Restoring from backup${NC}"
    echo -n "Enter password for backup: "
    read -s GPG_PASS
    echo

    gpg --batch --yes --passphrase "$GPG_PASS" --decrypt "$backup_file" 2>/dev/null > "$SECRETS_TMP"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERR] Wrong password or corrupted backup${NC}"
        rm -f "$SECRETS_TMP"
        exit 1
    fi

    if ! grep -q ":" "$SECRETS_TMP"; then
        echo -e "${RED}[ERR] Invalid backup format (expected service:secret)${NC}"
        rm -f "$SECRETS_TMP"
        exit 1
    fi

    local count=$(wc -l < "$SECRETS_TMP")
    echo -n "Create new password for restored storage: "
    read -s NEW_PASS
    echo
    echo -n "Repeat new password: "
    read -s NEW_PASS2
    echo
    [[ "$NEW_PASS" != "$NEW_PASS2" ]] && echo -e "${RED}[ERR] Passwords do not match${NC}" && rm -f "$SECRETS_TMP" && exit 1

    GPG_PASS="$NEW_PASS"
    encrypt_store
    echo -e "${GREEN}[OK] Restored ${count} entries successfully${NC}"
}

cmd_qr() {
    local service="$1"
    [[ -z "$service" ]] && echo -e "${RED}[ERR] Usage: 2fa qr <service>${NC}" && exit 1
    service=$(sanitize_service_name "$service")
    if [[ -z "$service" ]]; then
        echo -e "${RED}[ERR] Invalid service name${NC}"
        exit 1
    fi
    get_gpg_pass
    decrypt_store || exit 1
    local secret=$(grep -i "^$service:" "$SECRETS_TMP" | head -1 | cut -d: -f2- | tr -d '\n\r')
    rm -f "$SECRETS_TMP"
    if [[ -z "$secret" ]]; then
        echo -e "${RED}[ERR] Service '${service}' not found${NC}"
        exit 1
    fi
    local uri="otpauth://totp/$service?secret=$secret&issuer=Smart2FA"
    echo -e "${BLUE}${APP_NAME} - QR code for ${GREEN}${service}${NC}"
    if command -v qrencode &>/dev/null; then
        qrencode -t utf8 "$uri"
        echo -e "${YELLOW}[OK] Scan this QR code in your authenticator app${NC}"
    else
        echo -e "${YELLOW}[WARN] qrencode not installed. Install it: sudo apt install qrencode${NC}"
        echo -e "Manual URI: $uri"
    fi
}

case "$1" in
    add)      cmd_add "$2" "$3" ;;
    get)      cmd_get "$2" ;;
    list)     cmd_list ;;
    show-all) cmd_show_all ;;
    del)      cmd_del "$2" ;;
    show)     cmd_show ;;
    backup)   cmd_backup ;;
    restore)  cmd_restore "$2" ;;
    init)     cmd_init ;;
    qr)       cmd_qr "$2" ;;
    about)    about ;;
    version)  version ;;
    help|-h|--help|"") usage ;;
    *)        echo -e "${RED}[ERR] Unknown command: $1${NC}" && usage ;;
esac