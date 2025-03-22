{ fetchFromGitHub }:
rec {

  pname = "mobilizon";
  version = "5.1.1";

  src = fetchFromGitHub {
    owner = "Kompismoln";
    repo = pname;
    rev = "main";
    sha256 = "sha256-KbWBsTuzLfD0nrDiJ0zff8T2pNzHaNW+5Kq8nVUc35Q=";
  };
}
