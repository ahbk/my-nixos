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

declare -A allowed_keys=(
    ["root"]="age-key"
    ["host"]="age-key ssh-key wg-key luks-key"
    ["user"]="age-key ssh-key passwd mail"
    ["domain"]="age-key tls-cert"
)

declare -x here
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# import tmpdir, log, die, try, run, find-first and fn-exists
# shellcheck source=./tools/lib.sh
. "$here/lib.sh"

main() {
    setup "$@" && run
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

    [[ -f ".sops.yaml" ]] || create-sops-yaml
    validate-args
    verify-doas
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

verify-doas() {
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
    if [[ -n ${SECRET_FILE-} ]]; then
        cat "$SECRET_FILE" >"$(secret)"
    else
        create-secret::age-key >"$(secret)"
    fi
    chmod 600 "$(secret)"
    run validate || die 1 "$(cat "$(secret)")"

    upsert-identity
    rebuild-creation-rules

    create-backend
    run encrypt-secret
}

init:root:age-key() {
    [[ ! -f $(backend-file) ]] || die 1 "will not overwrite existing .sops.yaml"
    run new-secret
    upsert-identity
}

# --- new:*:*

new::() {
    run new-secret
    run align
}

new:root:age-key() {
    [[ "$class-$entity" != "$doas" ]] || die 1 "can't rotate current"
    run new-secret
    upsert-identity
}

new:host:ssh-key() {
    run new-secret
    quiet set-public
    log warning "public ssh keys will be overwritten by host scans on align"
}

new:host:luks-key() {
    run new-secret
}

# --- new-secret:*:*

new-secret::() {
    if [[ -n ${SECRET_FILE:-} ]]; then
        set-secret <"$SECRET_FILE"
    else
        run create-secret | set-secret
    fi
}

# --- align:*:*

align::age-key() {
    upsert-identity
}

align::wg-key() {
    quiet set-public
}

align::tls-cert() {
    quiet set-public
}

align:host:ssh-key() {
    scan:host:ssh-key >"$(public-file)"
}

align:user:ssh-key() {
    quiet set-public
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
    scan:host:ssh-key | try diff - "$(get-public)"
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
    local exit_code=0 pub sec
    pub=$(get-public)
    sec=$(get-secret)

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
    [[ "$key" == "age-key" ]] || return 1
    id=$(get-identity) || return 1
    echo "$id" | try diff "$(tmp-public)" -
}

verify-public::() {
    try diff "$(tmp-public)" "$(get-public)"
}

verify-host::() {
    run base64-secret | keyservice "$key"
}

verify-hash::() {
    local salt
    salt=$(
        key=$key-hashed
        awk -F'$' '{print $3}' "$(get-secret)"
    )

    mkpasswd -sm sha-512 -S "$salt" <"$(get-secret)" |
        try diff - "$(key=$key-hashed get-secret)"
}

# --- scan:*:*

scan:host:ssh-key() {
    ssh-keyscan -q "$(fqdn)" | awk '{print $2, $3}'
}

# --- create-secret:*:*

create-secret::age-key() {
    age-keygen 2> >(quiet tlog info) | tail -1
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
    age-keygen -y <"$(get-secret)"
}

derive-public::ssh-key() {
    ssh-keygen -y -C "" -f "$(get-secret)"
}

derive-public::wg-key() {
    wg pubkey <"$(get-secret)"
}

derive-public::tls-cert() {
    openssl req -new -x509 -key "$(get-secret)" \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

# --- validate:*:*

validate::() {
    trailing-newline "$(get-secret)" && quiet tmp-public
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
    [[ $(wc -c <"$(get-secret)") -ge 12 ]] || die 1 "shorter than 12 chars"
}

# --- cat-[secret|public]:*:*

cat-secret::() {
    cat "$(get-secret)"
}

cat-public::() {
    cat "$(get-public)"
}

# --- base64-secret:*:*

base64-secret::() {
    base64 -w0 "$(get-secret)"
    echo
}

# --- [encrypt|decrypt]-secret:*:*

encrypt-secret::() {
    sops set "$(backend-file)" "$(backend-path)" "$(jq -Rs <"$(secret)")"
}

encrypt-secret:root:() {
    cp -a "$(secret)" "$(backend-file)"
}

decrypt-secret::() {
    sops decrypt --extract "$(backend-path)" "$(backend-file)"
}

decrypt-secret:root:() {
    cat "$(backend-file)"
}

# --- updatekeys:*:*

updatekeys::() {
    rebuild-creation-rules
    [[ $class != "root" ]] || return 0
    sops updatekeys -y "$(backend-file)" \
        > >(tlog important >/dev/null) \
        2> >(grep "synced with" | tlog info >/dev/null)
}

# --- sideload:*:*

sideload::() {
    [[ "$class" == "host" ]]
    [[ $key =~ (age-key|luks-key) ]]

    {
        run base64-secret
        run new && run base64-secret
    } | keyservice "$key"
}

sideload:host:age-key() {
    run verify-identity
    sideload::
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
    yq-sops-e ".[\"$1\"]"
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
    age_key=$(cat) yq-sops-e '(
        .identities
            | to_entries
            | .[]
            | select(.value == "$age_key")
            | .key
        )'
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
    updatekeys:: || true
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

    run validate
    run encrypt-secret
}

get-public() {
    local public_file
    public_file=$(public-file)
    [[ -f $public_file ]]
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
    openssl rand -base64 12 | tr -d '\n'
}

run() {
    local action=${1:-$action} cmd
    cmd="$(find-first "$(callchain)" fn-exists)" || die
    $cmd | tlog debug
}

keyservice() {
    eval "$(ssh-agent -s)" >/dev/null
    trap 'ssh-agent -k >/dev/null 2>&1' EXIT
    (
        class=user
        entity=keyservice
        key=ssh-key
        run cat-secret
    ) | ssh-add - 2>/dev/null

    try ssh "keyservice@$(fqdn)" "$@"
}

# --- main
main "$@"
