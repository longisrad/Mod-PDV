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
DNSMASQ_MAIN_CONF="/tmp/dnsmasq.conf"
DNSMASQ_BAK="/tmp/dnsmasq.conf.agh_bak"

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

# ✅ Giải phóng port 53: tắt DNS dnsmasq, giữ DHCP
free_port53() {
    logger -t "adguardhome" "Freeing port 53 from dnsmasq..."

    # Backup dnsmasq.conf gốc
    [ -f "$DNSMASQ_MAIN_CONF" ] && cp "$DNSMASQ_MAIN_CONF" "$DNSMASQ_BAK"

    # Thêm port=0 để dnsmasq tắt DNS, chỉ giữ DHCP
    sed -i '/^port=/d' "$DNSMASQ_MAIN_CONF" 2>/dev/null
    echo "port=0" >> "$DNSMASQ_MAIN_CONF"

    # DHCP option 6: trỏ clients dùng router IP làm DNS (tức AGH)
    LAN_IP=$(nvram get lan_ipaddr)
    [ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"
    sed -i '/^dhcp-option=6/d' "$DNSMASQ_MAIN_CONF" 2>/dev/null
    echo "dhcp-option=6,$LAN_IP" >> "$DNSMASQ_MAIN_CONF"

    # Xóa upstream AGH cũ nếu có (không cần khi AGH nghe port 53)
    rm -f "$DNSMASQ_AGH_CONF" 2>/dev/null

    killall -HUP dnsmasq 2>/dev/null
    sleep 1
    logger -t "adguardhome" "Port 53 freed. dnsmasq now DHCP-only."
}

# ✅ Khôi phục dnsmasq: DNS + DHCP như ban đầu
restore_port53() {
    logger -t "adguardhome" "Restoring dnsmasq DNS on port 53..."

    if [ -f "$DNSMASQ_BAK" ]; then
        cp "$DNSMASQ_BAK" "$DNSMASQ_MAIN_CONF"
        rm -f "$DNSMASQ_BAK"
    else
        # Không có backup: chỉ xóa port=0
        sed -i '/^port=0/d' "$DNSMASQ_MAIN_CONF" 2>/dev/null
    fi

    rm -f "$DNSMASQ_AGH_CONF" 2>/dev/null
    killall -HUP dnsmasq 2>/dev/null
    sleep 1
    logger -t "adguardhome" "dnsmasq restored: DNS + DHCP on port 53."
}

agh_setup_dns() {
    if [ "$AGH_DNS_PORT" = "53" ]; then
        # AGH nghe port 53 trực tiếp → phải giải phóng dnsmasq
        free_port53
    else
        # AGH nghe port khác (5335) → dnsmasq làm upstream → AGH
        logger -t "adguardhome" "Setting dnsmasq upstream to 127.0.0.1#$AGH_DNS_PORT"
        mkdir -p /tmp/dnsmasq.d
        echo "server=127.0.0.1#$AGH_DNS_PORT" > "$DNSMASQ_AGH_CONF"
        killall -HUP dnsmasq 2>/dev/null
    fi
}

agh_teardown_dns() {
    if [ "$AGH_DNS_PORT" = "53" ]; then
        # Khôi phục dnsmasq về DNS+DHCP
        restore_port53
    else
        # Xóa upstream redirect
        if [ -f "$DNSMASQ_AGH_CONF" ]; then
            rm -f "$DNSMASQ_AGH_CONF"
            killall -HUP dnsmasq 2>/dev/null
            logger -t "adguardhome" "Removed dnsmasq upstream redirect"
        fi
    fi
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

    # ✅ Setup DNS trước khi start AGH
    agh_setup_dns
    sleep 1

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
    # ✅ Teardown DNS sau khi stop AGH
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
filtering:
  filtering_enabled: true
  protection_enabled: true
  filters_update_interval: 24
dhcp:
  enabled: false
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
    stop)   agh_stop    ;;
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
