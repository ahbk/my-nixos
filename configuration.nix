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

  networking.hostName = "friday";
  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Stockholm";

  users.users.frans = {
    isNormalUser = true;
    home = "/home/frans";
    extraGroups = [ "wheel" "networkmanager" "transmission" "audio" "adbusers" "video" "docker" "lxd" ];
    initialPassword = "a";
  };

  # fix hw quirk: wrong keycode for pipe |
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
  };

  fonts.fonts = with pkgs; [
    source-code-pro
    hackgen-nf-font
  ];

  environment.systemPackages = with pkgs; [

    qutebrowser firefox chromium
    mpv mupdf feh

    # for hyprland
    bemenu swaybg

    wl-clipboard
    silver-searcher ripgrep fd

    bitwarden-cli

    nil lua-language-server

    xdg-utils

    pavucontrol

    signal-desktop

    #xawtv
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

  programs.hyprland = {
    enable = true;
  };

  # for xbacklight
  hardware.acpilight.enable = true;

  # sound with pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    #jack.enable = true;
  };

  xdg.mime.defaultApplications = {
    "image/jpeg" = "feh.desktop";
    "image/png" = "feh.desktop";
    "text/html" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/about" = "org.qutebrowser.qutebrowser.desktop";
    "x-scheme-handler/unknown" = "org.qutebrowser.qutebrowser.desktop";
  };

  system.stateVersion = "20.03";
}
