# hosts.nix
{
  stationary = {
    id = 1;
    class = "webserver";
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
    class = "peer";
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  phone = {
    id = 4;
    class = "null";
    subnets = [
      "wg0"
    ];
    system = "aarch64-linux";
    stateVersion = null;
  };

  helsinki = {
    id = 5;
    class = "webserver";
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
    class = "peer";
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  lenovo = {
    id = 7;
    class = "workstation";
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  adele = {
    id = 8;
    class = "workstation";
    subnets = [
      "wg0"
      "wg1"
    ];
    system = "x86_64-linux";
    stateVersion = "25.11";
  };

  bootstrap = {
    id = 254;
    class = "null";
    subnets = [
      "wg0"
    ];
    system = "x86_64-linux";
    stateVersion = "25.11";
  };
}
