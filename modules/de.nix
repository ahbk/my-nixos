{ lib, config, pkgs, ... }: with lib;
let
  cfg = config.ahbk.de;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options.enable = mkEnableOption (mdDoc "Configure IDE for this user") // {
      default = true;
    };
  };

  hm = import ./de-hm.nix;
in {
  options.ahbk.de = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (eachUser != {}) {
    home-manager.users = mapAttrs (hm config.ahbk) eachUser;
    users.users = mapAttrs (user: cfg: { extraGroups = [ "audio" "transmission" "networkmanager" ]; }) eachUser;

    fonts.packages = with pkgs; [
      source-code-pro
      hackgen-nf-font
    ];

    networking.networkmanager.enable = true;

    programs.hyprland = {
      enable = true;
      xwayland.enable = false;
    };

    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      transmission-qt
      xdg-utils
    ];

    security.polkit.enable = true;

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

    xdg.mime.defaultApplications = {
      "text/*" = "nvim.desktop";
      "image/*" = "feh.desktop";
      "video/*" = "mpv.desktop";
      "audio/*" = "mpv.desktop";
      "application/pdf" = "mupdf.desktop";
      "application/x-bittorrent" = "transmission-qt.desktop";
      "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/magnet" = "transmission-qt.desktop";
    };
  };
}
