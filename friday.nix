{ inputs, pkgs, config, lib, ... }: {
  imports = [
    ./hardware/friday.nix
    ./common.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [
    "helvetica-neue-lt-std"
  ];

  networking = {
    hostName = "friday";
    extraHosts = ''
      127.0.0.2 ahbk.local
      10.233.1.2 wp.local
      10.233.1.2 www.wp.local
    '';
    firewall.allowedTCPPorts = [ 3000 5173 8000 ];
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "wlp1s0";
    };
    networkmanager.unmanaged = [ "interface-name:ve-*" ];
  };

  #programs.adb.enable = true;
  #users.users.frans.extraGroups = ["adbusers"];

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  # hw quirk: wrong keycode for pipe |
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
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

  services.openssh.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    ensureDatabases = [ "frans" ];
    ensureUsers = [
      {
        name = "frans";
        ensurePermissions = {
          "frans.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  fonts.packages = with pkgs; [
    aileron
    barlow
    cabin
    dina-font
    dm-sans
    fira
    fira-code
    fira-code-symbols
    font-awesome
    garamond-libre
    helvetica-neue-lt-std
    ibm-plex
    inter
    jost
    kanit-font
    libre-baskerville
    libre-bodoni
    libre-franklin
    liberation_ttf
    manrope
    mplus-outline-fonts.githubRelease
    montserrat
    noto-fonts
    noto-fonts-emoji
    oxygenfonts
    roboto
    roboto-mono
    roboto-slab
    roboto-serif
    paratype-pt-sans
    proggyfonts
    raleway
    redhat-official-fonts
    rubik
    source-sans-pro
    ubuntu_font_family
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    ensureDatabases = [ "frans" ];
    ensureUsers = [
      {
        name = "frans";
        ensureDBOwnership = true;
      }
    ];
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

  environment.systemPackages = with pkgs; [
    bitwarden-cli
    signal-desktop
    pavucontrol
    transmission-qt
    sqlitebrowser

    # browsing and media
    qutebrowser firefox chromium
    mpv mupdf feh

    # wayland
    fuzzel swaybg wl-clipboard

    # misc
    xdg-utils
  ];

}
