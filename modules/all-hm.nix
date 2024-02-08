ahbk: user: cfg: { inputs, ... }: {
  imports = [
    (import ./user-hm.nix ahbk user cfg)
    (import ./ide-hm.nix ahbk user cfg)
    (import ./shell-hm.nix ahbk user cfg)
  ];
}
