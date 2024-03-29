#!/bin/sh
# HELPHINT=display commitizen categories

PRGNAME="$(basename "$0")"

SHORTHELP="usage: /$PRGNAME (-[hv]|--help)?/
for a detailed list of options, use: \`$PRGNAME --help\`
"

HELPMSG="if you run $PRGNAME with no options it will display
the commitizen categories.

  -h       displays this message
  -v       displays commitizen help
"

COMMITIZEN_HELP="
    feat:  A new feature
     fix:  A bug fix
    docs:  Documentation only changes
   style:  Changes that do not affect the meaning of the code
           (white-space, formatting, missing semi-colons, etc)
refactor:  A code change that neither fixes a bug or adds a
           feature
    perf:  A code change that improves performance
    test:  Adding missing tests
   chore:  Changes to the build process or auxiliary tools and
           libraries such as documantation generation

"

case "$1" in
  "--help")
    printf "%s" "$HELPMSG"
    ;;
  "-h")
    printf "%s" "$SHORTHELP"
    ;;
  ""|"-v")
    printf "%s" "$COMMITIZEN_HELP"
    ;;
  *)
    printf "unknown option: '%s'\n\n%s" "$1" "$SHORTHELP"
    exit 1
    ;;
esac
