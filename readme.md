# A NixOS system flake
This flake configures my laptop, my stationary, a public host at glesys and a debian container.
The module structure is similar to NixOS' and adds a new set of options under `ahbk`.

> :warning: **Warning for very new NixOS users:**
Do not directly clone or fork this repository!
It's at best for inspiration and learning.
Read through the configurations and selectively copy-paste the parts that suit your setup.

> :bulb: **Notice to moderately new NixOS users:**
This repository serves as an example of how to utilize configurable modules with a custom set of options.
However, the canonical source of inspiration should always be the NixOS modules available at [github.com/NixOS/nixpkgs](https://github.com/NixOS/nixpkgs).
Consider this repository a condensed sample to illustrate how NixOS modules work.
For comprehensive understanding and best practices, refer directly to the nixpkgs repository.

That said, here comes a selection of what's going on in this repo that, for various reasons, is not available in nixpkgs:
- Non-mutable user setup with straightforward [agenix](https://github.com/ryantm/agenix) password management.
- A [Home-manager](https://github.com/nix-community/home-manager) setup that integrates with both NixOS and non-NixOS systems.
- Modules for deploying Django, SvelteKit, FastAPI, and WordPress.
- A working setup for the latest Odoo (version 17), an open source ERP system.
- The broken and unsafe wkthmltopdf package safely contained in [nixpak](https://github.com/nixpak/nixpak)

Feel free to incorporate whatever fits your NixOS setup!
