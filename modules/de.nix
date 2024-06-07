{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my-nixos.de;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options.enable = mkEnableOption "Desktop Environment for this user";
  };
in {
  options.my-nixos.de = with types; mkOption {
    type = attrsOf (submodule userOpts);
    description = "Definition of per-user desktop environment";
    default = {};
  };

  config = mkIf (eachUser != {}) {

    home-manager.users = mapAttrs (user: cfg: {
      my-nixos-hm.de.enable = true;
    }) eachUser;

    users.users = mapAttrs (user: cfg: { extraGroups = [ "audio" "transmission" "networkmanager" ]; }) eachUser;

    my-nixos.backup."stationary".paths = flatten (mapAttrsToList (user: cfg: [
      "/home/${user}/.local/share/qutebrowser/history.sqlite"
    ]) eachUser);

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
      transmission_4-qt
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
      "text/x-lua" = "nvim.desktop";
      "image/*" = "feh.desktop";
      "image/jpeg" = "feh.desktop";
      "video/*" = "mpv.desktop";
      "audio/*" = "mpv.desktop";
      "application/pdf" = "mupdf.desktop";
      "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
    };
  };

}
