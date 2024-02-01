{ inputs, ...}: {
  imports = [
    ./django.nix
    ./fastapi.nix
    ./svelte.nix
    ./wordpress.nix
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "alxhbk@proton.me";
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  services.nginx.virtualHosts."_" = {
    default = true;
    locations."/" = {
      return = "444";
    };
  };

  ahbk.wordpress.sites."esse.test" = {
    enable = true;
    ssl = false;
  };

  ahbk.fastapi.sites."sverigesval.test" = {
    enable = true;
    location = "api/";
    port = "2000";
    ssl = false;
    pkgs = inputs.sverigesval.django;
  };

  ahbk.svelte.sites."sverigesval.test" = {
    enable = true;
    port = "2001";
    ssl = false;
    pkgs = inputs.sverigesval.svelte;
    api = {
      port = "2000";
      location = "api/";
    };
  };

  ahbk.django.sites."chatddx.test" = {
    enable = true;
    port = "2002";
    ssl = false;
    pkgs = inputs.chatddx.django;
  };

  ahbk.svelte.sites."chatddx.test" = {
    enable = true;
    port = "2003";
    ssl = false;
    pkgs = inputs.chatddx.svelte;
    api = {
      port = "2002";
      location = "api/";
    };
  };
}
