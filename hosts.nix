let
  key = protocol: name: builtins.readFile ./keys/${protocol}-${name}.pub;
in
{

  stationary = rec {
    name = "stationary";
    hostname = "stationary.ahbk";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.1";
    publicAddress = "stationary.ahbk.se";
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  laptop = rec {
    name = "laptop";
    hostname = "laptop.ahbk";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.2";
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  glesys = rec {
    name = "glesys";
    hostname = "glesys.ahbk";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.3";
    publicAddress = "ahbk.se";
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  friday = rec {
    name = "friday";
    hostname = "friday.ahbk";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.6";
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  lenovo = rec {
    name = "lenovo";
    hostname = "lenovo.ahbk";
    wgKey = key "wg" name;
    sshKey = key "ssh-host" name;
    address = "10.0.0.7";
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  phone = rec {
    name = "phone";
    hostname = "phone.ahbk";
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
