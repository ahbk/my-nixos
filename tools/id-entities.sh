#!/usr/bin/env bash
# id-entities.sh

# shellcheck disable=SC2317,SC2030,SC2031,SC2016
#
# SC2317: This script has a dispatcher that makes dynamic calls to functions
# that shellcheck believes are unreachable, so we disable this check globally.
#
# SC2030/31: The exported variables (see below) are affected by indirect calls
# with altered context (e.g. var=new-value command). This may be an
# anti-pattern, but it's not accidental, so we mute these warnings.
#
# SC2016: Yes, we know expressions wont expand in single quotes.

set -uo pipefail
shopt -s globstar

declare -x session class entity action key

declare -A allowed_keys=(
    ["root"]="age-key"
    ["host"]="age-key ssh-key wg-key luks-key"
    ["user"]="age-key ssh-key passwd mail"
    ["domain"]="age-key tls-cert"
)

declare -x here
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# import tmpdir, log, die, try, run, find-first and fn-exists
# also sops-integrations
. "$here/lib.sh"

main() {
    setup "$@" || die 1 "setup failed"
    local cmd exit_code

    cmd=$(find-first "$(callchain)" fn-exists)
    $cmd
    exit_code=$?

    sync

    case $exit_code in
    0) log success "$action:$class:$key for '$entity' completed successfully" ;;
    *) log error "$action:$class:$key for '$entity' completed with errors ($exit_code)" ;;
    esac

    exit "$exit_code"
}

setup() {
    [[ -n ${1:-} ]] || die 1 "hello! try --help" usage

    case "$1" in
    -r | --root) class="root" ;;
    -h | --host) class="host" ;;
    -u | --user) class="user" ;;
    -d | --domain) class="domain" ;;
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
    root | host | user | domain)
        entity=${2:?"entity name required"}
        action=${3:?"action is required"}
        key=${4-"age-key"}
        ;;
    help)
        less "$here/id-entities-usage.txt"
        exit 0
        ;;
    *)
        die 1 "'$1' is not a valid command." usage
        ;;
    esac

    [[ -f ".sops.yaml" ]] || try create-sops-yaml
    validate-args

    verify-session
    verify-keyservice
}

validate-args() {
    fn-match "$action:" ||
        die 1 "'$action' is not a valid action"

    [[ $action == "init" && -f "$(backend-file)" ]] &&
        die 1 "can't init '$entity', '$(backend-file)' already exists."

    [[ $class == "root" || $action == "init" || -f "$(backend-file)" ]] ||
        die 1 "'$(backend-file)' doesn't exist, did you spell $class correctly?"

    [[ " ${allowed_keys[$class]} " == *" $key "* ]] ||
        die 1 "$key not allowed for $class, allowed keys: ${allowed_keys[$class]}"

    [[ -z ${SECRET_FILE:-} || -r $SECRET_FILE ]] ||
        die 1 "'$SECRET_FILE' is not a file"
}

verify-session() {
    [[ "$action-$class-$entity" != "init-root-1" ]] || return 0

    local _class
    IFS='-' read -r _class session < <(age-keygen -y <"$SOPS_AGE_KEY_FILE" | find-identity)

    [[ "$_class" == "root" ]] || die 1 "not root"
}

verify-keyservice() {
    [[ "$class" == "host" && "$action" =~ (verify|align) ]] || return 0
    (
        class=user
        entity=$(keyservice)
        key=ssh-key
        run verify
    ) || log warning "could not verify ssh-key for $(keyservice)"
}

# --- init:*:*

init::() {
    mkdir -p "$(dirname "$(backend-file)")"

    # Almost like new-secret but it writes directly to secret instead of set-secret
    # because set-secret expects a backend that doesn't exist yet.
    if [[ -n ${SECRET_FILE-} ]]; then
        try cat "$SECRET_FILE" >"$(secret)"
    else
        try create-secret::age-key >"$(secret)"
    fi
    chmod 600 "$(secret)"

    run validate || die 1 "validation failed"

    upsert-identity
    rebuild-creation-rules

    create-backend
    run encrypt-secret
}

init:root:age-key() {
    [[ ! -f $(backend-file) ]] || die 1 "root key '$entity' already exists"
    run new-secret
    upsert-identity
}

# --- new:*:*

new::() {
    run new-secret
    run align
}

new:root:age-key() {
    [[ "$entity" != "$session" ]] || die 1 "can't rotate current root key"
    run new-secret
    upsert-identity
}

new:host:ssh-key() {
    run new-secret
    set-public >/dev/null
    log warning "public ssh keys will be overwritten by host scans on align"
}

new:host:luks-key() {
    run new-secret
}

# --- new-secret:*:*

