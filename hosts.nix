{
  stationary = {
    name = "stationary";
    class = "webserver";
    hostname = "stationary.km";
    publicAddress = "stationary.kompismoln.se";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 1;
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  laptop = {
    name = "laptop";
    class = "peer";
    hostname = "laptop.km";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 2;
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  glesys = {
    name = "glesys";
    class = "webserver";
    hostname = "glesys.km";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 3;
    publicAddress = "ahbk.se";
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  phone = {
    name = "phone";
    class = "null";
    hostname = "phone.km";
    system = "aarch64-linux";
    subnets = [
      "wg0"
    ];
    peerId = 4;
  };

  helsinki = {
    name = "helsinki";
    class = "webserver";
    hostname = "helsinki.km";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 5;
    publicAddress = "helsinki.kompismoln.se";
    system = "x86_64-linux";
    stateVersion = "25.05";
  };

  friday = {
    name = "friday";
    class = "peer";
    hostname = "friday.ahbk";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 6;
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  lenovo = {
    name = "lenovo";
    class = "workstation";
    hostname = "lenovo.ahbk";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 7;
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  adele = {
    name = "adele";
    class = "workstation";
    hostname = "adele.km";
    subnets = [
      "wg0"
      "wg1"
    ];
    peerId = 8;
    system = "x86_64-linux";
    stateVersion = "25.11";
  };

  bootstrap = {
    name = "bootstrap";
    class = "null";
    hostname = "bootstrap.km";
    system = "x86_64-linux";
    stateVersion = "25.11";
    subnets = [
      "wg0"
    ];
    peerId = 254;
  };
}
