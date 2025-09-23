#!/usr/bin/env bash
# id-entities.sh

# === section 0: setup

# shellcheck disable=SC2030,SC2031
# - variables are modified in subshells intentionally

set -euo pipefail

declare -x doas entity prefix class key
declare -g slot

declare -A allowed_keys=(
    ["root"]="age-key"
    ["host"]="age-key ssh-key wg-key luks-key nix-cache-key"
    ["service"]="age-key ssh-key passwd"
    ["user"]="age-key ssh-key passwd mail"
    ["domain"]="age-key tls-cert"
)

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r here

# import run, with, log/try/die etc.
. "$here/run-with.bash"

# import upsert-identity, read-setting etc.
. "$here/sops-yaml.sh"

main() {
    # setup prefix, class, key etc.
    setup "$@" || die 1 "setup failed"

    # map command to a callchain and invoke its functions, e.g.
    # id-entities.sh -u alex verify ssh-key ->
    #     verify:user:ssh-key
    #     verify:user
    #     verify:ssh-key
    #     verify
    run "$prefix"

    # 'with id' runs id() and brings the result into scope as $id,
    # like a lazy variable.
    with id

    # sync to seize control over final output
    sync && log success "$prefix $key for $id completed."
}

callchain() {
    # strip everything from the first colon
    local pfix=${prefix%%:*}
    cat <<EOF
$pfix:$class:$key
$pfix:$class
$pfix:$key
$pfix:
EOF
}

setup() {
    [[ -n ${1:-} ]] || die 1 "hello! try --help" usage

    case "$1" in
    -r | --root) class="root" ;;
    -h | --host) class="host" ;;
    -u | --user) class="user" ;;
    -d | --domain) class="domain" ;;
    -s | --service) class="service" ;;
    -H | --help)
        less "$here/id-entities-usage.txt"
        exit 0
        ;;
    *)
        if IFS='-' read -r class entity < <(autocomplete-identity "$1"); then
            shift
            set -- "$entity" "$@"
            set -- "$class" "$@"
        else
            die 1 "could not infer a valid context" usage
        fi
        ;;
    esac

    entity=${2:?"entity name required"}
    prefix=${3:?"prefix is required"}
    key=${4-"age-key"}
    slot=${5:-0}

    preflight-input
    preflight-sops-yaml
    preflight-backend
    preflight-doas
}

preflight-input() {
    fn-match "$prefix" ||
        die 1 "no link matches prefix '$prefix'"

    [[ " ${allowed_keys[$class]} " == *" $key "* ]] ||
        die 1 "$key not allowed for $class, allowed keys: ${allowed_keys[$class]}"
}

preflight-sops-yaml() {
    with id
    [[ "$prefix-$id" == "init-root-1" && ! -f ".sops.yaml" ]] && {
        log important "bootstrap conditions, creating .sops.yaml."
        create-sops-yaml
    }

    [[ -f ".sops.yaml" ]] || die 1 "needs .sops.yaml in working directory"
}

preflight-backend() {
    with backend_path
    [[ $prefix == "init" && -f "$backend_path" ]] &&
        die 1 "can't init '$entity', '$backend_path' already exists."

    [[ $prefix == "init" || -f "$backend_path" ]] ||
        die 1 "'$backend_path' doesn't exist, did you spell '$entity' correctly?"
}

preflight-doas() {
    with id
    # bootstrap root-1 need not be checked, as it has nothing to be checked against
    [[ "$prefix-$id" != "init-root-1" ]] || return 0

    doas=$(age-keygen -y <"$SOPS_AGE_KEY_FILE" | find-identity) ||
        die 1 "no identity found in '$SOPS_AGE_KEY_FILE'"

    log important "$doas"
}

# === section 1: links
#
# there are ~70 links and they are listed below grouped by prefix and sorted
# roughly by typical workflow order

# --- init:*:*

# a trailing colon terminates the callchain
init:root:() {
    run new
}

