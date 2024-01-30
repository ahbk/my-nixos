{ pkgs, user, ...}: {

  environment.systemPackages = with pkgs; [
    transmission-qt
  ];
  users.users.${user}.extraGroups = [ "transmission" ];
}
