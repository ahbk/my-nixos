ahbk: user: cfg:
{ config
, pkgs
, theme
, ...
}:

with theme.colors;
with theme.fonts;

{
  home.shellAliases = {
    f = "fzf | xargs -r xdg-open";
    l = "eza -la --icons=auto";
    ll = "eza";
    cd = "z";
    grep = "grep --color=auto";
    cat = "bat";
  };

  home.sessionVariables = {
    PATH = "$PATH:$HOME/.local/bin";
    PROMPT_COMMAND = "\${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a; history -c; history -r";
    HISTTIMEFORMAT = "%y-%m-%d %T ";
  };

  programs.bash = {
    enable = true;

    historyControl = [ "ignoredups" "erasedups" "ignorespace" ];

    shellOptions = [
      "histappend"
      "histverify"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
    ];

    bashrcExtra = ''
    '';

    initExtra = ''
      pwu() {
        bw unlock --raw > ~/.bwsession
      }
      pw() {
        BW_SESSION=$(<~/.bwsession) bw get password $@ | wl-copy
      }
    '';

    shellAliases = {
      battery = "cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status";
    };
  };

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
  };

  programs.fzf = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    keyMode = "vi";
    escapeTime = 10;
    baseIndex = 1;
    extraConfig = ''
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

  programs.starship = {
    enable = false;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  home.packages = with pkgs; [ 
    bat
    bitwarden-cli
    eza
    fd
    imagemagick
    lazygit
    openssl
    ranger
    ripgrep
    silver-searcher
    unzip
  ];
}
