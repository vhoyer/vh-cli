# vh-cli

## Installing

```bash
# Adiciona o `~/.local/bin/` no seu .bashrc (ou .zshrc ou outro)
echo "PATH=\"\$PATH:\$HOME/.local/bin\"" >> $HOME/.bashrc
# Clona esse repositório.
git clone git@github.com:/vhoyer/vh-cli.git
# Entra na pasta
cd vh-cli
# Chama `make install` nessa pasta.
make install
```

## Dependencies

- git
- node
- fzf
- jq

## Contributing

Para adicionar um script no CLI, basta adicionar um script chamado `cmd.sh`
dentro de uma pasta com o nome do seu subcomando na pasta `./tools`.
