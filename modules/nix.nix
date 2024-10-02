{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkDefault mkForce;
in
{
  nix = {
    package = mkDefault pkgs.lix;
    registry = {
      self.flake = inputs.self;
      my-nixos = {
        from = {
          id = "my-nixos";
          type = "indirect";
        };
        to = {
          owner = "ahbk";
          repo = "my-nixos";
          type = "github";
        };
      };
      nixpkgs.flake = inputs.nixpkgs;
    };
    channel.enable = false;
    settings = {
      auto-optimise-store = false;
      bash-prompt-prefix = "(nix:$name)\\040";
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = "auto";
      nix-path = mkForce "nixpkgs=/etc/nix/inputs/nixpkgs";
      substituters = [
        "https://cache.nixos.org"
        "https://cache.lix.systems"
      ];
      trusted-users = [ "@wheel" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
      ];
      use-xdg-base-directories = true;
    };
  };
  environment.etc."nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";
}
