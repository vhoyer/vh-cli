#!/bin/sh
set -e

# this function asks the user for a value showing a default value, and creates
vhsetup_prompt() {
  prompt="$1"
  default_value="$2"

  # print to stderr so that it doesn't interfere with the stdout of the command
  # and to be able to show message to user
  >&2 printf '%s (default: %s): ' "$prompt" "$default_value"
  read -r value
  echo "${value:-$default_value}"
}
