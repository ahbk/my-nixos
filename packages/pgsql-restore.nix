{
  writeShellApplication,
  postgresql,
  gnugrep,
  coreutils,
  ...
}:
writeShellApplication {
  name = "pgsql-restore";
  runtimeInputs = [
    postgresql
    gnugrep
    coreutils
  ];
  text = builtins.readFile ../tools/session/pgsql-restore.sh;
}
