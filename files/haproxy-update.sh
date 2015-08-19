#!/usr/bin/env bash

set -x

read -r -d '' USAGE <<EOF
    Usage: haproxy-update.sh --config /etc/haproxy/haproxy.cfg [--server-directives /path/to/update/directives]
    server-directives must be provided by either stdin or the above argument
EOF

read -r -d '' HELP <<EOF
    $USAGE

    server-directives input format:
    {add|del} {backend_name} {container_port} [additional_options...]
    ...

    example:
    del domain-api 54321
    add domain-api 12345 maxconn 100
    add cassandra 39391

    Conventions:
        Server directives are processed in the order they are provided. 
        'add' directives are ignored if the container port already exists for the given backend_NAME. 
            If you wish to modify an existing directive to add an additional option, make sure
            to 'del' the directive before 'add'ing its replacement.
EOF

# Defaults
CONFIG=/etc/haproxy/haproxy.cfg
CONTAINER_HOST="127.0.0.1"
DYNAMIC_DIRECTIVE_RE="^\s*server ${SERVER_NAME_TAG}-${BACKEND_NAME}-.*${CONTAINER_HOST}:${PORT}.*"
HELP_ARG=false
SERVER_DIRECTIVES=
SERVER_NAME_TAG="DYNAMIC" 

while [[ "$#" > 0 ]]; do
    key="$1"
    case $key in
        --config)
        CONFIG="$2"
        shift
        ;;
        --server-directives)
        SERVER_DIRECTIVES_PATH="$2"
        shift
        ;;
        --help)
        HELP_ARG=true
        ;;
        *)
        
        ;;
    esac
    shift
done

if [ "$HELP_ARG" = true ]; then
    echo "$HELP"
    exit 0
fi

if ! [ -e "$CONFIG" ]; then
    >&2 echo "Error: Could not find config file ${CONFIG}"
fi

if [ -z "$SERVER_DIRECTIVES_PATH" ]; then
    read SERVER_DIRECTIVES
else
    if ! [ -e "$SERVER_DIRECTIVES_PATH" ]; then
        >&2 echo "Error: Could not find directives file ${SERVER_DIRECTIVES_PATH}"
        exit 1
    fi
    SERVER_DIRECTIVES=$(cat $SERVER_DIRECTIVES_PATH)
fi


function add_directive() {
    local BACKEND_NAME="$1"
    local PORT="$2"
    local OPTIONS="${@:3}"
    local DIRECTIVE="  server ${SERVER_NAME_TAG}-${BACKEND_NAME}-"$(date +%m-%d-%y_%H:%M:%S.%3N)" ${CONTAINER_HOST}:${PORT} ${OPTIONS}"

    if grep "$(directive_re "${BACKEND_NAME}" "${PORT}")" "$CONFIG"; then
        >&2 echo "Warning: Ignoring 'add' command: backend ${BACKEND_NAME} already contains server directive for port ${PORT}."
        return
    fi
    
    awk "/^\s*backend\s+${BACKEND_NAME}/{print; print \"${DIRECTIVE}\"; next}1" "$CONFIG" > "$CONFIG.tmp" \
        && mv "$CONFIG.tmp" "$CONFIG"
}

function remove_directive() {
    local BACKEND_NAME="$1"
    local PORT="$2"

    gsed -i'' '/'"$(directive_re "${BACKEND_NAME}" "${PORT}")"'/d' "$CONFIG"
}

function directive_re() {
    local BACKEND_NAME="$1"
    local PORT="$2"

    echo "^\s*server ${SERVER_NAME_TAG}-${BACKEND_NAME}-.*${CONTAINER_HOST}:${PORT}.*"
}

function process_directives() {
    while read DIRECTIVE; do
        read -a tokens <<< "$DIRECTIVE"
        local CMD="${tokens[0]}"
        local BACKEND_NAME="${tokens[1]}"
        local PORT="${tokens[2]}"
        local OPTIONS="${tokens[@]:3}"

        if ! grep "$BACKEND_NAME" $CONFIG; then
            >&2 echo "Error: Could not find backend '${BACKEND_NAME}' in ${CONFIG}. Moving on..."
            continue
        fi

        case "$CMD" in
             add)
             add_directive "$BACKEND_NAME" "$PORT" "$OPTIONS"
                ;;
             del)
             remove_directive "$BACKEND_NAME" "$PORT"
             ;;
             *)
             >&2 echo "Unrecognized command ${CMD}. Moving on..."
        esac
    done <<< "$SERVER_DIRECTIVES"
}

process_directives