#!/bin/sh
# HELPHINT=send notification to phone

PRGNAME="$(basename "$(dirname "$0")")"
STATE_FILE="/tmp/vh-notify/server.url"
TITLE="VH Notify"

HELP_MSG="Usage: vh $PRGNAME [-t TITLE] MESSAGE

Sends a notification to your phone via the LAN notification server.

Options:
  --help, -h        Show this help message and exit
  -t TITLE          Notification title (default: \"$TITLE\")

Examples:
  vh $PRGNAME 'Build complete!'
  vh $PRGNAME -t 'Deploy' 'Production deploy finished'
"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      echo "$HELP_MSG"
      exit 0
      ;;
    -t)
      shift
      TITLE=$1
      ;;
    *)
      break
      ;;
  esac
  shift
done

MESSAGE="$*"

if [ -z "$MESSAGE" ]; then
  echo "Error: No message provided"
  echo "$HELP_MSG"
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: Notification server is not running."
  echo "Start it with: vh notify-server"
  exit 1
fi

SERVER_URL=$(cat "$STATE_FILE")

if [ -z "$SERVER_URL" ]; then
  echo "Error: Server URL is empty. Restart the server with: vh notify-server"
  exit 1
fi

# Build JSON payload safely using printf to escape quotes
JSON_TITLE=$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
JSON_MESSAGE=$(printf '%s' "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')

curl -sk -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"$JSON_TITLE\",\"message\":\"$JSON_MESSAGE\"}" \
  "$SERVER_URL/send"

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "Error: Failed to send notification. Is the server still running?"
  exit 1
fi

echo ""
