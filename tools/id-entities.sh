#!/usr/bin/env bash
# id-entities.sh

# shellcheck disable=SC2317,SC2030,SC2031,SC2016,SC2015,SC2029
#
# SC2317: This script has a dispatcher that makes dynamic calls to functions
# that shellcheck believes are unreachable, so we disable this check globally.
#
# SC2030/31: The exported variables (see below) are affected by indirect calls
# with altered context (e.g. var=new-value command). This may be an
# anti-pattern, but it's not accidental, so we mute these warnings.
#
# SC2015: Got it, A && B || C is not if/then/else
# SC2029: Noted, double qoutes in ssh commands expand client side

# === section 0: setup

set -euo pipefail

declare -x doas class entity action key
declare -g slot

declare -A allowed_keys=(
    ["root"]="age-key"
    ["host"]="age-key ssh-key wg-key luks-key"
    ["service"]="age-key ssh-key"
    ["user"]="age-key ssh-key passwd mail"
    ["domain"]="age-key tls-cert"
)

declare -x here
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$here/run-with.bash"
. "$here/sops-yaml.sh"

main() {
    setup "$@" && run "$action"
    sync
    log success "$action $key for $(id) completed."
}

setup() {
    [[ -n ${1:-} ]] || die 1 "hello! try --help" usage

    case "$1" in
    -r | --root) class="root" ;;
    -h | --host) class="host" ;;
    -u | --user) class="user" ;;
    -d | --domain) class="domain" ;;
    -s | --service) class="service" ;;
    -H | --help) class="help" ;;
    *)
        if IFS='-' read -r class entity < <(autocomplete-identity "$1"); then
            shift
            set -- "$entity" "$@"
            set -- "$class" "$@"
        fi
        ;;
    esac

    case ${class:-} in
    root | host | user | domain | service)
        entity=${2:?"entity name required"}
        action=${3:?"action is required"}
        key=${4-"age-key"}
        slot=${5:-0}
        check-input
        ;;
    help)
        less "$here/id-entities-usage.txt"
        exit 0
        ;;
    *)
        die 1 "'$1' is not a valid command." usage
        ;;
    esac

    [[ -f ".sops.yaml" ]] || create-sops-yaml
    check-backend
    check-doas
}

check-input() {
    fn-match "$action:" ||
        die 1 "'$action' is not a valid action"

    [[ " ${allowed_keys[$class]} " == *" $key "* ]] ||
        die 1 "$key not allowed for $class, allowed keys: ${allowed_keys[$class]}"
}

check-backend() {
    with backend_path

    [[ $action == "init" && -f "$backend_path" ]] &&
        die 1 "can't init '$entity', '$backend_path' already exists."

    [[ $class == "root" || $action == "init" || -f "$backend_path" ]] ||
        die 1 "'$backend_path' doesn't exist, did you spell $class correctly?"
}

check-doas() {
    # first root need not be checked, as it has nothing to be checked against
    [[ "$action-$(id)" != "init-root-1" ]] || return 0

    doas=$(age-keygen -y <"$SOPS_AGE_KEY_FILE" | find-identity) ||
        die 1 "no identity found in '$SOPS_AGE_KEY_FILE'"

    log important "$doas"
}

# === section 1: dispatchables

# --- init:*:*

init::() {
    with secret_seed secret_path backend_path

    if [[ -s "$secret_seed" ]]; then
        cat "$secret_seed" >"$secret_path"
    else
        run create-secret >"$secret_path"
    fi

    upsert-identity
    mkdir -p "$(dirname "$backend_path")"
    create-sops-backend "$backend_path"
    run new
}

init:root:age-key() {
    run new-secret
    upsert-identity
}

# --- new:*:*
# --- new-secret:*:*

new::() { run new-secret align; }

new:root:age-key() {
    run new-secret
    upsert-identity
}

new:host:ssh-key() {
    run new-secret align-public
    log warning "public ssh keys will be overwritten by host scans on align"
}

new:host:luks-key() { run new-secret; }

new-secret::age-key() {
    [[ "$(id)" != "${doas:-}" ]] ||
        die 1 "entities are not allowed to rotate their own identity"
    new-secret::
}

new-secret::() {
    with secret_seed

    if [[ -s "$secret_seed" ]]; then
        run encrypt <"$secret_seed"
    else
        run create-secret | run encrypt
    fi
}

# --- create-secret:*:*

create-secret::age-key() {
    age-keygen 2> >(log info) | tail -1
}

