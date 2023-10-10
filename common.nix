{ config, pkgs, lib, ... }: {

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
    extraGroups = [ "wheel" "networkmanager" "transmission" "audio" "video" "lxd" ];
    initialPassword = "a";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alexander.holmback@gmail.com" ];
  };


  fonts.fonts = with pkgs; [
    source-code-pro
    hackgen-nf-font
  ];

  environment.systemPackages = with pkgs; [

    # browsing and media
    qutebrowser firefox chromium
    mpv mupdf feh

    # wayland
    fuzzel swaybg wl-clipboard

    # search
    silver-searcher ripgrep fd fzf

    # LSPs
    nil lua-language-server

    # misc
    xdg-utils
    bitwarden-cli
    signal-desktop
    pavucontrol
    debootstrap
    minica
    transmission-qt
    unzip
    pciutils
    lsof
    (sqlite.override { interactive = true; })
    python3
    poetry
    wget
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

  # brightness keys
  programs.light.enable = true;
  services.actkbd = {
    enable = true;
    bindings = [
    { keys = [ 224 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -U 10"; }
    { keys = [ 225 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -A 10"; }
    ];
  };

  # sound with pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # add as we go
  xdg.mime.defaultApplications = {
    "image/*" = "feh.desktop";
    "text/html" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/about" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/unknown" = "org.qutebrowser.qutebrowser.desktop";
  };

  # birthday
  system.stateVersion = "20.03";
}
