set -euo pipefail
appname="$1"
stateDir="$2"
pg_dump -U "$appname" "$appname" >"$stateDir/dbdump.sql"