create-secret::ssh-key() {
    local s
    s=$(mktemp "$tmpdir/XXXXXX") && rm "$s"
    try ssh-keygen -t "ed25519" -f "$s" -N "" -C "$(id)" > >(log info)
    cat "$s"
}

create-secret::wg-key() { try wg genkey; }
create-secret::luks-key() { try passphrase 12; }
create-secret::tls-cert() { try openssl genpkey -algorithm ED25519; }
create-secret::passwd() { try passphrase 8; }
create-secret::mail() { try passphrase 8; }

# --- derive-public:*:*

derive-public::age-key() { run cat-secret | try age-keygen -y; }
derive-public::wg-key() { run cat-secret | try wg pubkey; }

derive-public::ssh-key() {
    with secret_file
    try ssh-keygen -y -C "" -f "$secret_file"
}

derive-public::tls-cert() {
    run cat-secret | try openssl req -new -x509 -key /dev/stdin \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

# --- validate:*:*
# --- validate-[sha512|passphrase]:*:*

validate::() {
    with secret_file
    trailing-newline "$secret_file" && derived_public_file >/dev/null
}

validate::luks-key() { run validate-passphrase; }
validate::passwd() { run validate-passphrase; }
validate::mail() { run validate-passphrase; }
validate::passwd-sha512() { run validate-sha512; }
validate::mail-sha512() { run validate-sha512; }

validate-sha512::() {
    run-with cat-secret
    [[ "$cat_secret__" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

validate-passphrase::() {
    with secret_file
    local min_length=6

    ! trailing-newline "$secret_file" ||
        die 1 "'$secret_file' has trailing newline"

    [[ $(wc -m <"$secret_file") -ge "$min_length" ]] ||
        die 1 "'$(cat "$secret_file")' is shorter than $min_length chars"
}

# --- verify:*:*
# --- verify-[public|identity|host|sha512]:*:*

verify::age-key() { run verify-identity; }
verify::wg-key() { run verify-public; }
verify:host:luks-key() { run verify-host; }
verify:service:ssh-key() { run verify-public; }
verify:user:ssh-key() { run verify-public; }
verify:user:passwd() { run verify-sha512; }
verify:user:mail() { run verify-sha512; }

verify:host:age-key() {
    run verify-identity
    run verify-host
}

verify:host:ssh-key() {
    with public_file
    scan:host:ssh-key | try diff - "$public_file"
}

verify:domain:tls-cert() {
    with public_file secret_file

    try openssl x509 -in "$public_file" -checkend 2592000

    openssl x509 -in "$public_file" -noout -ext subjectAltName |
        try grep -q "DNS:$entity"

    openssl pkey -in "$secret_file" -pubout |
        try diff - <(openssl x509 -in "$public_file" -pubkey -noout)
}

verify-identity::() {
    with derived_public_file
    get-identity | try diff "$derived_public_file" -
}

verify-public::() {
    with derived_public_file public_file
    try diff "$derived_public_file" "$public_file"
}

verify-host::() {
    with base64_secret
    locksmith "$key" "$base64_secret"
}

verify-sha512::() {
    key=$key-sha512 with secret_file
    run sha512-secret | try diff - "$secret_file"
}

# --- align:*:*
# --- align-[public|sha512]:*:*

align::age-key() { upsert-identity; }
align::wg-key() { run align-public; }
align::tls-cert() { run align-public; }
align:service:ssh-key() { run align-public; }
align:user:ssh-key() { run align-public; }
align:user:passwd() { run align-sha512; }
align:user:mail() { run align-sha512; }

align:host:ssh-key() {
    with public_path
    scan:host:ssh-key >"$public_path"
}

align-public::() {
    with public_path
    run derive-public >"$public_path"
}

align-sha512::() {
    run sha512-secret | key=$key-sha512 run encrypt
}

# --- [encrypt|decrypt|unset]:*:*

encrypt::() {
    with secret_path
    cat >"$secret_path"
    run validate

    with backend_path backend_component json_secret
    try sops set "$backend_path" "$backend_component" "$json_secret"
}

encrypt:root:() {
    with secret_path backend_path
    cat >"$secret_path"
    run validate
    try cp -a "$secret_path" "$backend_path"
}

decrypt::() {
    with backend_path backend_component
    try sops decrypt --extract "$backend_component" "$backend_path"
}

decrypt:root:() {
    with backend_path
    try cat "$backend_path"
}

unset::() {
    with backend_path backend_component
    try sops unset "$backend_path" "$backend_component"
}

# --- rebuild:*:*

rebuild::() {
    try rebuild-creation-rules
    [[ $class != "root" ]] || return 0

    with backend_path
    sops updatekeys -y "$backend_path" \
        > >(log important) \
        2> >(grep "synced with" | log info) || true
}

# --- scan:*:*

scan:host:ssh-key() {
    with fqdn
    try ssh-keyscan -q "$fqdn" | awk '{print $2, $3}'
}

# --- sideload:*:*

sideload:host:luks-key() {
    with secret_seed
    local new_base64_secret

    if secret_file | cmp -s - "$secret_seed"; then
        run base64-secret new base64-secret | locksmith "$key"
        return
    fi

    with base64_secret next_slot
    new_base64_secret=$(
        slot=$next_slot
        run new base64-secret
    )

    printf '%s\n%s\n' "$base64_secret" "$new_base64_secret" | locksmith "$key"
}

sideload:host:age-key() {
    run verify-identity
    run base64-secret new base64-secret | locksmith "$key"
}

# --- cat-[secret|public]:*:*

cat-secret::() {
    with secret_file
    cat "$secret_file"
}

cat-public::() {
    with public_file
    cat "$public_file"
}

# --- proxies (lazy variables exposed as actions)

next-slot::() { proxy next_slot; }
base64-secret::() { proxy base64_secret; }
json-secret::() { proxy json_secret; }
sha512-secret::() { proxy sha512_secret; }

# === section 2: lazy variables

callchain() {
    cat <<EOF
$action:$class:$key
$action:$class:
$action::$key
$action::
EOF
}

id() { echo "$class-$entity"; }

secret_path() {
    with exact_key
    local s=$tmpdir/$class.$entity.$exact_key.secret
    [[ -f "$s" ]] || {
        touch "$s"
        chmod 600 "$s"
    }
    echo "$s"
}

secret_file() {
    with secret_path
    [[ -s $secret_path ]] || run decrypt >"$secret_path"
    echo "$secret_path"
}

public_path() {
    read-setting "public:$key"
}

public_file() {
    with public_path
    try test -f "$public_path"
    echo "$public_path"
}

derived_public_file() {
    local f="$tmpdir/$class.$entity.$key.public"
    [[ -f $f ]] || run derive-public >"$f"
    echo "$f"
}

secret_seed() {
    local f=$tmpdir/secret_seed

    [[ -f "$f" ]] || {
        touch "$f"
        [[ -r ${SECRET_SEED:-} ]] &&
            cat "$SECRET_SEED" >"$f"
    }
    echo "$f"
}

backend_path() {
    search-setting "backend:$class backend"
}

exact_key() {
    local exact_key=$key
    [[ "$slot" == "0" ]] || exact_key+="--$slot"
    echo "$exact_key"
}

backend_component() {
    with exact_key
    local c="['$exact_key']"
    [[ $class == "host" ]] || c="['$entity']$c"
    echo "$c"
}

fqdn() {
    read-setting "fqdn"
}

passphrase() {
    local length=${1:-12}
    openssl rand -base64 "$length" | tr -d '\n'
}

next_slot() {
    for ((slot = 0; ; slot++)); do
        (slot="$slot" with secret_file) || {
            echo "$slot"
            return
        }
    done
}

base64_secret() {
    run cat-secret | try base64 -w0
}

json_secret() {
    run cat-secret | try jq -Rs
}

sha512_secret() {
    local salt
    salt=$(key=$key-sha512 run cat-secret | awk -F'$' '{print $3}') || salt=""
    run cat-secret | mkpasswd -sm sha-512 -S "$salt"
}

# declarations of all lazy variables to satisfy shellcheck
declare -g \
    backend_path \
    backend_component \
    secret_path \
    secret_file \
    public_path \
    public_file \
    derived_public_file \
    secret_seed \
    fqdn \
    base64_secret \
    json_secret \
    exact_key \
    next_slot \
    cat_secret__

# --- misc helpers

usage() {
    sed -n '/^SYNOPSIS$/,/^$/p' "$here/id-entities-usage.txt"
}

locksmith() {
    with fqdn
    local payload=${2:-$(cat)}

    log debug "payload:"$'\n'"$payload"

    eval "$(ssh-agent -s)" >/dev/null
    trap 'ssh-agent -k >/dev/null 2>&1' EXIT
    (
        class=service
        entity=locksmith
        key=ssh-key
        slot=0
        run cat-secret
    ) | ssh-add - 2>/dev/null

    echo "$payload" | ssh "locksmith@$fqdn" "$1" \
        > >(log info) \
        2> >(log error) || die
}

# --- main
main "$@"
