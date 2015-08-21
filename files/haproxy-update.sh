#!/usr/bin/env bash

set -x

read -r -d '' USAGE <<EOF
    Usage: haproxy-update.sh [--live-config /etc/haproxy/haproxy.cfg] [--base-config /etc/haproxy/haproxy.cfg.base] [--commands-file /path/to/update/commands]
    comamands must be provided by either stdin or from the file in above argument. See --help for command format.
EOF

read -r -d '' HELP <<EOF
    haproxy-update.sh: Manages 'server' directives in haproxy.cfg.

    (1) Merges base config into live config, preserving 'server' directives of live configuration.
    (2) Adds or removes server directives in live config based on provided commands

    $USAGE

    command format:
    {add|del} {backend_name} {container_port} [additional_options...]
    ...

    example:
    del domain-api 54321
    add domain-api 12345 maxconn 100
    add cassandra 39391

    Conventions:
        Commands are processed in the order they are provided. 
        'add' commands are ignored if the container port already exists for the given backend_NAME. 
            If you wish add an additional option to an existing server directive, make sure
            to 'del' the directive before 'add'ing its replacement.
EOF

# Defaults
LIVE_CONFIG=/etc/haproxy/haproxy.cfg
BASE_CONFIG=/etc/haproxy/haproxy.cfg.base
CONTAINER_HOST="127.0.0.1"
DISPLAY_HELP=false
SERVER_NAME_TAG="DYNAMIC" 
DYNAMIC_DIRECTIVE_RE="^\s*server ${SERVER_NAME_TAG}-"
DIRECTIVE_LOOKUP_RE='${DYNAMIC_DIRECTIVE_RE}${BACKEND_NAME}-.*${CONTAINER_HOST}:${PORT}.*'
COMMANDS_FILE=
COMMANDS=

while [[ "$#" > 0 ]]; do
    key="$1"
    case $key in
        --live-config)
        LIVE_CONFIG="$2"
        shift
        ;;
        --base-config)
        BASE_CONFIG="$2"
        shift
        ;;
        --commands-file)
        COMMANDS_FILE="$2"
        shift
        ;;
        --help)
        DISPLAY_HELP=true
        ;;
        *)
        
        ;;
    esac
    shift
done

if [ "$DISPLAY_HELP" = true ]; then
    echo "$HELP"
    exit 0
fi

if ! [ -e "$LIVE_CONFIG" ]; then
    >&2 echo "Error: Could not find live config file ${LIVE_CONFIG}"
    exit 1
fi

if ! [ -e "$BASE_CONFIG" ]; then
    >&2 echo "Error: Could not find base config file ${BASE_CONFIG}"
    exit 1
fi

if [ -z "$COMMANDS_FILE" ]; then
    read COMMANDS
else
    if ! [ -e "$COMMANDS_FILE" ]; then
        >&2 echo "Error: Could not find commands file ${COMMANDS_FILE}"
        exit 1
    fi
    COMMANDS=$(cat $COMMANDS_FILE)
fi


function add_directive_line() {
    local CONFIG="$1"
    local DIRECTIVE="$2"

    awk "/^\s*backend\s+${BACKEND_NAME}/{print; print \"${DIRECTIVE}\"; next}1" "$CONFIG" > "$CONFIG.tmp" \
        && mv "$CONFIG.tmp" "$CONFIG"   
}

function add_live_directive() {
    local BACKEND_NAME="$1"
    local PORT="$2"
    local OPTIONS="${@:3}"
    local DIRECTIVE="  server ${SERVER_NAME_TAG}-${BACKEND_NAME}-"$(date +%m-%d-%y_%H:%M:%S.%3N)" ${CONTAINER_HOST}:${PORT} ${OPTIONS}"

    if grep "$(server_directive_re "${BACKEND_NAME}" "${PORT}")" "${LIVE_CONFIG}"; then
        >&2 echo "Warning: Ignoring 'add' command: backend ${BACKEND_NAME} already contains server directive for port ${PORT}."
        return
    fi
    
    add_directive_line "${LIVE_CONFIG}" "${DIRECTIVE}"
}

function remove_live_directive() {
    local BACKEND_NAME="$1"
    local PORT="$2"

    sed -i'' '/'"$(server_directive_re "${BACKEND_NAME}" "${PORT}")"'/d' "${LIVE_CONFIG}"
}

function server_directive_re() {
    local BACKEND_NAME="$1"
    local PORT="$2"

    echo -n "^\s*server ${SERVER_NAME_TAG}-${BACKEND_NAME}-.*${CONTAINER_HOST}:${PORT}.*"
}

function merge_live_directives() {
    # Save directives from live config
    local DIRECTIVES=$(grep "${DYNAMIC_DIRECTIVE_RE}" ${LIVE_CONFIG})

    # Replace live config with base config
    cp -f "${BASE_CONFIG}" "${LIVE_CONFIG}"

    # Copy existing directives into new live config
    while read DIRECTIVE; do
        if [ -n "$DIRECTIVE" ]; then
            add_directive_line "${LIVE_CONFIG}" "${DIRECTIVE}"
        fi
    done <<< "$DIRECTIVES"
}

function process_commands() {
    while read DIRECTIVE; do
        read -a TOKENS <<< "$DIRECTIVE"
        local CMD="${TOKENS[0]}"
        local BACKEND_NAME="${TOKENS[1]}"
        local PORT="${TOKENS[2]}"
        local OPTIONS="${TOKENS[@]:3}"

        if ! grep "$BACKEND_NAME" "$LIVE_CONFIG"; then
            >&2 echo "Error: Could not find backend '${BACKEND_NAME}' in ${CONFIG}. Moving on..."
            continue
        fi

        case "$CMD" in
             add)
                add_live_directive "$BACKEND_NAME" "$PORT" "$OPTIONS"
                ;;
             del)
                remove_live_directive "$BACKEND_NAME" "$PORT"
                ;;
             *)
             >&2 echo "Unrecognized command ${CMD}. Moving on..."
        esac
    done <<< "$COMMANDS"
}

merge_live_directives &&
process_commands