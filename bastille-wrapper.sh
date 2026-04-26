#!/bin/sh
# bastille-wrapper.sh - Bastille jail making wrapper
#
#   a bastillefile is great, but needs a little more to fully automate.
#   that's this script (i hope).
#
#   this script only does basic sanity checks so make sure your confs
#   are good (no bad paths or typos).

. "$(dirname "$0")/configs/config.conf"

if [ ! -d "$BASTILLE_ROOT" ]; then
    echo "Error: Bastille root not a directory -> ${BASTILLE_ROOT}"
    exit 1
elif [ ! -d "${BASTILLE_ROOT}/releases/${RELEASE}" ]; then
    echo "Error: Release ${RELEASE} not found -> ${BASTILLE_ROOT}/releases/${RELEASE}"
    exit 1
elif ! ifconfig "$IF" >/dev/null 2>&1; then
    echo "Error: Interface $IF does not exist"
    exit 1
fi

BOOT='--no-boot'
JNAME=''
IP=''
CONFIG_FILE=''
F_BRIDGE=''
F_VNET=''
F_MAC=''
F_DUAL=''
F_RESTART=''

usage() {
    echo "Usage: $0 -n name -i ip [options]"
    echo "Options:"
    echo "  -n NAME      Jail name (required)"
    echo "  -i IP        Jail IP (required. can also be DHCP)"
    echo "  -I IF        Interface (default: em0)"
    echo "  -R RELEASE   FreeBSD release (default: 14.3-RELEASE)"
    echo "  -C FILE      Configuration file"
    echo "  -b           Enable boot"
    echo "  -B           Bridge mode (ensure IF is a bridge)"
    echo "  -D           Enable IPv4 & IPv6"
    echo "  -M           Assign static mac address"
    echo "  -V           VNET mode"
    echo "  -x           Restart jail after creation"
    exit 1
}

while getopts "n:i:I:R:C:bBDMVx" opt; do
    case "$opt" in
        n) JNAME=$OPTARG ;;
        i) IP=$OPTARG ;;
        I) IF=$OPTARG ;;
        R) RELEASE=$OPTARG ;;
        C) CONFIG_FILE=$OPTARG ;;
        b) BOOT='' ;;
        B) F_BRIDGE='-B' ;;
        D) F_DUAL='-D' ;;
        M) F_MAC='-M' ;;
        V) F_VNET='-V' ;;
        x) F_RESTART='1' ;;
        *) usage ;;
    esac
done

if [ -n "$CONFIG_FILE" ] && [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found."
    exit 1
fi

if [ -z "$JNAME" ] || [ -z "$IP" ]; then
    echo "Error: Name (-n) and IP (-i) are required."
    usage
fi

if [ -n "$F_BRIDGE" ] && [ -n "$F_VNET" ]; then
    echo "Error: Cannot use Bridge mode (-B) and VNET mode (-V) simultaneously."
    exit 1
fi

if [ -n "$F_BRIDGE" ]; then
    if ! ifconfig "$IF" 2>/dev/null | grep -q "groups: bridge"; then
        echo "Error: Interface $IF is not a bridge, but Bridge mode (-B) was specified."
        exit 1
    fi
fi

DEFAULT_ORDER="CREATE SETTINGS MOUNTS SYSRC TEMPLATES COPY CMD"

process_section() {
    local target_section=$1
    [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ] && return
    local in_section=0
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r')
        if [ "$line" = "#!$target_section" ]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ]; then
            case "$line" in
                "#!"*) break ;;
                ""|"#"*) continue ;;
            esac
            
            case "$target_section" in
                SETTINGS)
                    echo "Applying setting: $line"
                    eval "set -- $line"
                    bastille config "$JNAME" set "$@"
                    ;;
                MOUNTS)
                    echo "Applying mount: $line"
                    eval "set -- $line"
                    if ! bastille mount "$JNAME" "$@"; then
                        exit 1
                    fi
                    ;;
                SYSRC)
                    echo "Applying sysrc: $line"
                    eval "set -- $line"
                    bastille sysrc "$JNAME" "$@"
                    ;;
                TEMPLATES)
                    echo "Applying template: $line"
                    eval "set -- $line"
                    bastille template "$JNAME" "$@"
                    ;;
                COPY)
                    echo "Copying file: $line"
                    eval "set -- $line"
                    bastille cp "$JNAME" "$@"
                    ;;
                CMD)
                    echo "Executing in jail: $line"
                    bastille cmd "$JNAME" /bin/sh -c "$line"
                    ;;
            esac
        fi
    done < "$CONFIG_FILE"
}
get_order() {
    local custom_order=""
    local seen_header=0
    local order_processed=0
    local is_first_section=1
    local current_section=""

    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r')
        case "$line" in
            "#!"*) 
                current_section="${line#*!}"
                if [ "$current_section" = "ORDER" ]; then
                    if [ "$is_first_section" -eq 1 ]; then
                        order_processed=1
                        continue
                    else
                        echo "Warning: #!ORDER should be first, skipping!" >&2
                        continue
                    fi
                fi
                if [ "$order_processed" -eq 1 ]; then
                    break
                fi
                is_first_section=0
                [ "$order_processed" -eq 0 ] && break
                continue
                ;;
            ""|"#"*) 
                if [ "$order_processed" -eq 1 ] && [ -z "$line" ]; then
                    break
                fi
                continue 
                ;;
            *)
                if [ "$order_processed" -eq 1 ]; then
                    if [ "$line" = "ORDER" ]; then
                        echo "Warning: ORDER cannot be specified in ORDER, skipping!" >&2
                        continue
                    fi
                    custom_order="$custom_order $line"
                fi
                ;;
        esac
    done < "$CONFIG_FILE"

    if [ -n "$custom_order" ]; then
        echo "$custom_order"
    else
        echo "$DEFAULT_ORDER"
    fi
}

order=$(get_order)
echo "Execution Order: $order"

is_first_step=1
for section in $order; do
    if [ "$section" = "CREATE" ]; then
        if [ "$is_first_step" -eq 1 ]; then
            echo "Creating jail: $JNAME..."
            if ! bastille create $F_BRIDGE $F_VNET $F_MAC $F_DUAL $BOOT "$JNAME" "$RELEASE" "$IP" "$IF"; then
                exit 1
            fi
        else
            echo "Skipping CREATE task as it was not first in ORDER list." >&2
        fi
    elif [ "$section" = "RESTART" ]; then
        echo "Restarting jail $JNAME..."
        bastille restart "$JNAME"
    else
        process_section "$section"
    fi
    is_first_step=0
done

if [ -n "$F_RESTART" ]; then
    echo "Restarting jail $JNAME..."
    bastille restart "$JNAME"
fi
