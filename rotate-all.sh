#!/bin/sh

# Account number file
ACCOUNT_FILE="/home/user/mullvad.txt"

# Wireguard configuration file
CONFIG="/etc/wireguard/wg0.conf"

# Backup file
BACKUP_CONFIG="${CONFIG}.bak"

# Escape special characters for sed
escape() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}

# Ensure required commands are installed
ensure_command() {
    command -v "$1" >/dev/null 2>&1 || { echo "[+] Error: $1 is not installed. Please install it and try again."; exit 1; }
}

ensure_command curl
ensure_command wg
ensure_command jq
ensure_command systemctl

# Get account number
if [ -r "$ACCOUNT_FILE" ]; then
    ACCOUNT="$(cat "$ACCOUNT_FILE" | tr -d '[:space:]')"
    if ! [[ $ACCOUNT =~ ^[0-9]{16}$ ]]; then
        echo "[+] Error: Invalid account number format"
        exit 1
    fi
else
    echo "[+] Error: No account number found"
    exit 1
fi
echo "[+] Using account $ACCOUNT"

# Get existing private key
OLD_PRIVATE_KEY="$(grep -oP '^PrivateKey\s*=\s*\K[^\s]+' "$CONFIG")"
if [ -z "$OLD_PRIVATE_KEY" ]; then
    echo "[+] Error: Wireguard private key not found"
    exit 1
fi

# Get public key
OLD_PUBLIC_KEY="$(printf '%s\n' "$OLD_PRIVATE_KEY" | wg pubkey)"
if [ -z "$OLD_PUBLIC_KEY" ]; then
    echo "[+] Error: Failed to get public key"
    exit 1
fi
echo "[+] Found public key $OLD_PUBLIC_KEY"

# Generate new private key
echo "[+] Generating new private key"
NEW_PRIVATE_KEY=$(wg genkey)
if [ -z "$NEW_PRIVATE_KEY" ]; then
    echo "[+] Error: Failed to generate new private key"
    exit 1
fi

# Generate new public key
NEW_PUBLIC_KEY=$(echo "$NEW_PRIVATE_KEY" | wg pubkey)
if [ -z "$NEW_PUBLIC_KEY" ]; then
    echo "[+] Error: Failed to generate new public key"
    exit 1
fi
echo "[+] Generated new public key $NEW_PUBLIC_KEY"

