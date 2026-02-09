#!/bin/sh
# HELPHINT=start LAN notification server for phone

PRGNAME="$(basename "$(dirname "$0")")"
TOOL_DIR="$(dirname "$0")"
STATE_DIR="/tmp/vh-notify"
VAPID_DIR="$HOME/.local/share/vh-notify"
PORT=7777

HELP_MSG="Usage: vh $PRGNAME [options]

Starts a local HTTPS server that sends notifications to your phone's browser
over LAN using Server-Sent Events and the Web Notifications API.

Scan the QR code shown in the terminal with your phone to connect.

Options:
  --help, -h        Show this help message and exit
  --port PORT, -p PORT
                    Port to listen on (default: $PORT)
"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      echo "$HELP_MSG"
      exit 0
      ;;
    --port|-p)
      shift
      PORT=$1
      ;;
    *)
      echo "Unknown option: $1"
      echo "$HELP_MSG"
      exit 1
      ;;
  esac
  shift
done

# Detect if running in WSL2
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

# Detect LAN IP
LAN_IP=""
if $IS_WSL; then
  echo "WSL2 detected."
  # Get Windows host's actual LAN IP (the one phones can reach)
  LAN_IP=$(powershell.exe -NoProfile -Command \
    '(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1).IPv4Address.IPAddress' \
    2>/dev/null | tr -d '\r\n')
  WSL_IP=$(hostname -I | awk '{print $1}')
else
  if command -v ip >/dev/null 2>&1; then
    LAN_IP=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p')
  fi
  if [ -z "$LAN_IP" ]; then
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi
fi
if [ -z "$LAN_IP" ]; then
  echo "Error: Could not detect LAN IP address"
  exit 1
fi

echo "Detected LAN IP: $LAN_IP"

# Ensure state directory
mkdir -p "$STATE_DIR"

# Ensure persistent data directory exists (for CA certs, VAPID keys, subscriptions)
mkdir -p "$VAPID_DIR"

# Generate persistent CA certificate (install once on phone to trust all future server certs)
CA_KEY="$VAPID_DIR/ca-key.pem"
CA_CERT="$VAPID_DIR/ca.pem"
if [ ! -f "$CA_CERT" ]; then
  echo "Generating CA certificate (one-time)..."
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$CA_KEY" -out "$CA_CERT" \
    -days 3650 -subj "/CN=VH Notify CA" \
    2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Failed to generate CA certificate"
    exit 1
  fi
  echo "CA certificate saved to $CA_CERT"
  echo "Install this on your phone to trust the server."
fi

# Generate server certificate signed by the CA for this LAN IP
CERT_FILE="$STATE_DIR/cert.pem"
KEY_FILE="$STATE_DIR/key.pem"

echo "Generating server certificate for $LAN_IP (signed by CA)..."
openssl req -newkey rsa:2048 -nodes \
  -keyout "$KEY_FILE" -out "$STATE_DIR/server.csr" \
  -subj "/CN=vh-notify" \
  2>/dev/null

printf "subjectAltName=IP:%s\n" "$LAN_IP" > "$STATE_DIR/cert-ext.cnf"

openssl x509 -req \
  -in "$STATE_DIR/server.csr" \
  -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
  -out "$CERT_FILE" \
  -days 30 \
  -extfile "$STATE_DIR/cert-ext.cnf" \
  2>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Failed to generate server certificate"
  exit 1
fi
rm -f "$STATE_DIR/server.csr" "$STATE_DIR/cert-ext.cnf"

# Install npm dependencies if needed
if [ ! -d "$TOOL_DIR/node_modules" ]; then
  echo "Installing dependencies..."
  npm install --prefix "$TOOL_DIR"
  if [ $? -ne 0 ]; then
    echo "Error: npm install failed"
    exit 1
  fi
fi

# Generate VAPID keys for Web Push (persist across reboots)
VAPID_FILE="$VAPID_DIR/vapid.json"
if [ ! -f "$VAPID_FILE" ]; then
  echo "Generating VAPID keys..."
  node -e "
    var wp = require('$TOOL_DIR/node_modules/web-push');
    var keys = wp.generateVAPIDKeys();
    var fs = require('fs');
    fs.writeFileSync('$VAPID_FILE', JSON.stringify(keys, null, 2));
  "
  if [ $? -ne 0 ]; then
    echo "Error: Failed to generate VAPID keys"
    exit 1
  fi
  echo "VAPID keys saved to $VAPID_FILE"
fi

# WSL2: set up port forwarding so the phone can reach the server
if $IS_WSL; then
  echo "Setting up port forwarding ($LAN_IP:$PORT -> $WSL_IP:$PORT)..."
  echo "An administrator prompt may appear."

  WIN_TEMP=$(powershell.exe -NoProfile -Command '[System.IO.Path]::GetTempPath()' 2>/dev/null | tr -d '\r\n')
  SETUP_PS1="${WIN_TEMP}vh-notify-setup.ps1"
  CLEANUP_PS1="${WIN_TEMP}vh-notify-cleanup.ps1"
  LINUX_SETUP_PS1=$(wslpath "$SETUP_PS1" 2>/dev/null)
  LINUX_CLEANUP_PS1=$(wslpath "$CLEANUP_PS1" 2>/dev/null)

  printf 'netsh interface portproxy add v4tov4 listenport=%s listenaddress=0.0.0.0 connectport=%s connectaddress=%s\n' \
    "$PORT" "$PORT" "$WSL_IP" > "$LINUX_SETUP_PS1"
  printf 'netsh advfirewall firewall add rule name="vh-notify-%s" dir=in action=allow protocol=tcp localport=%s\n' \
    "$PORT" "$PORT" >> "$LINUX_SETUP_PS1"

  printf 'netsh interface portproxy delete v4tov4 listenport=%s listenaddress=0.0.0.0\n' \
    "$PORT" > "$LINUX_CLEANUP_PS1"
  printf 'netsh advfirewall firewall delete rule name="vh-notify-%s"\n' \
    "$PORT" >> "$LINUX_CLEANUP_PS1"

  powershell.exe -NoProfile -Command \
    "Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$SETUP_PS1' -Verb RunAs -Wait" 2>/dev/null

  if [ $? -ne 0 ]; then
    echo "Warning: Port forwarding setup may have failed."
    echo "You can set it up manually in an admin PowerShell:"
    echo "  netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=$WSL_IP"
    echo "  netsh advfirewall firewall add rule name=\"vh-notify-$PORT\" dir=in action=allow protocol=tcp localport=$PORT"
  else
    echo "Port forwarding active."
  fi
fi

# Write server URL for notify-send to find
SERVER_URL="https://$LAN_IP:$PORT"
echo "$SERVER_URL" > "$STATE_DIR/server.url"

# Cleanup on exit
cleanup() {
  rm -f "$STATE_DIR/server.url"
  if $IS_WSL && [ -n "$CLEANUP_PS1" ]; then
    echo ""
    echo "Removing port forwarding..."
    powershell.exe -NoProfile -Command \
      "Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$CLEANUP_PS1' -Verb RunAs -Wait" 2>/dev/null
    rm -f "$LINUX_SETUP_PS1" "$LINUX_CLEANUP_PS1" 2>/dev/null
  fi
  echo "\nServer stopped."
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# Start the server
node "$TOOL_DIR/server.js" "$CERT_FILE" "$KEY_FILE" "$PORT" "$LAN_IP" "$VAPID_FILE" "$VAPID_DIR/subscriptions.json" "$CA_CERT"
