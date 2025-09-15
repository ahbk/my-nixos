{
  stationary = {
    name = "stationary";
    class = "webserver";
    hostname = "stationary.km";
    address = "10.0.0.1";
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  laptop = {
    name = "laptop";
    class = "peer";
    hostname = "laptop.km";
    address = "10.0.0.2";
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  glesys = {
    name = "glesys";
    class = "webserver";
    hostname = "glesys.km";
    address = "10.0.0.3";
    system = "x86_64-linux";
    stateVersion = "23.11";
  };

  phone = {
    name = "phone";
    class = "null";
    hostname = "phone.km";
    system = "aarch64-linux";
    address = "10.0.0.4";
  };

  helsinki = {
    name = "helsinki";
    class = "webserver";
    hostname = "helsinki.km";
    address = "10.0.0.5";
    publicAddress = "helsinki.kompismoln.se";
    system = "x86_64-linux";
    stateVersion = "25.05";
  };

  friday = {
    name = "friday";
    class = "peer";
    hostname = "friday.ahbk";
    address = "10.0.0.6";
    system = "x86_64-linux";
    stateVersion = "20.03";
  };

  lenovo = {
    name = "lenovo";
    class = "workstation";
    hostname = "lenovo.ahbk";
    address = "10.0.0.7";
    system = "x86_64-linux";
    stateVersion = "24.11";
  };

  adele = {
    name = "adele";
    class = "peer";
    hostname = "adele.km";
    address = "10.0.0.8";
    system = "x86_64-linux";
    stateVersion = "25.11";
  };

  bootstrap = {
    name = "iso";
    class = "base";
    hostname = "iso";
    system = "x86_64-linux";
    stateVersion = "25.11";
    address = "10.0.0.254";
  };
}
