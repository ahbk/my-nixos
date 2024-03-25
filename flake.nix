{
  description = "my system";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    nixpak.url = "github:nixpak/nixpak";
    nixpak.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";

    # wkhtmltopdf is broken and unsafe, this is the context for running wkhtmltopdf as a nixpak
    nixpkgs-wkhtmltopdf.url = "github:NixOS/nixpkgs/c8d822252b86022a71dcc4f0f48bc869ef446401";
    nixpkgs-wkhtmltopdf.flake = false;

  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # custom packages not found in nixpkgs.pkgs
    pkgs' = import ./packages/all.nix { inherit pkgs; };

    # custom library functions not found in nixpkgs.lib
    lib' = import ./lib.nix {
      inherit (nixpkgs) lib;
      inherit pkgs;
    };

    # chunks of reusable configuration snippets
    ahbk = import ./ahbk.nix { inherit inputs system; };

  in with nixpkgs.lib; {
    homeConfigurations = mapAttrs' (user: cfg: (
      nameValuePair "${user}@debian" (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs system; };
      modules = [ (import ./modules/all-hm.nix cfg user null) ];
      }))) {
        frans = with ahbk; {
          user.frans = user.frans;
          ide.frans.enable = true;
          shell.frans.enable = true;
        };
      };

    nixosConfigurations = rec {

      # nixos@10.233.2.2 for testing
      # nixos-container create test --flake ~/Desktop/nixos
      container = test;
      test = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib' ahbk; };
        modules = with ahbk; [
          ./hardware/container.nix
          ./modules/all.nix
          {
            ahbk = {
              user.frans = user.frans;
              ide.frans.enable = true;
              shell.frans.enable = true;
            };

            system.stateVersion = "23.11";
            networking.hostName = "test";
          }
        ];
      };

      laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib'; };
        modules = with ahbk; [
          ./hardware/laptop.nix
          ./modules/all.nix
          {
            ahbk = {
              user.alex = user.alex;
              user.frans = user.frans;
              shell.frans.enable = true;
              ide.frans.enable = true;
              de.frans.enable = true;
              vd.frans.enable = true;

              laptop.enable = true;
            };

            system.stateVersion = "23.11";

            networking = {
              hostName = "laptop";
              nat = {
                enable = true;
                internalInterfaces = ["ve-+"];
                externalInterface = "wlp1s0";
              };
              networkmanager.unmanaged = [ "interface-name:ve-*" ];
              firewall.allowedTCPPorts = [ 3000 5173 8000 ];
            };

            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            swapDevices = [
              {
                device = "/swapfile";
                size = 8192;
              }
            ];

            services.dnsmasq = {
              enable = true;
              settings.address = "/.test/10.233.1.2";
            };

            # hw quirk: wrong keycode for pipe |
            systemd.services.pipefix = {
              wantedBy = [ "multi-user.target" ];
              after = [ "nix-daemon.socket" ];
              before = [ "systemd-user-sessions.service" ];
              script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
            };
          }
        ];
      };

      glesys = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib'; };
        modules = [
          ./hardware/glesys.nix
          ./modules/all.nix
          {
            networking.hostName = "glesys";
            system.stateVersion = "23.11";

            ahbk = with ahbk; {
              user.frans = user.frans;
              ide.frans = ide.frans;
              shell.frans = shell.frans;

              nginx = {
                enable = true;
                email = user.frans.email;
              };

              inherit chatddx sverigesval;
              wordpress.sites."esse.nu" = wordpress.sites."esse.nu";
            };

            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            swapDevices = [
              {
                device = "/swapfile";
                size = 4096;
              }
            ];
          }
        ];
      };

      stationary = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib' pkgs'; };
        modules = [
          ./hardware/stationary.nix
          ./modules/all.nix
          ({ config, pkgs', ... }: {
            networking.hostName = "stationary";
            system.stateVersion = "20.03";
            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            ahbk = with ahbk; {
              user.frans = user.frans;
              shell.frans = shell.frans;
              ide.frans = ide.frans;

              nginx = {
                enable = true;
                email = user.frans.email;
              };

              odoo = {
                enable = true;
                package = pkgs'.odoo;
                ssl = true;
                domain = "ahbk.ddns.net";
                settings = {
                  options = {
                    db_user = "odoo";
                    db_name = "odoo";
                  };
                };
              };

              inadyn = {
                enable = true;
                providers."default@noip.com" = {
                  username = "alexander.holmback@gmail.com";
                  hostname = "ahbk.ddns.net";
                  passwordFile = config.age.secrets."ddns-password".path;
                };
              };

              wordpress.sites."test.esse.nu" = wordpress.sites."test.esse.nu";
            };

            age.secrets."ddns-password".file = ./secrets/ddns-password.age;

          })
        ];
      };
    };
  };
}