new-secret::() {
    if [[ -n ${SECRET_FILE:-} ]]; then
        set-secret <"$SECRET_FILE" ||
            die 1 "could not copy secret"
    else
        run create-secret | set-secret ||
            die 1 "could not generate secret"
    fi
}

# --- align:*:*

align::age-key() {
    upsert-identity
}

align::wg-key() {
    set-public >/dev/null
}

align::tls-cert() {
    set-public >/dev/null
}

align:host:ssh-key() {
    scan:host:ssh-key >"$(public-file)"
}

align:user:ssh-key() {
    set-public >/dev/null
}

align:user:passwd() {
    align-hash::
}

align:user:mail() {
    align-hash::
}

align-hash::() {
    local hash
    hash=$(mkpasswd -sm sha-512 <"$(get-secret)")
    (
        key=$key-hashed
        echo "$hash" | set-secret
    ) || die 1 "could not align '$key-hashed'"
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
    scan:host:ssh-key | try diff - "$(get-public)" >&2 ||
        die 1 "not same"
}

verify:host:luks-key() {
    verify-host::
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
    local exit_code=0

    openssl x509 -in "$(get-public)" -checkend 2592000 | tlog info ||
        exit_code=1

    openssl x509 -in "$(get-public)" -noout -ext subjectAltName |
        grep -q "DNS:$entity" ||
        exit_code=1

    diff -q \
        <(openssl pkey -in "$(get-secret)" -pubout) \
        <(openssl x509 -in "$(get-public)" -pubkey -noout) ||
        exit_code=1

    return "$exit_code"
}

# --- verify-[public|identity|host|hash]:*:*

verify-identity::() {
    [[ "$key" == "age-key" ]] ||
        die 1 "only age-key can verify identity"

    get-identity | try diff "$(tmp-public)" - || die 1 "not same"
}

verify-public::() {
    (try diff "$(tmp-public)" "$(get-public)") || die 1 "not same"
}

verify-host::() {
    run base64-secret | try ssh "$(keyservice)@$(fqdn)" "$key" | tlog info ||
        die 1 "not same"
}

verify-hash::() {
    local salt
    salt=$(
        key=$key-hashed
        awk -F'$' '{print $3}' "$(get-secret)"
    )

    mkpasswd -sm sha-512 -S "$salt" <"$(get-secret)" |
        try diff - "$(key=$key-hashed get-secret)" || die 1 "not same"
}

# --- scan:*:*

scan:host:ssh-key() {
    try ssh-keyscan -q "$(fqdn)" | awk '{print $2, $3}' ||
        die 1 "scan failed"
}

# --- create-secret:*:*

create-secret::age-key() {
    try age-keygen | tail -1
}

create-secret::ssh-key() {
    local tmpkey
    tmpkey=$(mktemp -u "$tmpdir/XXXXXX")
    try ssh-keygen -q -t "ed25519" -f "$tmpkey" -N "" -C "" <<<y 2>/dev/null
    cat "$tmpkey"
}

create-secret::wg-key() {
    try wg genkey
}

create-secret::luks-key() {
    try gen-passwd
}

create-secret::tls-cert() {
    try openssl genpkey -algorithm ED25519
}

create-secret::passwd() {
    try gen-passwd
}

create-secret::mail() {
    try gen-passwd
}

# --- derive-public:*:*

derive-public::age-key() {
    try age-keygen -y <"$(get-secret)"
}

derive-public::ssh-key() {
    try ssh-keygen -y -C "" -f "$(get-secret)"
}

derive-public::wg-key() {
    try wg pubkey <"$(get-secret)"
}

