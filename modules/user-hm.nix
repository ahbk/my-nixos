ahbk: user: cfg:
{ lib
, ...
}:

{
  programs.home-manager.enable = true;

  programs.ssh = {
    enable = true;
  };

  home = {
    enableNixpkgsReleaseCheck = true;
    stateVersion = "22.11";
    username = user;
    homeDirectory = lib.mkDefault /home/${user};
  };
}
