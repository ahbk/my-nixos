# subnets.nix
{
  wg0 = rec {
    enable = true;
    address = "10.0.0.0/24";
    port = 51820;
    keepalive = 25;
    gateway = "helsinki";
    namespace = "km";
    dns = [ "helsinki" ];
    resetOnRebuild = true;
    peerAddress = host: "10.0.0.${toString host.id}";
    fqdn = hostname: "${hostname}.${namespace}";
  };

  wg1 = rec {
    enable = true;
    address = "10.0.1.0/24";
    port = 51821;
    keepalive = 25;
    gateway = "stationary";
    namespace = "km1";
    dns = [ "stationary" ];
    resetOnRebuild = true;
    peerAddress = host: "10.0.1.${toString host.id}";
    fqdn = hostname: "${hostname}.${namespace}";
  };
}
