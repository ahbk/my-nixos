{
  fonts = {
    monospace = "Source Code Pro";
    serif = "Merriweather";
    sans-serif = "Roboto";
  };

  colors = rec {
    base00 = black-900;
    base01 = red-400;
    base02 = green-400;
    base03 = yellow-400;
    base04 = blue-400;
    base05 = purple-400;
    base06 = cyan-400;
    base07 = white-400;

    base08 = black-100;
    base09 = red-500;
    base0A = green-500;
    base0B = yellow-500;
    base0C = blue-500;
    base0D = purple-500;
    base0E = cyan-500;
    base0F = white-300;

    bg-300 = black-600;
    bg-400 = black-700;
    bg-500 = black-800;
    bg-inv = fg-400;

    bg-selected = bg-inv;
    bg-success = green-400;
    bg-disabled = black-400;
    bg-error = red-400;
    bg-warning = yellow-400;
    bg-info = blue-400;

    fg-300 = white-300;
    fg-400 = white-400;
    fg-500 = white-500;
    fg-inv = bg-400;

    fg-selected = fg-inv;
    fg-success = white-400;
    fg-disabled = black-200;
    fg-error = white-400;
    fg-warning = black-700;
    fg-info = white-400;

    fg-match = red-500;
    fg-match-selected = red-500;

    black-100 = "#717C7C"; # katanaGray
    black-200 = "#727169"; # fujiGray
    black-300 = "#54546D"; # sumiInk6
    black-400 = "#363646"; # sumiInk5
    black-500 = "#2A2A37"; # sumiInk4
    black-600 = "#1F1F28"; # sumiInk3
    black-700 = "#1a1a22"; # sumiInk2
    black-800 = "#181820"; # sumiInk1
    black-900 = "#16161D"; # sumiInk0

    red-300 = "#FF5D62"; # peachRed
    red-400 = "#C34043"; # autumnRed
    red-500 = "#E82424"; # samuraiRed

    pink-300 = "#D27E99"; # sakuraPink
    pink-400 = "#E46876"; # waveRed
    pink-500 = "#43242B"; # winterRed

    green-300 = "#98BB6C"; # springGreen
    green-400 = "#76946A"; # autumnGreen
    green-500 = "#2B3328"; # winterGreen

    yellow-300 = "#E6C384"; # carpYellow
    yellow-400 = "#DCA561"; # autumnYellow
    yellow-500 = "#FF9E3B"; # roninYellow

    beige-300 = "#C0A36E"; # boatYellow2
    beige-400 = "#938056"; # boatYellow1
    beige-500 = "#49443C"; # winterYellow

    orange-400 = "#FFA066"; # surimiOrange

    blue-200 = "#A3D4D5"; # lightBlue
    blue-300 = "#7FB4CA"; # springBlue
    blue-400 = "#7E9CD8"; # crystalBlue
    blue-500 = "#2D4F67"; # waveblue2
    blue-600 = "#223249"; # waveBlue1
    blue-700 = "#252535"; # winterBlue

    purple-200 = "#b8b4d0"; # oniViolet2
    purple-300 = "#9CABCA"; # springViolet2
    purple-400 = "#938AA9"; # springViolet1
    purple-500 = "#957FB8"; # oniViolet

    cyan-300 = "#7AA89F"; # waveAqua2
    cyan-400 = "#6A9589"; # waveAqua1
    cyan-500 = "#658594"; # dragonBlue

    white-300 = "#ECE7DA";
    white-400 = "#DCD7BA"; # fujiWhite
    white-500 = "#C8C093"; # oldwhite
  };
}
