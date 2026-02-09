#!/bin/sh
# HELPHINT=convert mp4 to gif with the smallest size I can muster

CLI="vh"
PRGNAME="$(basename "$(dirname "$0")")"

SCALE=920
FPS=24


HELP_MSG="Usage: vh $PRGNAME [options] <filename1> [filename2 ...]

Converts <filename1> to <filename1>.gif

Filenames passed should not contain the extension

Options:
  --help, -h        Show this help message and exit

  --scale <number>,
  -s <number>       Default = $SCALE, represents width of
                    the gif, aspect on height will be
                    kept.
  --fps <number>    Default = $FPS, frame rate of the gif.
"


while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      echo "$HELP_MSG"
      exit 0
      ;;
    --scale|-s)
      shift
      SCALE=$1
      ;;
    --fps)
      shift
      FPS=$1
      ;;
    *)
      ## allow rest of args to be consumed as files
      break
      ;;
  esac
  shift
done



# execute tool from the directory it was invoked
cd "$VH_INVOKE_DIR" || exit 1


for file in $@; do
  input="$file"
  output="${file%.*}.gif"
  palette=/tmp/vh2gif-palette.png

  ffmpeg \
    -i $input \
    -vf "fps=$FPS,scale=$SCALE:-1:flags=lanczos,palettegen" \
    $palette \
    -y
  ffmpeg \
    -i $input \
    -i $palette \
    -filter_complex "fps=$FPS,scale=$SCALE:-1:flags=lanczos[p];[p]paletteuse" \
    -gifflags \
    -offsetting \
    -c:v gif \
    $output \
    -y
done

