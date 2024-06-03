let
  key = protocol: hostname: builtins.readFile ./keys/${protocol}-${hostname}.pub;
in {

  stationary = rec {
    name = "stationary";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.1";
    publicAddress = "stationary.ahbk.se";
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  laptop = rec {
    name = "laptop";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.2";
    system = "x86_64-linux";
    stateVersion ="23.11";
  };
  
  glesys = rec {
    name = "glesys";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.3";
    publicAddress = "ahbk.se";
    system = "x86_64-linux";
    stateVersion ="23.11";
  };

  phone = rec {
    name = "phone";
    wgKey = key "wg" name;
    system = "aarch64-linux";
    address = "10.0.0.4";
  };

  container = rec {
    name = "container";
    sshKey = key "ssh-host" name;
    address = "10.0.0.5";
    system = "x86_64-linux";
    stateVersion = "24.05";
  };

}
