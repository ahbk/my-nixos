{ user, isHM, ...}: let
  hm = {
    programs.tmux = {
      enable = true;
      terminal = "screen-256color";
      keyMode = "vi";
      escapeTime = 10;
      extraConfig = (builtins.readFile ./tmux.conf);
    };
  };
in if isHM then hm else {
  home-manager.users.${user} = hm;
}
