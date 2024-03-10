ahbk: user: cfg: { config, pkgs, ... }: {
  home.packages = with pkgs; [ 
    inkscape
    figma-linux
    krita
  ];
}
