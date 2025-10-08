# subnets.nix
{
  wg0 = {
    enable = true;
    address = "10.0.0.0/24";
    port = 51820;
    keepalive = 25;
    gateway = "stationary";
    dns = [ "helsinki" ];
    resetOnRebuild = true;
    peerAddress = peerId: "10.0.0.${toString peerId}";
  };

  wg1 = {
    enable = true;
    address = "10.0.1.0/24";
    port = 51821;
    keepalive = 25;
    gateway = "stationary";
    dns = [ ];
    resetOnRebuild = false;
    peerAddress = peerId: "10.0.1.${toString peerId}";
  };
}