derive-public::tls-cert() {
    try openssl req -new -x509 -key "$(get-secret)" \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

# --- validate:*:*

validate::() {
    trailing-newline "$(get-secret)" || die 1 "needs trailing newline"
    tmp-public >/dev/null
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
    [[ "$(<"$(get-secret)")" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

validate-passphrase::() {
    ! trailing-newline "$(get-secret)" || die 1 "has trailing newline"
    get-secret | grep -qE '^.{12,}$'
}

# --- cat-[secret|public]:*:*

cat-secret::() {
    try cat "$(get-secret)"
}

cat-public::() {
    try cat "$(get-public)"
}

# --- base64-secret:*:*

base64-secret::() {
    try base64 -w0 "$(get-secret)"
    echo
}

# --- [encrypt|decrypt]-secret:*:*

encrypt-secret::() {
    try sops set "$(backend-file)" "$(backend-path)" "$(jq -Rs <"$(secret)")"
}

encrypt-secret:root:() {
    cp -a "$(secret)" "$(backend-file)"
}

decrypt-secret::() {
    try sops decrypt --extract "$(backend-path)" "$(backend-file)"
}

decrypt-secret:root:() {
    cat "$(backend-file)"
}

# --- updatekeys:*:*

updatekeys::() {
    rebuild-creation-rules
    [[ $class == "root" ]] && return 0
    sops updatekeys -y "$(backend-file)" \
        > >(tlog important >/dev/null) \
        2> >(grep "synced with" | tlog info)
}

# --- sideload:*:*

sideload::() {
    [[ "$class" == "host" ]] ||
        die 1 "only hosts can sideload"

    [[ $key =~ (age-key|luks-key) ]] ||
        die 1 "only age-key and ssh-key can be sideloaded"

    {
        run base64-secret
        run new && run base64-secret
    } |
        try ssh "$(keyservice)@$(fqdn)" "$key" |
        tlog info ||
        die 1 "sideload failed"

    log important "rebuild '$entity' now or suffer the consequences"
}

sideload:host:age-key() {
    (run verify-identity) ||
        die 1 "keys are not aligned, run '$0 -h $entity align age-key' first"

    sideload::
}

# --- sops integrations

create-sops-yaml() {
    [[ -f .sops.yaml ]] &&
        die 1 "will not overwrite existing .sops.yaml"

    cat >.sops.yaml <<'EOF'
fqdn: $entity.local
backend: enc/$class-$entity.yaml
backend:root: enc/$class-$entity
public:ssh-key: public/$class-$entity-$key.pub
public:wg-key: public/$class-$entity-$key.pub
public:tls-cert: public/$class-$entity-$key.pem
EOF
}

create-backend() {
    # shellcheck disable=SC2094
    # SC believes we're reading from $(backend-file) here, but --filename-override
    # simply tells sops what creation rule to use, so this is ok.
    echo "init: true" | try sops encrypt \
        --filename-override "$(backend-file)" \
        /dev/stdin >"$(backend-file)" || die 1 "could not create $(backend-file)"
}

read-setting() {
    yq-sops ".[\"$1\"]"
}

search-setting() {
    find-first "$1" read-setting
}

yq-sops() {
    [[ -f .sops.yaml ]] || die 1 ".sops.yaml doesn't exist"
    local query

    query=$(echo "$1" | envsubst)
    if [[ ${2-} == "-i" ]]; then
        try yq -i "$query" .sops.yaml
    else
        try yq -e "$query" .sops.yaml | envsubst ||
            die 1 "'$query' failed"
    fi
}

autocomplete-identity() {
    q=$1 LOG_LEVEL=off yq-sops '(
        .identities
            | keys
            | map(select(. | contains("$q")))[0] // error("no match")
    )'
}

find-identity() {
    age_key=$(cat) yq-sops '(
        .identities
            | to_entries
            | .[]
            | select(.value == "$age_key")
            | .key
        )' || die 1 "no identity found for '$class-$entity'"
}

get-identity() {
    yq-sops '.identities.$class-$entity // error("not found")' ||
        die 1 "no identity found for '$class-$entity'"
}

upsert-identity() {
    age_key=$(run derive-public) yq-sops '(
        .identities.$class-$entity = "$age_key" |
        .identities.$class-$entity anchor = "$class-$entity"
        )' -i
    updatekeys::
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

    try yq -i "$query" .sops.yaml
}

# --- derived variables

secret() {
    echo "$tmpdir/$class.$entity.$key.secret"
}

backend-file() {
    search-setting "backend:$class backend"
}

backend-path() {
    case $class in
    host) echo "['$key']" ;;
    *) echo "['$entity']['$key']" ;;
    esac
}

fqdn() {
    read-setting "fqdn"
}

public-file() {
    read-setting "public:$key"
}

keyservice() {
    echo "${KEYSERVICE:-"keyservice"}"
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
    [[ -f $(secret) ]] || {
        run decrypt-secret >"$(secret)"
        chmod 600 "$(secret)"
    }
    secret
}

set-secret() {
    cat >"$(secret)"
    chmod 600 "$(secret)"

    run validate || die 1 "validation failed"
    run encrypt-secret
}

get-public() {
    local public_file
    public_file=$(public-file)
    [[ -f $public_file ]] || die 1 "public file '$public_file' doesn't exist"
    echo "$public_file"
}

set-public() {
    local public_file
    public_file=$(public-file)
    run derive-public >"$public_file"
    echo "$public_file"
}

tmp-public() {
    local public_file="$tmpdir/$class.$entity.$key.public"
    [[ -f $public_file ]] || run derive-public >"$public_file"
    echo "$public_file"
}

# --- misc helpers

usage() {
    sed -n '/^SYNOPSIS$/,/^$/p' "$here/id-entities-usage.txt"
}

gen-passwd() {
    try openssl rand -base64 12 | tr -d '\n'
}

# Shorthand for running other actions with inherited context
run() {
    local action=$1 cmd
    cmd="$(find-first "$(callchain)" fn-exists)"
    $cmd
}

# --- main
main "$@"
