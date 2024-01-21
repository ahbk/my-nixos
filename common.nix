{ config, pkgs, lib, inputs, ... }: {
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  system.activationScripts.stty = ''
    ${pkgs.coreutils}/bin/stty -ixon
  '';

  # As an end user who doesn't tinker with privileges or delve
  # into system administration, the benefits of having Polkit
  # in a system like NixOS might not be immediately apparent.
  # However, Polkit still offers advantages that contribute
  # to your overall experience and security:
  # [ long list redacted ]
  #
  # /ChatGTP
  security.polkit.enable = true;

  # makes certificates for https
  security.pki.certificateFiles = [ ./minica/minica.pem ];

  # nmtui
  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Stockholm";

  users.users.frans = {
    isNormalUser = true;
    home = "/home/frans";
    extraGroups = [ "wheel" "networkmanager" "transmission" "audio" "video" ];
    initialPassword = "a";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alexander.holmback@gmail.com" ];
  };

  fonts.packages = with pkgs; [
    source-code-pro
    hackgen-nf-font
  ];

  environment.sessionVariables = rec {
    XDG_CACHE_HOME  = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME   = "$HOME/.local/share";
    XDG_STATE_HOME  = "$HOME/.local/state";

    # Not officially in the specification
    XDG_BIN_HOME    = "$HOME/.local/bin";
    PATH = [ 
      "${XDG_BIN_HOME}"
    ];
  };

  environment.systemPackages = with pkgs; [

    # search
    silver-searcher ripgrep fd fzf

    # LSPs
    nil lua-language-server

    # misc
    debootstrap
    minica
    unzip
    pciutils
    lsof
    (sqlite.override { interactive = true; })
    python3
    poetry
    wget
    inputs.agenix.packages.${system}.default
  ];

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    escapeTime = 10;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };

  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  # birthday
  system.stateVersion = "20.03";
}
