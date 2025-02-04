{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) getExe mkEnableOption mkIf;

  inherit (import ../theme.nix) colors;
  cfg = config.my-nixos-hm.shell;
in

{
  options.my-nixos-hm.shell = {
    enable = mkEnableOption "Enable shell for this user";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      bat
      bitwarden-cli
      dig
      eza
      fd
      imagemagick
      lazygit
      less
      nethogs
      openssl
      ranger
      ripgrep
      shell-gpt
      silver-searcher
      unzip
      tcpdump
      traceroute
      which
    ];

    programs = {

      bash = {
        enable = true;

        sessionVariables = {
          PATH = "$HOME/.local/bin:$PATH";
          PROMPT_COMMAND = "\${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a; history -c; history -r";
          HISTTIMEFORMAT = "%y-%m-%d %T ";
          MANPAGER = "sh -c 'col -bx | bat -l man -p'";
          MANROFFOPT = "-c";
        };

        shellAliases = {
          battery = "cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status";
          f = "xdg-open \"$(fzf)\"";
          l = "eza -la --icons=auto";
          ll = "eza";
          cd = "z";
          grep = "grep --color=auto";
          switch = "nixos-rebuild switch --use-remote-sudo --show-trace --print-build-logs --verbose";
          needs-reboot =
            let
              booted = "<(readlink /run/booted-system/{initrd,kernel,kernel-modules})";
              current = "<(readlink /run/current-system/{initrd,kernel,kernel-modules})";
              diff = "$(diff ${booted} ${current})";
            in
            ''if [[ ${diff} ]] then echo "yes"; else echo "no"; fi'';
        };

        historyControl = [
          "ignoredups"
          "erasedups"
          "ignorespace"
        ];

        shellOptions = [
          "histappend"
          "histverify"
          "checkwinsize"
          "extglob"
          "globstar"
          "checkjobs"
        ];

        initExtra = ''
          pwu() {
            bw unlock --raw > ~/.bwsession
          }
          pw() {
            BW_SESSION=$(<~/.bwsession) bw get password $@ | wl-copy
          }
          d() {
            ${getExe pkgs.wdiff} "$1" "$2" | ${getExe pkgs.colordiff}
          }
        '';
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      fzf = {
        enable = true;
      };

      ssh = {
        enable = true;
      };

      tmux = {
        enable = true;
        terminal = "tmux-256color";
        keyMode = "vi";
        escapeTime = 10;
        baseIndex = 1;
        extraConfig = with colors; ''
          set-option -ga terminal-features ',foot:RGB'
          set-option -g status-right "#{user}@#{host}"
          set -ga terminal-overrides ",256col:Tc"
          set -ga update-environment TERM
          set -ga update-environment TERM_PROGRAM
          set -g allow-passthrough on
          set -g status-bg "${bg-400}"
          set -g status-fg "${fg-500}"
          bind -T copy-mode-vi y send -X copy-pipe-and-cancel 'wl-copy'
        '';
      };

      yazi = {
        enable = true;
        enableBashIntegration = true;
      };

      zoxide = {
        enable = true;
      };

    };

  };
}
