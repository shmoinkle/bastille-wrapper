#!/bin/sh
# bastille-wrapper.sh - Bastille jail making wrapper
#
#   a bastillefile is great, but needs a little more to fully automate.
#   that's this script (i hope).
#
#   this script only does basic sanity checks so make sure your confs
#   are good (no bad paths or typos).

. "$(dirname "$0")/config.conf"

if [ ! -d "$BASTILLE_ROOT" ]; then
    echo "Error: Bastille root not a directory -> ${BASTILLE_ROOT}"
    exit 1
elif [ ! -d "${BASTILLE_ROOT}/templates/${TEMPLATE}" ]; then
    echo "Error: Template ${TEMPLATE} not found -> ${BASTILLE_ROOT}/templates/${TEMPLATE}"
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
F_FORCE=''
F_RESTART=''

destroy_jail() {
    if [ -n "$F_FORCE" ] && [ -n "$JNAME" ]; then
        echo "Critical error occurred. Force-cleaning jail $JNAME..."
        bastille destroy -f "$JNAME" >/dev/null 2>&1 || true
    fi
    exit 1
}

process_section() {
    [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ] && return
    local in_section=0
    while IFS= read -r line; do
        if [ "$line" = "#!$1" ]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ]; then
            case "$line" in
                ""|"#!"*) break ;;
                "#"*) continue ;;
            esac
            
            case "$1" in
                SETTINGS)
                    set -- $line
                    local s_key=$1
                    shift
                    local s_val="$*"
                    echo "Setting $s_key = $s_val"
                    bastille config "$JNAME" set "$s_key" "$s_val"
                    ;;
                MOUNTS)
                    # Parse: "host_dir" "jail_dir" [setting]
                    # We pass the full line to bastille mount for flexibility
                    echo "Mounting: $line"
                    if ! bastille mount "$JNAME" $line; then
                        destroy_jail
                    fi
                    ;;
                SYSRC|RCCONF)
                    echo "Applying to rc.conf: $line"
                    bastille sysrc "$JNAME" "$line"
                    ;;
                TEMPLATES)
                    echo "Applying template: $line"
                    bastille template "$JNAME" "$line"
                    ;;
                CMD)
                    echo "Executing in jail: $line"
                    bastille cmd "$JNAME" /bin/sh -c "$line" || true
                    ;;
            esac
        fi
    done < "$CONFIG_FILE"
}

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
    echo "  -F           Force clean (destroy jail on create/mount failure)"
    echo "  -x           Restart jail after creation"
    exit 1
}

while getopts "n:i:I:R:C:bBDMVFx" opt; do
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
        F) F_FORCE='1' ;;
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

echo "Creating jail: $JNAME..."
if ! bastille create $F_BRIDGE $F_VNET $F_MAC $F_DUAL $BOOT "$JNAME" "$RELEASE" "$IP" "$IF"; then
    destroy_jail
fi

process_section MOUNTS
process_section SETTINGS
process_section RCCONF
process_section TEMPLATES
process_section CMD

if [ -n "$F_RESTART" ]; then
    echo "Restarting jail $JNAME..."
    bastille restart "$JNAME"
fi
