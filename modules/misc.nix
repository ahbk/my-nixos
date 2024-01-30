{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    signal-desktop
    qutebrowser firefox chromium
    mpv mupdf feh
  ];
}