# non-root entities require a little dance to insert themselves in .sops.yaml
# before backend is created (the age-key is encrypted by the age-key)
init:() {
    with secret_seed secret_path backend_path

    if [[ -s "$secret_seed" ]]; then
        cat "$secret_seed" >"$secret_path"
    else
        run create-secret >"$secret_path"
    fi

    with id
    run derive-artifact | upsert-identity "$id"
    create-sops-backend "$backend_path"
    run new
}

# --- new:*:*

new:() {
    run new-secret align
}

# prevent identities from rotating themselves out of access
new:age-key() {
    with id
    [[ "$id" != "${doas:-}" ]] ||
        die 1 "entities are not allowed to rotate their own identity"
}

# --- new-secret:*:*

new-secret:() {
    # If SECRET_SEED is set to the path of a file, the path will be available
    # in $secret_seed
    with secret_seed
    if [[ -s "$secret_seed" ]]; then
        run encrypt <"$secret_seed"
    else
        run create-secret | run encrypt
    fi
}

# --- [verify|check]:*:*

verify:() {
    run-with get-artifact
    run derive-artifact | try diff - "$get_artifact"
}

# force artifact-only verification
verify:host:ssh-key:() {
    run-with get-artifact
    derive-artifact:ssh-key: | try diff - "$get_artifact"
}

verify:domain:tls-cert:() {
    run-with get-artifact
    with secret_file

    try openssl x509 -in "$get_artifact" -checkend 2592000 | log info

    openssl x509 -in "$get_artifact" -noout -ext subjectAltName |
        try grep -q "DNS:$entity"

    openssl pkey -in "$secret_file" -pubout |
        try diff - <(openssl x509 -in "$get_artifact" -pubkey -noout)
}

# host scan under check:* instead
check:host:ssh-key:() {
    verify:
}

check:host:age-key() {
    base64-secret: | locksmith
}

check:host:luks-key() {
    base64-secret: | locksmith
}

# --- [align|pull|push]:*:*

align:() {
    run derive-artifact | run set-artifact
}

# prevent derive-artifact from doing host scan for host:ssh-key
align:host:ssh-key:() {
    derive-artifact:ssh-key: | run set-artifact

    run-with get-artifact
    log warning "next 'pull' will replace public ssh key at '$get_artifact'"
}

# host scan under pull:* instead
pull:host:ssh-key:() {
    align:
}

push:host:luks-key() {
    with secret_file secret_seed

    # if the currently held secret and the user-provided-secret are identical,
    # pass them to looksmith as two (also identical) base64-strings.
    # this will instruct locksmith to drop the luks-key on the host.
    if cmp -s "$secret_file" "$secret_seed"; then
        run base64-secret new base64-secret | locksmith
        return
    fi

    # otherwise create a new secret under first available slot and pass them
    # as two base64-strings, this will instruct locksmith to add the second
    # passphrase.
    run-with next-slot
    {
        run base64-secret
        slot=$next_slot run new base64-secret
    } | locksmith
}

push:host:age-key() {
    run verify
    # age-keys are stacked in the hosts' key file and will remain until
    # garbage-collected.
    run base64-secret new base64-secret | locksmith
}

# --- create-secret:*:*

create-secret:age-key() {
    try age-keygen 2> >(log info) | tail -1
}

create-secret:ssh-key() {
    with id tmp_path
    try ssh-keygen -t "ed25519" -f "$tmp_path" -N "" -C "$id" > >(log info)
    cat "$tmp_path"
}

create-secret:nix-cache-key() {
    with fqdn tmp_path
    nix-store --generate-binary-cache-key "$fqdn" "$tmp_path" "$tmp_path.pub"
    cat "$tmp_path"
}

create-secret:wg-key() {
    try wg genkey
}

create-secret:luks-key() {
    try passphrase 12
}

create-secret:tls-cert() {
    try openssl genpkey -algorithm ED25519
}

create-secret:passwd() {
    try passphrase 8
}

# nixos-mailserver has unix-like user management, so mail will piggyback
# on passwd for all ops
create-secret:mail() {
    create-secret:passwd
}

# --- validate:*:*

validate:() {
    # secrets without artifacts may supply null operations here
    run derive-artifact >/dev/null
}

validate:luks-key() {
    validate-passphrase
}

