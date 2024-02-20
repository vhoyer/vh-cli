#!/bin/sh
# HELPHINT=Add template base for creating your own local template to a project
set -e

printf "template name: "; read -r template_name;
printf "template desc: "; read -r template_description;

NEW_TEMPLATE_HOME="./.vh-cli/templates/$template_name/"
NEW_TEMPLATE_ENTRY="$NEW_TEMPLATE_HOME/cmd.sh"
mkdir -p "$NEW_TEMPLATE_HOME"
cat <<EOF > "$NEW_TEMPLATE_ENTRY"
#!/bin/sh
# HELPHINT=$template_description
set -e
EOF
chmod +x "$NEW_TEMPLATE_ENTRY"
