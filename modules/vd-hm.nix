ahbk: user: cfg: { config, pkgs, lib, ... }: {
  config = lib.mkIf cfg.enable {
  home.packages = with pkgs; [ 
    inkscape
    figma-linux
    krita
  ];
};
}
