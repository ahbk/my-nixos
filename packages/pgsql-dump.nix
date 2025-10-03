{
  writeShellApplication,
  postgresql,
  gnugrep,
  coreutils,
  ...
}:
writeShellApplication {
  name = "pgsql-dump";
  runtimeInputs = [
    postgresql
    gnugrep
    coreutils
  ];
  text = builtins.readFile ../tools/session/pgsql-dump.sh;
}