validate:passwd() {
    validate-passphrase
}

validate:mail() {
    validate:passwd
}

# this key 'passwd-sha512' is actually artifact for 'passwd', so it is banned
# from deriving artifacts and we terminate the callchain with a trailing colon
validate:passwd-sha512:() {
    validate-sha512
}

validate:mail-sha512:() {
    validate:passwd-sha512:
}

validate-sha512() {
    run-with cat-secret
    [[ "$cat_secret" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

validate-passphrase() {
    with secret_file
    local min_length=6

    ! trailing-newline "$secret_file" ||
        die 1 "'$secret_file' has trailing newline"

    [[ $(wc -m <"$secret_file") -ge "$min_length" ]] ||
        die 1 "'$(cat "$secret_file")' is shorter than $min_length chars"
}
# --- derive-artifact:*:*

derive-artifact:age-key:() {
    cat-secret: | try age-keygen -y
}

derive-artifact:passwd:() {
    sha512-secret:
}

derive-artifact:mail:() {
    derive-artifact:passwd:
}

# luks-keys have no public artifact
derive-artifact:luks-key:() {
    :
}

derive-artifact:wg-key:() {
    cat-secret: | try wg pubkey
}

derive-artifact:nix-cache-key:() {
    with fqdn secret_file
    {
        echo -n "$fqdn:"
        cut -d: -f2 <"$secret_file" | base64 --decode | tail -c 32 | base64 -w 0
    }
}

derive-artifact:tls-cert:() {
    run cat-secret | try openssl req -new -x509 -key /dev/stdin \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

derive-artifact:ssh-key:() {
    with secret_file
    try ssh-keygen -y -C "" -f "$secret_file"
}

derive-artifact:host:ssh-key:() {
    with fqdn
    try ssh-keyscan -q "$fqdn" | awk '{print $2, $3}'
}

# --- get-artifact:*

get-artifact:() {
    with artifact_path
    # shellcheck disable=SC2015
    # - this is not if/then/else
    test -s "$artifact_path" &&
        echo "$artifact_path" ||
        die 1 "no artifact at $artifact_path"
}

get-artifact:age-key() {
    with artifact_path
    # the public age-key is stored under .identities in .sops.yaml.
    get-identity >"$artifact_path"
}

get-artifact:passwd() {
    with artifact_path
    # create subshell to retreive secret from passwd-sha512 and use as artifact
    key=$key-sha512 cat-secret: >"$artifact_path"
}

get-artifact:mail() {
    get-artifact:passwd
}

get-artifact:luks-key:() {
    echo /dev/null
}

# --- set-artifact:*

set-artifact:() {
    with artifact_path
    cat >"$artifact_path"
}

set-artifact:age-key:() {
    with id
    upsert-identity "$id"
}

set-artifact:luks-key:() {
    cat >/dev/null
}

set-artifact:passwd:() {
    key=$key-sha512 run encrypt
}

set-artifact:mail:() {
    set-artifact:passwd:
}

# --- [encrypt|decrypt|unset]:*:*

encrypt:() {
    with secret_path
    cat >"$secret_path"
    run validate

    with backend_path backend_component
    run-with json-secret
    try sops set "$backend_path" "$backend_component" "$json_secret"
}

encrypt:root:() {
    with secret_path backend_path
    cat >"$secret_path"
    run validate
    try cp -a "$secret_path" "$backend_path"
}

decrypt:() {
    with backend_file backend_component
    try sops decrypt --extract "$backend_component" "$backend_file"
}

decrypt:root:() {
    with backend_path
    try cat "$backend_path"
}

unset:() {
    with backend_path backend_component
    try sops unset "$backend_path" "$backend_component"
}

# --- rebuild:*:*

rebuild:() {
    try rebuild-creation-rules
    [[ $class != "root" ]] || return 0

    with backend_path
    local rc=0
    sops updatekeys -y "$backend_path" \
        > >(log important) \
        2> >(grep "synced with" | log info) ||
        rc=$?

    case $rc in
    0 | 1) return ;;
    *) die $rc ;;
    esac
}

# --- next-slot:*:*

next-slot:() {
    local slot=0
    while (LOG_LEVEL=off run decrypt >/dev/null); do
        ((slot++)) || true
    done
    echo "$slot"
}

# --- [cat|base64|json|sha512]-secret:*:*

cat-secret:() {
    with secret_file && cat "$secret_file"
}

base64-secret:() {
    cat-secret: | try base64 -w0
    echo
}

json-secret:() {
    cat-secret: | try jq -Rs
}

sha512-secret:() {
    local salt
    salt=$(
        LOG_LEVEL=off
        key=$key-sha512
        run cat-secret | awk -F'$' '{print $3}'
    ) || salt=""
    run cat-secret | mkpasswd -sm sha-512 -S "$salt"
}

# === section 2: lazy variables (idempotent functions)

# run-with
declare -g \
    cat_secret \
    get_artifact \
    json_secret \
    next_slot

# with
declare -g \
    artifact_path \
    backend_component \
    backend_enabled \
    backend_file \
    backend_path \
    exact_key \
    fqdn \
    id \
    secret_file \
    secret_path \
    secret_seed \
    tmp_path

artifact_path() {
    # secrets that have public keys and other artifacts can store them at a
    # permanent location specified in .sops.yaml
    with exact_key
    LOG_LEVEL=off read-setting "artifact:$key" ||
        echo "$tmpdir/$class.$entity.$exact_key.artifact"
}

backend_component() {
    with exact_key
    local c="['$exact_key']"
    [[ $class == "host" ]] || c="['$entity']$c"
    echo "$c"
}

backend_enabled() {
    with backend_path
    local enabled rc
    enabled=$(try sops decrypt --extract "['enable']" "$backend_path")
    rc=$?
    case $rc in
    0) echo "$enabled" ;;
    100) die 1 "backend file missing for '$entity'" ;;
    esac
}

