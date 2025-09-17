#!/usr/bin/env bash
# sops-yaml.sh
# shellcheck disable=SC2016
# SC2016: Yes, we know expressions wont expand in single quotes.

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

create-sops-backend() {
    local backend_file=$1
    # shellcheck disable=SC2094
    # SC believes we're reading from $(backend_file) here, but --filename-override
    # simply tells sops what creation rule to use, so this is ok.
    echo "enable: true" | try sops encrypt \
        --filename-override "$backend_file" \
        /dev/stdin >"$backend_file"
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
    (($(echo "$matches" | wc -l) == 1)) || die 1 "ambiguous query"
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
    id="$(id)" try yq-sops-e '.identities.$id // error("$id not found")'
}

upsert-identity() {
    age_key=$(run derive-public) id="$(id)" \
        yq-sops-i '(
            .identities.$id = "$age_key" |
            .identities.$id anchor = "$id"
        )'
    run rebuild
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

yq-sops-i() {
    yq -i "$(echo "$1" | envsubst)" .sops.yaml
}

yq-sops-e() {
    yq -e "$(echo "$1" | envsubst)" .sops.yaml | envsubst
}
