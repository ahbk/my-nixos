# hosts/index.nix
{
  stationary = {
    id = 1;
    roles = [ "webserver" ];
    endpoint = "stationary.kompismoln.se";
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  laptop = {
    id = 2;
    roles = [ "peer" ];
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  phone = {
    id = 4;
    subnets = [
      "wg0"
    ];
    system = "aarch64-linux";
    stateVersion = null;
  };

  helsinki = {
    id = 5;
    roles = [
      "webserver"
      "mailserver"
    ];
    endpoint = "helsinki.kompismoln.se";
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "25.05";
  };

  friday = {
    id = 6;
    roles = [ "peer" ];
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  lenovo = {
    id = 7;
    roles = [ "workstation" ];
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  adele = {
    id = 8;
    roles = [ "workstation" ];
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "25.11";
  };

  bootstrap = {
    id = 254;
    subnets = [
      "wg0"
    ];
    system = "x86_64-linux";
    stateVersion = "25.11";
  };
}
