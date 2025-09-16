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
# SC2016: Yes, we know expressions wont expand in single quotes.
# SC2029: Noted, double qoutes in ssh commands expand client side

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

# import tmpdir, log, die, try, run, find-first and fn-exists
# shellcheck source=./tools/lib.sh
. "$here/lib.sh"

main() {
    setup "$@" && run "$action"
    sync
    log success "$action $key for $class-$entity completed."
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
    check-input
    check-doas
}

check-input() {
    fn-match "$action:" ||
        die 1 "'$action' is not a valid action"

    [[ $action == "init" && -f "$(backend-file)" ]] &&
        die 1 "can't init '$entity', '$(backend-file)' already exists."

    [[ $class == "root" || $action == "init" || -f "$(backend-file)" ]] ||
        die 1 "'$(backend-file)' doesn't exist, did you spell $class correctly?"

    [[ " ${allowed_keys[$class]} " == *" $key "* ]] ||
        die 1 "$key not allowed for $class, allowed keys: ${allowed_keys[$class]}"
}

check-doas() {
    # first root need not be verified, as it has nothing to be verified against
    [[ "$action-$class-$entity" != "init-root-1" ]] || return 0

    IFS='-' read -r doas < <(age-keygen -y <"$SOPS_AGE_KEY_FILE" | find-identity) ||
        die 1 "no identity found in '$SOPS_AGE_KEY_FILE'"

    log important "$doas"
}

# --- init:*:*

init::() {
    mkdir -p "$(dirname "$(backend-file)")"

    # Almost like new-secret but it writes directly to secret instead of set-secret
    # because set-secret expects a backend that doesn't exist yet.
    if [[ -s "$(seed-secret)" ]]; then
        cat "$(seed-secret)" >"$(secret)"
    else
        create-secret::age-key >"$(secret)"
    fi
    run validate

    upsert-identity
    create-backend
    run encrypt-secret
}

init:root:age-key() {
    run new-secret
    upsert-identity
}

# --- new:*:*

new::() {
    run new-secret align
}

new:root:age-key() {
    [[ "$class-$entity" != "$doas" ]] || die 1 "can't rotate current"
    run new-secret
    upsert-identity
}

new:host:ssh-key() {
    run new-secret
    align-public
    log warning "public ssh keys will be overwritten by host scans on align"
}

new:host:luks-key() {
    run new-secret
}

# --- new-secret:*:*

new-secret::() {
    if [[ -s "$(seed-secret)" ]]; then
        set-secret <"$(seed-secret)"
    else
        run create-secret | set-secret
    fi
}

# --- align:*:*

align::age-key() {
    upsert-identity
}

align::wg-key() {
    align-public
}

align::tls-cert() {
    align-public
}

align:host:ssh-key() {
    scan:host:ssh-key >"$(public-file)"
}

align:service:ssh-key() {
    align-public
}

align:user:ssh-key() {
    align-public
}

align:user:passwd() {
    align-hash::
}

align:user:mail() {
    align-hash::
}

align-public() {
    run derive-public >"$(public-file)"
}

align-hash::() {
    local hash
    read -r _secret < <(get-secret)
    hash=$(mkpasswd -sm sha-512 <"$_secret")
    (
        key=$key-hashed
        echo "$hash" | set-secret
    )
}

# --- verify:*:*

verify::age-key() {
    verify-identity::
}

verify::wg-key() {
    verify-public::
}

verify:host:age-key() {
    verify-identity::
    verify-host::
}

verify:host:ssh-key() {
    scan:host:ssh-key | try diff - "$(public-file)"
}

verify:host:luks-key() {
    verify-host::
}

verify:service:ssh-key() {
    verify-public::
}

verify:user:ssh-key() {
    verify-public::
}

verify:user:passwd() {
    verify-hash::
}

verify:user:mail() {
    verify-hash::
}

verify:domain:tls-cert() {
    local exit_code=0 pub sec
    read -r pub < <(public-file)
    read -r sec < <(get-secret)

    openssl x509 -in "$pub" -checkend 2592000 ||
        exit_code=1

    openssl x509 -in "$pub" -noout -ext subjectAltName |
        grep -q "DNS:$entity" ||
        exit_code=1

    diff \
        <(openssl pkey -in "$sec" -pubout) \
        <(openssl x509 -in "$pub" -pubkey -noout) ||
        exit_code=1

    return "$exit_code"
}

# --- verify-[public|identity|host|hash]:*:*

verify-identity::() {
    assert "$key" "age-key" "age-key only"
    read -r _public < <(test-public)
    get-identity | try diff "$_public" -
}

