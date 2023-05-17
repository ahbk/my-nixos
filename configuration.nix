# This is configuration.nix for friday
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
    pavucontrol
    qutebrowser firefox chromium
    bemenu swaybg

    xclip
    silver-searcher

    bitwarden-cli

    #wget
    #mpv
    #git
    #mkpasswd
    #gcc
    #debootstrap
    #pwgen
    #gtypist
    #xawtv
    #scrot
    # tor-browser-bundle-bin
    #signal-desktop
    #mupdf
    #pciutils hwinfo lshw dmidecode
    #zip unzip
    #(st.override { conf = builtins.readFile ./st-0.8.5/config.def.h; })
    #python310
    #vimHugeX
    #musescore
    #feh
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

  #programs.adb.enable = true;

  #virtualisation.docker.enable = true;

  #programs.light.enable = true; # Needed for the /run/wrappers/bin/light SUID wrapper.
  #services.actkbd = {
  #  enable = true;
  #  bindings = [
  #    { keys = [ 224 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -U 10"; }
  #    { keys = [ 225 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -A 10"; }
  #  ];
  #};
  #sound.enable = true;
  #sound.mediaKeys.volumeStep = "1000";
  #hardware.pulseaudio.enable = true;
  #hardware.bluetooth.enable = true;

  #services.openssh.enable = true;
  #services.transmission.enable = true;

  # the release version of the first install of this system (don't change)
  system.stateVersion = "20.03";
}
