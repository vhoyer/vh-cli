#!/bin/sh
# HELPHINT=get random port number

PRGNAME="$(basename "$(dirname "$0")")"

HELP_MSG="Usage: vh $PRGNAME [options]

Generates a random port number between 10000 and 65535. Copies the port number
to the clipboard.

Options:
  --help, -h  Show this help message and exit
  --copy, -c  Copy the port number to the clipboard
"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      echo "$HELP_MSG"
      exit 0
      ;;
    --copy|-c)
      COPY=1
      ;;
    *)
      ;;
  esac
  shift
done

PORT=$(shuf -i 10000-65535 -n 1)

if [ -n "$COPY" ]; then
  echo "$PORT" | xclip -selection clipboard
  echo "Port copied to clipboard."
fi

echo "$PORT"
