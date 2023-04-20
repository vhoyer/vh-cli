TOOLS_PATH="$(dirname $0)/tools"

complete -W "$(ls $TOOLS_PATH | tr '\n' ' ')" vh
