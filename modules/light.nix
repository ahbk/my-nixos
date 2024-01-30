{ user, ... }: {
  # brightness keys
  programs.light = {
    enable = true;
    brightnessKeys.step = 10;
    brightnessKeys.enable = true;
  };
  #services.actkbd = {
  #  enable = true;
  #  bindings = [
  #    { keys = [ 224 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -U 10"; }
  #    { keys = [ 225 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -A 10"; }
  #  ];
  #};
  #users.users.${user}.extraGroups = [ "video" ];
}
