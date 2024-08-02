#!/bin/sh
# HELPHINT=setup for commiting inside the container
set -e

SUBNAME="$(basename "$0" | sed -e 's/\.sh$//')"

HELP_MSG="Usage: $CLI $PRGNAME $SUBNAME [options]

To select the container interactively, it must be
running.
"

while [ $# -ne 0 ]; do
  case "$1" in
    -h | --help)
      printf "%s" "$HELP_MSG"
      exit 0
      ;;
    *) break ;;
  esac
  shift
done

container_list="$(docker container ls --format json)"

if [ -z "$container_list" ]; then
  echo "No running containers found"
  exit 1
fi

container_id="$(echo "$container_list" | jq '[.ID, .Names] | join(" | ")' --raw-output | fzf --nth 3 | sed -e 's/\s|\s.*$//')"

echo "copying files to container..."

WHERE_TO="/home/node"

echo "script in development, not working properly with .gnupg"

# copy .ssh/ .gnupg/ .gitconfig into container
for file in ~/.ssh ~/.gitconfig; do
  # if file does not exist throw
  if [ ! -e "$file" ]; then
    echo "file not found: $file"
    exit 1
  fi

  docker cp "$(realpath $file)" "$container_id:$WHERE_TO/$(basename $file)"
done

echo "copied files to '$WHERE_TO' in container"
