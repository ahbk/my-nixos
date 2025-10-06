{ inputs }:

final: prev: {
  km-tools = final.callPackage ../packages/km-tools.nix { inherit inputs; };
}
