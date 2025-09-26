#!/usr/bin/env bash
# sops-yaml.sh
# shellcheck disable=SC2016
# SC2016: Yes, we know expressions wont expand in single quotes.

create-sops-yaml() {
    cat >.sops.yaml <<'EOF'
fqdn: $entity.local
backend: enc/$class-$entity.yaml
backend:root: keys/$class-$entity
artifact:ssh-key: artifacts/$class-$entity-$key.pub
artifact:nix-cache-key: artifacts/$class-$entity-$key.pub
artifact:wg-key: artifacts/$class-$entity-$key.pub
artifact:tls-cert: artifacts/$class-$entity-$key.pem
EOF
}

identity-picker() {

    options=("Option 1" "Option 2" "Option 3")
    PS3="Choose an option: "

    select opt in "${options[@]}"; do
        if [[ -n "$opt" ]]; then
            echo "You chose $opt"
            break
        else
            echo "Invalid choice, try again."
        fi
    done
}

create-sops-backend() {
    local backend_path=$1
    mkdir -p "$(dirname "$backend_path")"
    # shellcheck disable=SC2094
    # SC believes we're reading from $(backend_file) here, but --filename-override
    # simply tells sops what creation rule to use, so this is ok.
    echo "enable: true" | try sops encrypt \
        --filename-override "$backend_path" \
        /dev/stdin >"$backend_path"
}

read-setting() {
    path=$1 yq-sops-e '.["$path"] // error("$path not found")' 2> >(log error)
}

get-ops() {
    op=$1 yq-sops-e '.ops.$op
        | with_entries(select(
            .key == "$class-$entity" or
            .key == "$class" or
            .key == "all"
            )
        ) | [.all[], .$class[], .$class-$entity[] ][]'
}

search-setting() {
    for item; do
        read-setting "$item" 2>/dev/null || continue
        return 0
    done
}

autocomplete-identity() {
    local matches
    matches=$(
        q=$1 try yq-sops-e '(
        .identities
            | keys
            | map(select(. | contains("$q")))[]
            // error("`$q` did not match any identities")
        )'
    )
    (($(echo "$matches" | wc -l) == 1)) ||
        die 1 "$matches"$'\n'"^ ambiguous query, which did you mean?"
    echo "$matches"
}

get-identity-by-age-key() {
    age_key=$(cat) yq-sops-e '(
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

all-identities() {
    yq '.identities | keys | .[]' .sops.yaml
}

upsert-identity() {
    age_key=$(cat) id="$1" \
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
