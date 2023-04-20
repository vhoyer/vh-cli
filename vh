#!/bin/sh

## Global constants, available for all tools
export VH_CONFIG_FILE="$HOME/.vhconfig"
export VH_INVOKE_DIR="$PWD"

# Load config file if present
if [ -f "$VH_CONFIG_FILE" ]; then
  # shellcheck source=/dev/null
  . "$VH_CONFIG_FILE"
fi

VH_BIN_FILE="$(readlink "$0" | realpath "$0")"
VH_CLI_DIR="$(dirname "$VH_BIN_FILE")"
VH_TOOLS_DIR="$VH_CLI_DIR/tools"

export VH_BIN_FILE VH_TOOLS_DIR VH_INVOKE_GIT_DIR VH_CLI_DIR

# help messages
SHORTHELP="the commands available are:
$(find "$VH_TOOLS_DIR" -maxdepth 1 -mindepth 1 -not -path '*/.*' | \
  sed -e 's/^.*\///' | \
  xargs -I{} sh -c "\
    head -n 3 $VH_TOOLS_DIR/{}/cmd.sh | \
    sed -ne 's/^# HELPHINT=/- {}§/p'" | \
  column -t -s '§')
"

# execute tool from the directory of this file by default
cd "$VH_CLI_DIR" || exit 1

# run auto update check as an independent process (nohup &)
UPDATE_NEEDED_FILE="/tmp/vh-needs-update"
if [ "$DO_AUTO_UPDATE" != 'false' ]; then
  nohup ./vh_update_check $UPDATE_NEEDED_FILE 1>/dev/null 2>&1 &
fi

# Check if tool exists
if [ ! -f "$VH_TOOLS_DIR/$1/cmd.sh" ]; then
  printf "unknown option: '%s'\n\n%s" "$1" "$SHORTHELP"
  exit 1
fi

# save current tool and shift
TOOL=$1
shift

# call tool and forward every argument to tool
"$VH_TOOLS_DIR/$TOOL/cmd.sh" "$@"

# after command execution, warn the user if there is an update available
if [ -f "$UPDATE_NEEDED_FILE" ]; then
  export LC='\033[1;36m' # light cyan
  export LY='\033[1;33m' # light yellow
  export RC='\033[0m' # reset color
  echo ""
  echo "${LY}\!\!${RC} Update available, run ${LC}vh update${RC} to update"
fi
