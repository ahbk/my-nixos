{ config, pkgs, lib, ... }: {
  imports = [ ./hardware-configurations/friday.nix ];

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
  
  security.polkit.enable = true;
  security.pki.certificateFiles = [ ./minica/minica.pem ];

  networking.hostName = "friday";
  networking.extraHosts = ''
      127.0.0.2 weblog.local
    '';
  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Stockholm";

  users.users.frans = {
    isNormalUser = true;
    home = "/home/frans";
    extraGroups = [ "wheel" "networkmanager" "transmission" "audio" "adbusers" "video" "lxd" ];
    initialPassword = "a";
  };

  fonts.fonts = with pkgs; [
    source-code-pro
    hackgen-nf-font
  ];

  environment.systemPackages = with pkgs; [

    # browsing and media
    qutebrowser firefox chromium
    mpv mupdf feh

    # for hyprland
    fuzzel swaybg wl-clipboard

    # search
    silver-searcher ripgrep fd fzf

    # LSPs
    nil lua-language-server

    # misx
    xdg-utils
    bitwarden-cli
    signal-desktop
    pavucontrol
    debootstrap
    minica
    transmission-qt

  ];

  programs.hyprland = {
    enable = true;
  };

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
    #jack.enable = true;
  };

  # fix hw quirk: wrong keycode for pipe |
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
  };

  # add as we go
  xdg.mime.defaultApplications = {
    "image/jpeg" = "feh.desktop";
    "image/png" = "feh.desktop";
    "text/html" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/about" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/unknown" = "org.qutebrowser.qutebrowser.desktop";
  };

  # birthday
  system.stateVersion = "20.03";
}
