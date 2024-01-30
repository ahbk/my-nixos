{ user, ... }: {
  home-manager.users.${user} = {
    programs.foot = {
      enable = true;
      settings = {
        main.term = "xterm-256color";
        main.font = "Source Code Pro:size=10";
        main.include = "~/.config/foot/include.ini";
        main.dpi-aware = "yes";
        mouse.hide-when-typing = "yes";
        colors.alpha = .8;
      };
    };
    home.file.".config/foot/include.ini".source = ./foot.ini;
  };
}