verify-public::() {
    test-public >/dev/null
    try diff "$(test-public)" "$(public-file)"
}

verify-host::() {
    assert "$class" "host" "hosts only"
    run base64-secret | keyservice "$key"
}

verify-hash::() {
    local salt
    salt=$(
        key=$key-hashed
        cat-secret:: | awk -F'$' '{print $3}'
    )

    try diff \
        <(cat-secret:: | mkpasswd -sm sha-512 -S "$salt") \
        <(key=$key-hashed cat-secret::)
}

# --- scan:*:*

scan:host:ssh-key() {
    ssh-keyscan -q "$(fqdn)" | awk '{print $2, $3}'
}

# --- create-secret:*:*

create-secret::age-key() {
    age-keygen 2> >(log info) | tail -1
}

create-secret::ssh-key() {
    local tmpkey
    tmpkey=$(mktemp -u "$tmpdir/XXXXXX")
    quiet ssh-keygen -q -t "ed25519" -f "$tmpkey" -N "" -C "" <<<y
    cat "$tmpkey"
}

create-secret::wg-key() {
    wg genkey
}

create-secret::luks-key() {
    gen-passwd
}

create-secret::tls-cert() {
    openssl genpkey -algorithm ED25519
}

create-secret::passwd() {
    gen-passwd
}

create-secret::mail() {
    gen-passwd
}

# --- derive-public:*:*

derive-public::age-key() {
    cat-secret:: | try age-keygen -y
}

derive-public::ssh-key() {
    read -r _secret < <(get-secret)
    ssh-keygen -y -C "" -f "$_secret"
}

derive-public::wg-key() {
    cat-secret:: wg pubkey
}

derive-public::tls-cert() {
    cat-secret:: | openssl req -new -x509 -key /dev/stdin \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

# --- validate:*:*

validate::() {
    trailing-newline "$(get-secret)" && test-public >/dev/null
}

validate::luks-key() {
    validate-passphrase::
}

validate::passwd() {
    validate-passphrase::
}

validate::mail() {
    validate-passphrase::
}

validate::passwd-hashed() {
    validate-hash::
}

validate::mail-hashed() {
    validate-hash::
}

validate-hash::() {
    read -r _secret < <(get-secret)
    [[ "$(<"$_secret")" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

validate-passphrase::() {
    read -r _secret < <(get-secret)

    ! trailing-newline "$_secret" ||
        die 1 "'$_secret' has trailing newline"

    [[ $(wc -c <"$_secret") -ge 12 ]] ||
        die 1 "'$(cat "$_secret")' is shorter than 12 chars"
}

# --- cat-[secret|public]:*:*

cat-secret::() {
    read -r _secret < <(get-secret) || die 1 "failed to get secret"
    cat "$_secret"
}

cat-public::() {
    cat "$(public-file)"
}

# --- base64-secret:*:*

base64-secret::() {
    cat-secret:: | base64 -w0
    echo
}

# --- [encrypt|decrypt|unset]-secret:*:*

encrypt-secret::() {
    try sops set "$(backend-file)" "$(backend-path)" "$(jq -Rs <"$(secret)")"
}

encrypt-secret:root:() {
    try cp -a "$(secret)" "$(backend-file)"
}

decrypt-secret::() {
    try sops decrypt --extract "$(backend-path)" "$(backend-file)"
}

decrypt-secret:root:() {
    try cat "$(backend-file)"
}

unset-secret::() {
    try sops unset "$(backend-file)" "$(backend-path)"
}

# --- rebuild:*:*

rebuild::() {
    rebuild-creation-rules
    [[ $class != "root" ]] || return 0
    sops updatekeys -y "$(backend-file)" \
        > >(log important) \
        2> >(grep "synced with" | log info)
}

# --- sideload:*:*

sideload:host:luks-key() {
    local old_key new_key

    old_key=$(run base64-secret)

    if get-secret | cmp -s - "$(seed-secret)" >/dev/null; then
        new_key=$old_key
    else
        new_key=$(
            slot=$(next-slot::) >&2
            run new base64-secret
        )
    fi

    {
        printf '%s\n' "$old_key"
        printf '%s\n' "$new_key"
    } | keyservice "$key"
}

sideload:host:age-key() {
    run verify-identity
    run base64-secret new base64-secret | keyservice "$key"
}

# --- [exists|next-slot]:*:*

exists::() {
    get-secret >/dev/null
}

next-slot::() {
    local _slot=0
    while (slot=$_slot run exists); do
        ((_slot++)) || true
    done
    echo $_slot
}

# --- sops integrations

create-sops-yaml() {
    [[ -f .sops.yaml ]]
    cat >.sops.yaml <<'EOF'
fqdn: $entity.local
backend: enc/$class-$entity.yaml
backend:root: keys/$class-$entity
public:ssh-key: public/$class-$entity-$key.pub
public:wg-key: public/$class-$entity-$key.pub
public:tls-cert: public/$class-$entity-$key.pem
EOF
}

create-backend() {
    # shellcheck disable=SC2094
    # SC believes we're reading from $(backend-file) here, but --filename-override
    # simply tells sops what creation rule to use, so this is ok.
    echo "init: true" | sops encrypt \
        --filename-override "$(backend-file)" \
        /dev/stdin >"$(backend-file)"
}

read-setting() {
    path=$1 try yq-sops-e '.["$path"] // error("$path not found")'
}

search-setting() {
    find-first "$1" read-setting
}

autocomplete-identity() {
    local matches
    matches=$(
        q=$1 yq-sops-e '(
        .identities
            | keys
            | map(select(. | contains("$q")))[]
            // error("no match for $q")
        )'
    ) || return
    (($(echo "$matches" | wc -l) == 1))
    echo "$matches"
}

find-identity() {
    age_key=$(cat) try yq-sops-e '(
        .identities
            | to_entries
            | .[]
            | select(.value == "$age_key")
            | .key
        ) // error("$age_key not found")'
}

get-identity() {
    id="$class-$entity" try yq-sops-e '.identities.$id // error("$id not found")'
}

upsert-identity() {
    age_key=$(run derive-public) \
    id="$class-$entity" \
        yq-sops-i '(
            .identities.$id = "$age_key" |
            .identities.$id anchor = "$id"
        )'
    rebuild:: || true
}

rebuild-creation-rules() {
    local query='(
        . as $d
            |
        $d.identities
            | keys
            | map(select(. == "root-*")) as $roots
            | map(select(. != "root-*"))
            |
        map(. as $identity | {
            "path_regex": "enc/" + .,
            "key_groups": [
                { "age": $roots + [.] + $d.grants[$identity]
                    | map(. as $_ | . alias = .)
                }
            ]
        })
    ) as $generated_rules | .creation_rules = $generated_rules'

    yq -i "$query" .sops.yaml
}

