let
  key = protocol: hostname: builtins.readFile ./keys/${protocol}-${hostname}.pub;
in {
  stationary = rec {
    name = "stationary";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.1";
    publicAddress = "stationary.ahbk.se";
    stateVersion ="20.03";
  };
  laptop = rec {
    name = "laptop";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.2";
    stateVersion ="23.11";
  };
  glesys = rec {
    name = "glesys";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.3";
    publicAddress = "ahbk.se";
    stateVersion ="23.11";
  };
  phone = rec {
    name = "phone";
    wgKey = key "wg" name;
    address = "10.0.0.4";
  };
}