backend_file() {
    with backend_path backend_enabled
    if [[ "$backend_enabled" == "true" ]]; then
        echo "$backend_path"
    else
        die 1 "backend for '$entity' disabled"
    fi
}

backend_path() {
    search-setting "backend:$class" "backend"
}

exact_key() {
    local exact_key=$key
    [[ "$slot" == "0" ]] || exact_key+="--$slot"
    echo "$exact_key"
}

fqdn() {
    [[ $class == "host" ]] || die 1 "only hosts can have fqdn"
    try read-setting "fqdn"
}

id() {
    echo "$class-$entity"
}

passphrase() {
    local length=${1:-12}
    openssl rand -base64 "$length" | tr -d '\n'
}

secret_file() {
    with secret_path
    [[ -s $secret_path ]] ||
        run decrypt >"$secret_path" &&
        echo "$secret_path"
}

secret_path() {
    with exact_key
    local s=$tmpdir/$class.$entity.$exact_key.secret
    [[ -f "$s" ]] || {
        touch "$s"
        chmod 600 "$s"
    }
    echo "$s"
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

tmp_path() {
    local s
    s=$(mktemp "$tmpdir/XXXXXX") && rm "$s"
    echo "$s"
}

# === misc helpers

usage() {
    sed -n '/^USAGE$/,/^$/p' "$here/id-entities-usage.txt"
}

locksmith() {
    with fqdn

    if [ -t 0 ]; then
        die 1 "no payload"
    fi

    local lines payload

    payload=$(cat)
    [[ -n $payload ]] || die 1 "empty payload"

    lines=$(echo "$payload" | wc -l)
    [[ "$lines" -eq 1 || "$lines" -eq 2 ]] ||
        die 1 "payload must be 1-2 lines (got $lines)"

    eval "$(ssh-agent -s)" >/dev/null
    trap 'ssh-agent -k >/dev/null 2>&1' EXIT

    # create a subshell to retreive locksmith's ssh-key
    (
        class=service
        entity=locksmith
        key=ssh-key
        slot=0
        run cat-secret
    ) | ssh-add - 2>/dev/null

    echo "$payload" | try ssh "locksmith@$fqdn" "$key" \
        > >(log info) \
        2> >(log error)
}

# === main
main "$@"
