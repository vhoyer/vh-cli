#!/bin/sh
# HELPHINT=create a project

# default values
PRGNAME="$(basename "$(dirname "$0")")"
TEMPLATE_DIR="$VH_TOOLS_DIR/$PRGNAME/templates"

LOCAL_TEMPLATES_HELP=""
TEMPLATE_DIR_LOCAL="$VH_INVOKE_DIR/.vh-cli/templates"
if [ -d "$TEMPLATE_DIR_LOCAL" ]; then
  LOCAL_TEMPLATES_HELP="Project defined templates:
$(find "$TEMPLATE_DIR_LOCAL" -maxdepth 1 -mindepth 1 -not -path '*/.*' | \
  sed -e 's/^.*\///' | \
  xargs -I{} sh -c "\
    head -n 3 $TEMPLATE_DIR_LOCAL/{}/cmd.sh | \
    sed -ne 's/^# HELPHINT=/- {}§/p'" | \
  column -t -s '§')
"
fi

HELPMSG="Usage: quero $PRGNAME [options] <package>

  Includes the templates into your project. There are global templates which
  you can find on the vh-cli repository, and you can also define local
  templates for your project on a folder at the root of your project named:
  \`.vh-cli/templates/<name of the template>/cmd.sh\`

  You use the \`cmd.sh\` to code custom behavior, for examples on how the this
  system works, you can see templates defined on vh-cli repository.

  The philosophy of these templates should be \"ready to add something to an
  existing project\". Think about: 'adding docker-compose setup to an existing
  project', 'adding a local template to an existing project'.

Options:
  -h,--help  print this help

Global templates:
$(find "$TEMPLATE_DIR" -maxdepth 1 -mindepth 1 -not -path '*/.*' | \
  sed -e 's/^.*\///' | \
  xargs -I{} sh -c "\
    head -n 3 $TEMPLATE_DIR/{}/cmd.sh | \
    sed -ne 's/^# HELPHINT=/- {}§/p'" | \
  column -t -s '§')
$LOCAL_TEMPLATES_HELP"

# Parse flags
while [ $# -ne 0 ]; do
  case "$1" in
    "-h" | "--help" | "")
      printf "%s" "$HELPMSG"
      exit 0
      ;;
    *)
      PACKAGE="$1"
      break
      ;;
  esac
  shift
done

if [ -z "$PACKAGE" ]; then
  echo "no package was specified"
  exit 1
fi

PACKAGE_ENTRYPOINT="$TEMPLATE_DIR/$PACKAGE/cmd.sh"

if [ -f "$TEMPLATE_DIR_LOCAL/$PACKAGE/cmd.sh" ]; then
  PACKAGE_ENTRYPOINT="$TEMPLATE_DIR_LOCAL/$PACKAGE/cmd.sh"
elif [ -f "$TEMPLATE_DIR/$PACKAGE/cmd.sh" ]; then
  PACKAGE_ENTRYPOINT="$TEMPLATE_DIR/$PACKAGE/cmd.sh"
else
  echo "package not found: $PACKAGE"
  exit 1
fi

if [ ! -f "$PACKAGE_ENTRYPOINT" ]; then
  echo "package not found: $PACKAGE"
  exit 1
fi

# run from invoke
cd "$VH_INVOKE_DIR" || exit 1
# make package root available for script
export QINIT_PACKAGE_ROOT="$TEMPLATE_DIR/$PACKAGE"
# run cmd.sh from chosen package
"$PACKAGE_ENTRYPOINT"
