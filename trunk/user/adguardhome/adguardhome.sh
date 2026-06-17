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

# Doc cau hinh tu nvram (Đồng bộ với Web UI)
AGH_ENABLED=$(nvram get agh_enable)
AGH_PORT=$(nvram get agh_port)
AGH_DNS_PORT=$(nvram get agh_dns_port)
AGH_USER=$(nvram get agh_user)
AGH_PASS=$(nvram get agh_pass)

# Gia tri mac dinh neu chua set
[ -z "$AGH_PORT" ]     && AGH_PORT="3000"
[ -z "$AGH_DNS_PORT" ] && AGH_DNS_PORT="5335" # Đổi cổng DNS mặc định sang 53 nếu bạn muốn AGH làm DNS chính trực tiếp, hoặc giữ 5335 tùy nhu cầu của bạn
[ -z "$AGH_USER" ]     && AGH_USER="admin"
[ -z "$AGH_PASS" ]     && AGH_PASS=""

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

	# Tao thu muc RAM cho cache/log
	mkdir -p "$AGH_WORK_DIR"

	# Tao thu muc flash cho config neu chua co
	mkdir -p "$AGH_CONF_DIR"

	# Tao config mac dinh neu chua co
	if [ ! -f "$AGH_CONF" ]; then
		agh_create_config
	fi

	# Chay AdGuard Home
	"$AGH_BIN" \
		--config "$AGH_CONF" \
		--work-dir "$AGH_WORK_DIR" \
		--no-check-update \
		--pidfile "$AGH_PID" \
		>> "$AGH_LOG" 2>&1 &

	sleep 2

	if agh_is_running; then
		logger -t "adguardhome" "Started successfully (DNS port: $AGH_DNS_PORT, Web port: $AGH_PORT)"
		# Neu dns port la 53 thi redirect dnsmasq -> adguardhome
		agh_setup_dns
	else
		logger -t "adguardhome" "ERROR: Failed to start"
		return 1
	fi
}

agh_stop() {
	logger -t "adguardhome" "Stopping AdGuard Home..."

	# Huy dns redirect truoc
	agh_teardown_dns

	if [ -f "$AGH_PID" ]; then
		kill $(cat "$AGH_PID") 2>/dev/null
		rm -f "$AGH_PID"
	else
		killall AdGuardHome 2>/dev/null
	fi

	sleep 1
	logger -t "adguardhome" "Stopped"
}

agh_restart() {
	agh_stop
	sleep 1
	agh_start
}

agh_is_running() {
	if [ -f "$AGH_PID" ]; then
		local pid=$(cat "$AGH_PID")
		[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
	fi
	pidof AdGuardHome > /dev/null 2>&1
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

	# Lay IP LAN
	LAN_IP=$(nvram get lan_ipaddr)
	[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"

	cat > "$AGH_CONF" << EOF
http:
  pprof:
    port: 6060
    enabled: false
  address: 0.0.0.0:${AGH_PORT}
  session_ttl: 720h
users:
  - name: ${AGH_USER}
    password: ${AGH_PASS}
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: ""
theme: auto
dns:
  bind_hosts:
    - 0.0.0.0
  port: ${AGH_DNS_PORT}
  anonymize_client_ip: false
  ratelimit: 20
  ratelimit_subnet_len_ipv4: 24
  ratelimit_subnet_len_ipv6: 56
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - https://dns10.quad9.net/dns-query
    - https://cloudflare-dns.com/dns-query
  upstream_dns_file: ""
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 2620:fe::10
    - 2620:fe::fe:10
  fallback_dns: []
  upstream_mode: load_balance
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: true
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: false
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  bootstrap_prefer_ipv6: false
  use_private_ptr_resolvers: true
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
  serve_plain_dns: true
  hostsfile_enabled: true
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 784
  port_dnscrypt: 0
  dnscrypt_config_file: ""
  allow_unencrypted_doh: false
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
querylog:
  dir_path: ${AGH_WORK_DIR}
  ignored: []
  interval: 24h
  size_memory: 1000
  enabled: true
  file_enabled: false
statistics:
  dir_path: ${AGH_WORK_DIR}
  ignored: []
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
  interface_name: ""
  local_domain_name: lan
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
filtering:
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_services:
    schedule:
      time_zone: Local
    ids: []
  protection_disabled_until: null
  safe_search:
    enabled: false
    bing: true
    duckduckgo: true
    ecosia: true
    google: true
    pixabay: true
    yandex: true
    youtube: true
  blocking_mode: default
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites: []
  safe_browsing_cache_size: 1048576
  safe_search_cache_size: 1048576
  parental_cache_size: 1048576
  cache_time: 30
  filters_update_interval: 24
  blocked_response_ttl: 10
  filtering_enabled: true
  parental_enabled: false
  safe_browsing_enabled: false
log:
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 28
EOF

	logger -t "adguardhome" "Default config created at $AGH_CONF"
}

agh_setup_dns() {
	# Neu AGH dung DNS port 5335, chuyen dnsmasq -> AGH
	# dnsmasq se lam upstream den AGH thay vi ra ngoai truc tiep
	if [ "$AGH_DNS_PORT" != "53" ]; then
		logger -t "adguardhome" "Setting dnsmasq upstream to 127.0.0.1#$AGH_DNS_PORT"
		# Them upstream dnsmasq -> AGH
		echo "server=127.0.0.1#$AGH_DNS_PORT" > /tmp/dnsmasq.d/adguardhome.conf
		# Reload dnsmasq
		killall -HUP dnsmasq 2>/dev/null
	fi
}

agh_teardown_dns() {
	# Xoa upstream redirect khi AGH stop
	if [ -f /tmp/dnsmasq.d/adguardhome.conf ]; then
		rm -f /tmp/dnsmasq.d/adguardhome.conf
		killall -HUP dnsmasq 2>/dev/null
		logger -t "adguardhome" "Removed dnsmasq upstream redirect"
	fi
}

agh_save_config() {
	# Backup config tu RAM ve flash (goi khi shutdown)
	logger -t "adguardhome" "Config is stored on flash, no backup needed"
}

###########################
# Main
###########################
case "$1" in
	start)
		[ "$AGH_ENABLED" = "1" ] && agh_start || logger -t "adguardhome" "Disabled in config"
		;;
	stop)
		agh_stop
		;;
	restart)
		agh_restart
		;;
	status)
		agh_status
		;;
	enable)
		nvram set adguardhome_enable=1
		nvram commit
		agh_start
		;;
	disable)
		nvram set adguardhome_enable=0
		nvram commit
		agh_stop
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status|enable|disable}"
		exit 1
		;;
esac

exit 0
