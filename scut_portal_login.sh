#!/bin/sh
set -u

CONFIG_FILE="${CONFIG_FILE:-/etc/scut_portal.conf}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck source=/dev/null
. "$CONFIG_FILE"

IFACE="${IFACE:-apclix0}"
AC_NAME="${AC_NAME:-example_ac}"
HOST="${HOST:-portal.example.edu.cn}"
HOST_IP="${HOST_IP:-}"
PORT="${PORT:-802}"
LOGIN_URL="https://${HOST}:${PORT}/eportal/portal/login"

LOG="${LOG:-/tmp/scut_portal_login.log}"
LOCK_DIR="/tmp/scut_portal_login.lock"
FAIL_COUNT_FILE="/tmp/scut_portal_fail_count"

CURL_BIN="${CURL_BIN:-curl}"
TIMEOUT_CHECK="${TIMEOUT_CHECK:-5}"
TIMEOUT_LOGIN="${TIMEOUT_LOGIN:-12}"
MAX_IP_RETRY="${MAX_IP_RETRY:-3}"
FAIL_RESET_THRESHOLD="${FAIL_RESET_THRESHOLD:-2}"
LOGIN_ATTEMPTS="${LOGIN_ATTEMPTS:-3}"
RETRY_SLEEP="${RETRY_SLEEP:-3}"
ENABLE_IFACE_RESET="${ENABLE_IFACE_RESET:-0}"
DEBUG="${DEBUG:-0}"
PORTAL_USER="${PORTAL_USER:-${USER:-}}"
PORTAL_PASS="${PORTAL_PASS:-${PASS:-}}"

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG"
}

cleanup() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

acquire_lock() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        exit 0
    fi
}

get_fail_count() {
    [ -f "$FAIL_COUNT_FILE" ] && cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0
}

set_fail_count() {
    echo "$1" > "$FAIL_COUNT_FILE"
}

inc_fail_count() {
    COUNT="$(get_fail_count)"
    COUNT=$((COUNT + 1))
    set_fail_count "$COUNT"
    echo "$COUNT"
}

reset_fail_count() {
    set_fail_count 0
}

require_config() {
    if [ -z "${PORTAL_USER:-}" ] || [ -z "${PORTAL_PASS:-}" ]; then
        log "missing required config: PORTAL_USER or PORTAL_PASS"
        exit 1
    fi
}

get_user_ip() {
    i=1
    while [ "$i" -le "$MAX_IP_RETRY" ]; do
        IP="$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
        if [ -n "${IP:-}" ]; then
            echo "$IP"
            return 0
        fi
        sleep 2
        i=$((i + 1))
    done
    return 1
}

get_user_mac() {
    MAC="$(cat /sys/class/net/"$IFACE"/address 2>/dev/null | tr '[:lower:]' '[:upper:]' | tr -d ':')"
    [ -n "${MAC:-}" ] && echo "$MAC" || echo "000000000000"
}

check_online_204() {
    CODE="$($CURL_BIN -4 --noproxy '*' --interface "$IFACE" -m "$TIMEOUT_CHECK" -s -o /dev/null -w '%{http_code}' 'http://connect.rom.miui.com/generate_204' 2>/dev/null || echo 000)"
    [ "$CODE" = "204" ]
}

check_online_msft() {
    BODY="$($CURL_BIN -4 --noproxy '*' --interface "$IFACE" -m "$TIMEOUT_CHECK" -s 'http://www.msftconnecttest.com/connecttest.txt' 2>/dev/null || true)"
    echo "$BODY" | grep -q 'Microsoft Connect Test'
}

check_online() {
    check_online_204 || check_online_msft
}

reset_iface() {
    if [ "$ENABLE_IFACE_RESET" != "1" ]; then
        log "skip interface reset because ENABLE_IFACE_RESET=0"
        return 0
    fi

    log "too many failures, resetting interface iface=$IFACE"
    ifdown "$IFACE" 2>/dev/null || true
    sleep 3
    ifup "$IFACE" 2>/dev/null || true
    sleep 8
}

portal_login_once() {
    USER_IP="$1"
    USER_MAC="$2"
    TS="$(date +%s)"

    RESOLVE_ARG=""
    if [ -n "${HOST_IP:-}" ]; then
        RESOLVE_ARG="--resolve ${HOST}:${PORT}:${HOST_IP}"
    fi

    RESP="$($CURL_BIN -k -4 --noproxy '*' --interface "$IFACE" -m "$TIMEOUT_LOGIN" -sS --get "$LOGIN_URL" \
        ${RESOLVE_ARG} \
        -H "Referer: https://${HOST}/" \
        -H 'User-Agent: Mozilla/5.0' \
        --data-urlencode "callback=dr1003" \
        --data-urlencode "login_method=1" \
        --data-urlencode "user_account=${PORTAL_USER}" \
        --data-urlencode "user_password=${PORTAL_PASS}" \
        --data-urlencode "wlan_user_ip=${USER_IP}" \
        --data-urlencode "wlan_user_ipv6=" \
        --data-urlencode "wlan_user_mac=${USER_MAC}" \
        --data-urlencode "wlan_ac_ip=" \
        --data-urlencode "wlan_ac_name=${AC_NAME}" \
        --data-urlencode 'jsVersion=4.1.3' \
        --data-urlencode 'terminal_type=1' \
        --data-urlencode 'lang=zh-cn' \
        --data-urlencode 'mac_type=0' \
        --data-urlencode "program_index=aGPKgC${TS}" \
        --data-urlencode "page_index=OYOGQG${TS}" \
        --data-urlencode 'v=1500' \
        2>&1)"
    RC=$?
    return "$RC"
}

handle_failure() {
    REASON="$1"
    COUNT="$(inc_fail_count)"

    if [ "$DEBUG" = "1" ]; then
        log "login failure reason=$REASON fail_count=$COUNT response=$(printf '%s' "$RESP" | tr '\r\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-160)"
    else
        log "login failure reason=$REASON fail_count=$COUNT"
    fi

    if [ "$COUNT" -ge "$FAIL_RESET_THRESHOLD" ]; then
        reset_iface
        reset_fail_count
        log "failure counter reset"
    fi

    exit 1
}

main() {
    acquire_lock
    require_config

    USER_IP="$(get_user_ip)" || {
        RESP="no_ipv4"
        handle_failure "no_ipv4"
    }

    if check_online; then
        reset_fail_count
        exit 0
    fi

    USER_MAC="$(get_user_mac)"

    ATTEMPT=1
    while [ "$ATTEMPT" -le "$LOGIN_ATTEMPTS" ]; do
        portal_login_once "$USER_IP" "$USER_MAC"

        if check_online; then
            if [ "$ATTEMPT" -eq 1 ]; then
                log "login success iface=$IFACE ip=$USER_IP"
            else
                log "login success after retry iface=$IFACE ip=$USER_IP attempt=$ATTEMPT"
            fi
            reset_fail_count
            exit 0
        fi

        if echo "$RESP" | grep -q '"msg":"512"'; then
            log "soft success or already-online msg=512 iface=$IFACE ip=$USER_IP"
            exit 0
        fi

        if [ "$ATTEMPT" -lt "$LOGIN_ATTEMPTS" ]; then
            sleep "$RETRY_SLEEP"
            USER_IP="$(get_user_ip)" || {
                RESP="attempt_${ATTEMPT}_retry_no_ipv4"
                handle_failure "retry_no_ipv4"
            }
            USER_MAC="$(get_user_mac)"
        fi

        ATTEMPT=$((ATTEMPT + 1))
    done

    handle_failure "portal_login_failed"
}

main "$@"
