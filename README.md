# dotfiles

This repo contains the configuration to setup my machines. This is using [Chezmoi](https://chezmoi.io), the dotfile manager to setup the install.

This automated setup is currently only configured for MacOS machines. Pretty much forked from https://github.com/logandonley/dotfiles, TY!

## How to run

```shell
export GITHUB_USERNAME=ianyimi
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
```
