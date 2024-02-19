F_GRAY=\033[30;1m
B_WHITE=\033[47;1m
F_CYAN=\033[36;1m
T_RESET=\033[0m

CURRENT_SHELL=$(shell echo $$SHELL | sed -e 's|.*/||')
SHELL_CONFIG_FILE=$(shell sed -n -e's/SHELL_CONFIG_FILE=//p' tab-completion/${CURRENT_SHELL}/.env)

install:
	mkdir -p $$HOME/.local/bin/
	rm -f $$HOME/.local/bin/vh
	ln -fs $$(realpath ./vh) $$HOME/.local/bin/
	@echo -e "${F_CYAN}[info]${T_RESET} Insert the line below in your rc file (${SHELL_CONFIG_FILE}), we have support for:\n$(shell ls tab-completion)\n\n${B_WHITE}${F_GRAY}. $$PWD/tab-completion/${CURRENT_SHELL}/quero-completion.sh${T_RESET}\n\nthis is only for <tab> completion (like typing \"vh <tab>\" end it will show all the subcommands available)"

install-oh-my-zsh-tab-completion:
	mkdir -p $$HOME/.oh-my-zsh/custom/plugins/vh/
	rm -f $$HOME/.oh-my-zsh/custom/plugins/vh/_vh
	ln -fs $$(realpath ./tab-completion/zsh/_vh) $$HOME/.oh-my-zsh/custom/plugins/vh/
	@echo -e "${F_CYAN}[info]${T_RESET} Insert the line below in your rc file (${SHELL_CONFIG_FILE}), we have support for:\n$(shell ls tab-completion)\n\n${B_WHITE}${F_GRAY}plugins+=(vh)${T_RESET}\n\nthis is only for <tab> completion (like typing \"vh <tab>\" end it will show all the subcommands available"
