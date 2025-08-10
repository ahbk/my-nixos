let
  key = host: type: builtins.readFile ./keys/${host}-${type}.pub;
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
    wgKey = key name "wg-key";
    sshKey = key name "ssh-host-key";
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

  phone = rec {
    name = "phone";
    hostname = "phone.ahbk";
    wgKey = key "wg" name;
    system = "aarch64-linux";
    address = "10.0.0.4";
  };

  helsinki = rec {
    name = "helsinki";
    hostname = "helsinki.ahbk";
    wgKey = key name "wg-key";
    sshKey = key name "ssh-host-key";
    address = "10.0.0.5";
    publicAddress = "helsinki.kompismoln.se";
    system = "x86_64-linux";
    stateVersion = "25.05";
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
    wgKey = key name "wg-key";
    sshKey = key name "ssh-host-key";
    address = "10.0.0.7";
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  container = rec {
    name = "container";
    sshKey = key "ssh-host" name;
    address = "10.0.0.254";
    system = "x86_64-linux";
    stateVersion = "24.05";
  };

}