# --- derived variables

secret() {
    local tmp=$tmpdir/$class.$entity.$key.$slot.secret
    [[ -s "$tmp" ]] || {
        touch "$tmp"
        chmod 600 "$tmp"
    }
    echo "$tmp"
}

backend-file() {
    search-setting "backend:$class backend"
}

backend-path() {
    local _key=$key
    [[ "$slot" == "0" ]] || _key="$key--$slot"
    case $class in
    host) echo "['$_key']" ;;
    *) echo "['$entity']['$_key']" ;;
    esac
}

fqdn() {
    read-setting "fqdn"
}

public-file() {
    read-setting "public:$key"
}

callchain() {
    cat <<EOF
$action:$class:$key
$action:$class:
$action::$key
$action::
EOF
}

# --- cached I/O ops

get-secret() {
    [[ -s $(secret) ]] || {
        run decrypt-secret >"$(secret)"
    } && secret
}

set-secret() {
    cat >"$(secret)"
    run validate encrypt-secret
}

test-public() {
    local public_file="$tmpdir/$class.$entity.$key.public"
    [[ -f $public_file ]] || run derive-public >"$public_file"
    echo "$public_file"
}

seed-secret() {
    local seed_secret=$tmpdir/seed_secret
    [[ -f "$seed_secret" ]] || {
        touch "$seed_secret"
        [[ -r ${SEED_SECRET:-} ]] &&
            cat "$SEED_SECRET" >"$seed_secret"
    }
    echo "$seed_secret"
}

# --- misc helpers

usage() {
    sed -n '/^SYNOPSIS$/,/^$/p' "$here/id-entities-usage.txt"
}

gen-passwd() {
    openssl rand -base64 12 | tr -d '\n'
}

run() {
    local cmd
    for action in "$@"; do
        cmd="$(find-first "$(callchain)" fn-exists)" || die
        $cmd
    done
}

keyservice() {
    local payload
    payload=$(cat)

    log debug "payload:"$'\n'"$payload"

    eval "$(ssh-agent -s)" >/dev/null
    trap 'ssh-agent -k >/dev/null 2>&1' EXIT
    (
        class=service
        entity=keyservice
        key=ssh-key
        slot=0
        run cat-secret
    ) | ssh-add - 2>/dev/null

    echo "$payload" | ssh "keyservice@$(fqdn)" "$@" \
        > >(log info) \
        2> >(log error) || die
}

# --- main
main "$@"
