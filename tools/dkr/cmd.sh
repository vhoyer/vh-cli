#!/bin/sh
# HELPHINT=utils related to docker

CLI="vh"
PRGNAME="$(basename "$(dirname "$0")")"
SUBCOMMAND_DIR="$VH_TOOLS_DIR/$PRGNAME/subcommands"
export PRGNAME SUBCOMMAND_DIR

HELP_MSG="Usage: $CLI $PRGNAME [subcommand] [options]

Commands:
$(find "$SUBCOMMAND_DIR" -maxdepth 1 -mindepth 1 -not -path '*/.*' | \
  sed -e 's/^.*\///g' -e 's/\.sh$//g' | \
  xargs -I{} sh -c "\
    head -n 3 $SUBCOMMAND_DIR/{}.sh | \
    sed -ne 's/^# HELPHINT=/- {}§/p'" | \
  column -t -s '§')
"

# Parse global flags
case "$1" in
"-h" | "--help" | "")
  printf "%s" "$HELP_MSG"
  exit 0;
  ;;
esac

# Parse sub commands
COMMAND=$1
shift

if [ ! -f "$SUBCOMMAND_DIR/$COMMAND.sh" ]; then
  printf "Unknown command: %s\nUse '$CLI $PRGNAME --help' for help\n" "$COMMAND"
  exit 1
fi

"$SUBCOMMAND_DIR/$COMMAND.sh" "$@"
