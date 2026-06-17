#!/bin/sh
#############################################################
# AdGuard Home control script for Padavan firmware
# Config: /etc/storage/adguardhome/  (flash)
# Cache/Log: /tmp/adguardhome/       (RAM)
#############################################################

AGH_BIN="/usr/bin/AdGuardHome"
AGH_CONF_DIR="/etc/storage/adguardhome"
AGH_CONF="$AGH_CONF_DIR/AdGuardHome.yaml"
AGH_WORK_DIR="/tmp/adguardhome"
AGH_PID="/var/run/adguardhome.pid"
AGH_LOG="$AGH_WORK_DIR/adguardhome.log"
DNSMASQ_AGH_CONF="/tmp/dnsmasq.d/adguardhome.conf"

AGH_ENABLED=$(nvram get agh_enable)
AGH_PORT=$(nvram get agh_port)
AGH_DNS_PORT=$(nvram get agh_dns_port)
AGH_USER=$(nvram get agh_user)
AGH_PASS=$(nvram get agh_pass)

[ -z "$AGH_PORT" ]     && AGH_PORT="3000"
[ -z "$AGH_DNS_PORT" ] && AGH_DNS_PORT="53"
[ -z "$AGH_USER" ]     && AGH_USER="admin"
[ -z "$AGH_PASS" ]     && AGH_PASS=""

agh_is_running() {
    if [ -f "$AGH_PID" ]; then
        local pid=$(cat "$AGH_PID")
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
    fi
    pidof AdGuardHome > /dev/null 2>&1
}

agh_setup_dns() {
    if [ "$AGH_DNS_PORT" != "53" ]; then
        # AGH nghe port khác → dnsmasq upstream → AGH
        logger -t "adguardhome" "Setting dnsmasq upstream to 127.0.0.1#$AGH_DNS_PORT"
        mkdir -p /tmp/dnsmasq.d
        echo "server=127.0.0.1#$AGH_DNS_PORT" > "$DNSMASQ_AGH_CONF"
        killall -HUP dnsmasq 2>/dev/null
    fi
    # Port 53: services_ex.c đã tự set port=0 cho dnsmasq
}

agh_teardown_dns() {
    if [ "$AGH_DNS_PORT" != "53" ]; then
        if [ -f "$DNSMASQ_AGH_CONF" ]; then
            rm -f "$DNSMASQ_AGH_CONF"
            killall -HUP dnsmasq 2>/dev/null
            logger -t "adguardhome" "Removed dnsmasq upstream redirect"
        fi
    fi
    # Port 53: dnsmasq tự khôi phục khi firewall restart
}

agh_start() {
    if [ ! -f "$AGH_BIN" ]; then
        logger -t "adguardhome" "ERROR: binary not found at $AGH_BIN"
        return 1
    fi

    if agh_is_running; then
        logger -t "adguardhome" "Already running, skipping start"
        return 0
    fi

    logger -t "adguardhome" "Starting AdGuard Home..."
    mkdir -p "$AGH_WORK_DIR"
    mkdir -p "$AGH_CONF_DIR"

    [ ! -f "$AGH_CONF" ] && agh_create_config

    agh_setup_dns
    sleep 2

    "$AGH_BIN" \
        --config "$AGH_CONF" \
        --work-dir "$AGH_WORK_DIR" \
        --no-check-update \
        --pidfile "$AGH_PID" \
        >> "$AGH_LOG" 2>&1 &

    sleep 2

    if agh_is_running; then
        logger -t "adguardhome" "Started successfully (DNS: $AGH_DNS_PORT, Web: $AGH_PORT)"
    else
        logger -t "adguardhome" "ERROR: Failed to start, restoring DNS..."
        agh_teardown_dns
        return 1
    fi
}

agh_stop() {
    logger -t "adguardhome" "Stopping AdGuard Home..."
    if [ -f "$AGH_PID" ]; then
        kill $(cat "$AGH_PID") 2>/dev/null
        rm -f "$AGH_PID"
    else
        killall AdGuardHome 2>/dev/null
    fi
    sleep 1
    agh_teardown_dns
    logger -t "adguardhome" "Stopped"
}

agh_restart() {
    agh_stop
    sleep 1
    agh_start
}

agh_status() {
    if agh_is_running; then
        echo "AdGuard Home is running (PID: $(cat $AGH_PID 2>/dev/null || pidof AdGuardHome))"
        echo "Web UI: http://$(nvram get lan_ipaddr):$AGH_PORT"
        echo "DNS port: $AGH_DNS_PORT"
    else
        echo "AdGuard Home is stopped"
    fi
}

agh_create_config() {
    logger -t "adguardhome" "Creating default config..."

    LAN_IP=$(nvram get lan_ipaddr)
    [ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"

    if [ -z "$AGH_PASS" ]; then
        USERS_BLOCK="users: []"
    else
        USERS_BLOCK="users:
  - name: ${AGH_USER}
    password: ${AGH_PASS}"
    fi

    cat > "$AGH_CONF" << EOF
http:
  address: 0.0.0.0:${AGH_PORT}
  session_ttl: 720h
${USERS_BLOCK}
auth_attempts: 5
block_auth_min: 15
dns:
  bind_hosts:
    - 0.0.0.0
  port: ${AGH_DNS_PORT}
  upstream_dns:
    - https://dns10.quad9.net/dns-query
    - https://cloudflare-dns.com/dns-query
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
  cache_size: 4194304
  cache_optimistic: true
  ratelimit: 20
  refuse_any: true
  serve_plain_dns: true
querylog:
  dir_path: ${AGH_WORK_DIR}
  interval: 24h
  enabled: true
  file_enabled: false
statistics:
  dir_path: ${AGH_WORK_DIR}
  interval: 24h
  enabled: true
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
filtering:
  filtering_enabled: true
  protection_enabled: true
  filters_update_interval: 24
log:
  enabled: true
  max_size: 100
os:
  rlimit_nofile: 0
schema_version: 29
EOF

    logger -t "adguardhome" "Config created at $AGH_CONF"
}

###########################
# Main
###########################
case "$1" in
    start)
        [ "$AGH_ENABLED" = "1" ] && agh_start || logger -t "adguardhome" "Disabled in config"
        ;;
    stop)    agh_stop    ;;
    restart) agh_restart ;;
    status)  agh_status  ;;
    enable)
        nvram set agh_enable=1
        nvram commit
        agh_start
        ;;
    disable)
        nvram set agh_enable=0
        nvram commit
        agh_stop
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|enable|disable}"
        exit 1
        ;;
esac

exit 0
