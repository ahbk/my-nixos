{ fetchFromGitHub }:
rec {

  pname = "mobilizon";
  version = "5.1.1";

  src = fetchFromGitHub {
    owner = "Kompismoln";
    repo = pname;
    rev = "main";
    sha256 = "sha256-JpEKgo3CjfX7G5NljRNuSYhDfBtUrDX8oQwrzhJX89Y=";
  };
}
