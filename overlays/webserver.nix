{ inputs }:

final: prev: {
  pgsql-restore = final.callPackage ../packages/pgsql-restore.nix { inherit inputs; };
  pgsql-dump = final.callPackage ../packages/pgsql-dump.nix { inherit inputs; };
}
