{ user, isHM, ...}: let
  hm = {
    programs.git = {
      enable = true;
      userName = "Alexander Holmbäck";
      userEmail = "alexander.holmback@gmail.com";
    };
  };
in if isHM then hm else {
  home-manager.users.${user} = hm;
}
