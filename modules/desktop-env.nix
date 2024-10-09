{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    flatten
    types
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    ;

  cfg = config.my-nixos.desktop-env;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;
  eachHMUser = filterAttrs (user: cfg: config.my-nixos.hm.${user}.enable) eachUser;

  userOpts = {
    options.enable = mkEnableOption "desktop environment for this user";
  };
in
{
  options.my-nixos.desktop-env = mkOption {
    type = types.attrsOf (types.submodule userOpts);
    description = "Definition of per-user desktop environment.";
    default = { };
  };

  config = mkIf (eachUser != { }) {

    home-manager.users = mapAttrs (user: cfg: {
      my-nixos-hm.desktop-env = {
        enable = true;
      };
    }) eachHMUser;

    users.users = mapAttrs (user: cfg: {
      extraGroups = [
        "audio"
        "transmission"
        "networkmanager"
      ];
    }) eachUser;

    services.restic.backups.local.paths = flatten (
      mapAttrsToList (user: cfg: [ "/home/${user}/.local/share/qutebrowser/history.sqlite" ]) eachUser
    );

    fonts.packages = with pkgs; [
      source-code-pro
      hackgen-nf-font
    ];

    networking.networkmanager.enable = true;

    programs.hyprland = {
      enable = true;
    };

    security = {
      rtkit.enable = true;
      polkit.enable = true;
    };

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

    environment.sessionVariables = rec {
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      XDG_BIN_HOME = "$HOME/.local/bin";
      PATH = [ "${XDG_BIN_HOME}" ];
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
      "message/rfc88" = "thunderbird.desktop";
      "application/x-email" = "thunderbird.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
    };
  };
}
