#!/bin/sh
# HELPHINT=Add a node docker compose setup to a project
set -e

# load template utils
. "$(dirname "$0")/../../template-utils.sh"

# folder to take template files from
SOURCE_DIR="$(dirname "$0")/source"
SOURCE_DIR_CHAR_COUNT="$(echo "$SOURCE_DIR" | wc --chars)"
TARGET_DIR="$VH_INVOKE_DIR"

# variables to replace <%= %> in template files
NODE_VERSION="$(vhsetup_prompt "Node version" "$(node -v | cut -c2-)")"
PORT="$(vhsetup_prompt "Port" "$(vh port)")"
PACKAGE_MANAGER="$(vhsetup_prompt "Package manager" "pnpm")"

FILES_TO_COPY="$(find "$SOURCE_DIR/" -type f \
  | cut -c"$SOURCE_DIR_CHAR_COUNT"- \
  | cut -c2- \
  | sed -e '/^$/d')"

for FILE in $FILES_TO_COPY; do
  NEW_FILE="$TARGET_DIR/$FILE"

  # create parent directories if they don't exist
  # this makes so that the source can have subdirectories
  mkdir -p "$(dirname "$NEW_FILE")"

  # remove file if it exists
  rm -f "$NEW_FILE"
  # copy file to new place
  cp "$SOURCE_DIR/$FILE" "$NEW_FILE"

  # replace variables in the new file
  sed \
    -e "s/<%= NODE_VERSION %>/$NODE_VERSION/" \
    -e "s/<%= PORT %>/$PORT/" \
    -e "s/<%= PACKAGE_MANAGER %>/$PACKAGE_MANAGER/" \
    -i "$NEW_FILE"
done

# if .gitignore exists, try removing ".env" from it
if [ -f "$TARGET_DIR/.gitignore" ]; then
  sed -e '/.env/d' -i "$TARGET_DIR/.gitignore"
fi
