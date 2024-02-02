ahbk: user: cfg: { config, pkgs, ... }: {
  programs.bash.bashrcExtra = ''
      export PATH="$PATH:$HOME/.local/bin"
  '';
  home.shellAliases = {
    nix-store-size = ''ls /nix/store | wc -l'';
    f = ''fzf | xargs -I {} rifle {}'';
    l = ''eza -la --icons=auto'';
    ll = ''eza'';
    grep = ''grep --color=auto'';
  };

  programs.bash = {
    enable = true;

    initExtra = ''
      pwu() {
        bw unlock --raw > ~/.bwsession
      }
      pw() {
        BW_SESSION=$(<~/.bwsession) bw get password $@ | wl-copy
      }
    '';

    shellAliases = {
      battery = ''cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status'';
    };
  };

  programs.zoxide = {
    enable = true;
  };

  programs.fzf = {
    enable = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  home.packages = with pkgs; [ 
    bitwarden-cli
    ranger
    lazygit
    silver-searcher
    ripgrep
    fd
    eza
    wget
    unzip
  ];
}
