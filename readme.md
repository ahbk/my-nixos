# my system
This system is specified by flake.nix, configuration.nix and home.nix.

- [NixOS](https://github.com/NixOS/nixpkgs) + [Home Manager](https://github.com/nix-community/home-manager)
- WM: [Hyprland](https://github.com/hyprwm/Hyprland) + [tmux](https://github.com/tmux/tmux/wiki)
- Default apps:
[qutebrowser](https://github.com/qutebrowser/qutebrowser),
[foot](https://codeberg.org/dnkl/foot),
[neovim](https://github.com/neovim/neovim),
[mpv](https://github.com/mpv-player/mpv),
[feh](https://github.com/derf/feh),
[mupdf](https://mupdf.com) and
[fzf](https://github.com/junegunn/fzf).

## todo
- figure out telescope/ripgrep's deal with ignores
- implement [swaylock with lid switch](https://wiki.hyprland.org/Configuring/Binds/#bind-flags)
- fix [sound media keys](https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/services/audio/alsa.nix)
- optimize nix based on [this template](https://github.com/Misterio77/nix-starter-configs)
- evaluate these neovim plugins: chadtree, bufferline, navic(with barbecue) or lsp saga, which-key, lualine or lightline, gitsigns , indent-blankline, monakai or monakai-pro
