{ user, ... }: {
  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    extraGroups = [ "wheel" ];
    initialPassword = "a";
  };
}
