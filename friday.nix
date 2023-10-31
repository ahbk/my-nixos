{ inputs, pkgs, config, ... }: {
  imports = [
    ./hardware/friday.nix
    ./common.nix
  ];

  networking.hostName = "friday";

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  # pet projects
  networking = {
    extraHosts = ''
      127.0.0.2 ahbk.local
    '';
    firewall.allowedTCPPorts = [ 5173 8000 ];
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

  # Test instance for ahbk
  users = rec {
    users."ahbk-api" = {
      isSystemUser = true;
      group = "ahbk-api";
      uid = 994;
    };
    groups."ahbk-api".gid = users."ahbk-api".uid;
  };
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    ensureDatabases = [ "ahbk" "frans" ];
    ensureUsers = [
      {
        name = "ahbk-api";
        ensurePermissions = {
          "DATABASE ahbk" = "ALL PRIVILEGES";
        };
      }
      {
        name = "frans";
        ensurePermissions = {
          "DATABASE ahbk" = "ALL PRIVILEGES";
          "DATABASE frans" = "ALL PRIVILEGES";
        };
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

    # browsing and media
    qutebrowser firefox chromium
    mpv mupdf feh

    # wayland
    fuzzel swaybg wl-clipboard

    # misc
    xdg-utils
  ];

}
