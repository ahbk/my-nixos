{ lib
, config
, pkgs
, ...
}:

with lib;

let
  cfg = config.ahbk.vd;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options.enable = mkEnableOption (mdDoc "Configure IDE for this user");
  };
in {
  options.ahbk.vd = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (eachUser != {}) {
    home-manager.users = mapAttrs (user: cfg: {
      ahbk-hm.vd.enable = true;
    }) eachUser;

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "helvetica-neue-lt-std"
    ];

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
  };

}