# Get authorization token
echo "[+] Getting Mullvad access token"
AUTH_TOKEN_RES=$(curl -fsSL -X POST \
    -H 'Content-Type: application/json' \
    -H 'Accepts: application/json' \
    -d "{\"account_number\": \"$ACCOUNT\"}" \
    https://api.mullvad.net/auth/v1/token)
AUTH_TOKEN=$(echo "$AUTH_TOKEN_RES" | jq -r '.access_token')
if [ -z "$AUTH_TOKEN" ]; then
    echo "[+] Error: Failed to get account token"
    exit 1
fi

# Submit new key to Mullvad
echo "[+] Submitting new Wireguard key to Mullvad"
IPS=$(curl -s -d account="$ACCOUNT" \
          --data-urlencode pubkey="$NEW_PUBLIC_KEY" \
          https://api.mullvad.net/wg/)
if ! printf '%s\n' "$IPS" | grep -E '^[0-9a-f:/.,]+$' >/dev/null; then
    echo "[+] Error: Failed to submit new Wireguard key to Mullvad"
    echo "[+] Response: $IPS"
    exit 1
fi
echo "[+] New Wireguard IPs are $IPS"

# Get device name using the new public key
echo "[+] Getting device name using the new public key"
DEVICES=$(curl -fsSL \
    -H 'Content-Type: application/json' \
    -H 'Accepts: application/json' \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    https://api.mullvad.net/accounts/v1/devices)
if [ -z "$DEVICES" ]; then
    echo "[+] Error: Failed to retrieve devices"
    exit 1
fi
DEVICE_NAME=$(echo "$DEVICES" | jq -r --arg NEW_PUBLIC_KEY "$NEW_PUBLIC_KEY" '.[] | select(.pubkey == $NEW_PUBLIC_KEY) | .name')
if [ -z "$DEVICE_NAME" ]; then
    echo "[+] Error: Device name not found for new public key"
    exit 1
fi
echo "[+] Device name for new public key: $DEVICE_NAME"

# Get new WireGuard endpoint IP address and public key
echo "[+] Fetching relay list to get a new WireGuard IP address and public key"
RELAY_LIST=$(curl -fsSL -H 'Content-Type: application/json' -H "Authorization: Bearer $AUTH_TOKEN" -H 'Accepts: application/json' https://api.mullvad.net/app/v1/relays)
ACTIVE_RELAYS=$(echo "$RELAY_LIST" | jq '.wireguard.relays | map(select(.active == true))')
ACTIVE_RELAYS_COUNT=$(echo "$ACTIVE_RELAYS" | jq length)
if [ "$ACTIVE_RELAYS_COUNT" -eq 0 ]; then
    echo "[+] Error: No active relays found"
    exit 1
fi
NEW_RELAY_INDEX=$(shuf -i 0-$(("$ACTIVE_RELAYS_COUNT" - 1)) -n 1)
NEW_RELAY=$(echo "$ACTIVE_RELAYS" | jq -r ".[$NEW_RELAY_INDEX]")
NEW_WG_IP=$(echo "$NEW_RELAY" | jq -r '.ipv4_addr_in')
NEW_WG_PUBLIC_KEY=$(echo "$NEW_RELAY" | jq -r '.public_key')
NEW_WG_HOSTNAME=$(echo "$NEW_RELAY" | jq -r '.hostname')
if [ -z "$NEW_WG_IP" ] || [ -z "$NEW_WG_PUBLIC_KEY" ]; then
    echo "[+] Error: Failed to get a new WireGuard IP address or public key"
    exit 1
fi

echo "[+] Selected new WireGuard hostname: $NEW_WG_HOSTNAME"
echo "[+] Selected new WireGuard IP address: $NEW_WG_IP"
echo "[+] Selected new WireGuard public key: $NEW_WG_PUBLIC_KEY"

# Backup Wireguard config
echo "[+] Backing up Wireguard config"
cp "$CONFIG" "$BACKUP_CONFIG"

# Update Wireguard config
echo "[+] Updating Wireguard config $CONFIG"
ESCAPED_PRIVATE_KEY="$(escape "$NEW_PRIVATE_KEY")"
ESCAPED_IPS="$(escape "$IPS")"
ESCAPED_DEVICE_NAME="$(escape "$DEVICE_NAME")"
ESCAPED_WG_IP="$(escape "$NEW_WG_IP")"
ESCAPED_WG_PUBLIC_KEY="$(escape "$NEW_WG_PUBLIC_KEY")"
sed -i -r "s/^# Device: .*/# Device: $ESCAPED_DEVICE_NAME/" "$CONFIG"
sed -i -r "s/^PrivateKey\s*=\s*.*$/PrivateKey = $ESCAPED_PRIVATE_KEY/" "$CONFIG"
sed -i -r "s/^Address\s*=\s*.*$/Address = $ESCAPED_IPS/" "$CONFIG"
sed -i -r "s/^Endpoint\s*=\s*.*$/Endpoint = $ESCAPED_WG_IP:51820/" "$CONFIG"
sed -i -r "s/^PublicKey\s*=\s*.*$/PublicKey = $ESCAPED_WG_PUBLIC_KEY/" "$CONFIG"

# Optionally: Revoke old key
echo "[+] Revoking old key"
curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d "{\"pubkey\": \"$OLD_PUBLIC_KEY\"}" \
        https://api.mullvad.net/www/wg-pubkeys/revoke/

# Check if Wireguard is running
echo "[+] Waiting for changes to propagate..."
sleep 5
if systemctl is-active --quiet wg-quick@wg0; then
    echo "[+] Wireguard is running, restarting Wireguard"
    # systemctl restart wg-quick@wg0
else
    echo "[+] Wireguard is not running, no need to restart"
fi

echo "[+] Key rotation and device name update completed successfully"
