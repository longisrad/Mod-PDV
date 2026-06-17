#!/bin/sh

# Trình quản lý khởi động AdGuard Home & SQM CAKE/FQ_CoDel trên Padavan
# Thiết kế tối ưu riêng cho Newifi D2

func_nvram_get() {
    nvram get "$1"
}

# ✅ HÀM MỚI: Tự động detect WAN interface đang thực sự dùng
get_wan_interface() {
    # Ưu tiên 1: Default route - chính xác nhất
    local iface=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)

    # Ưu tiên 2: Validate - interface phải có trạng thái UP
    if [ -n "$iface" ]; then
        ip link show "$iface" | grep -q "UP" || iface=""
    fi

    # Ưu tiên 3: Tìm interface có IP public
    if [ -z "$iface" ]; then
        iface=$(ip -o addr show | awk '
            $2 !~ /^(lo|br|eth0|ra|rai)/ &&
            $3 == "inet" &&
            $4 !~ /^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[01])\./ {
                print $2; exit
            }')
    fi

    # Fallback: thử theo thứ tự ưu tiên apclii0 trước
    if [ -z "$iface" ]; then
        for try_if in apclii0 apcli0 eth2.2 eth3 eth2; do
            if ip link show "$try_if" > /dev/null 2>&1; then
                iface="$try_if"
                break
            fi
        done
    fi

    echo "$iface"
}
    # Fallback cuối: Thử các interface phổ biến theo thứ tự
    if [ -z "$iface" ]; then
        for try_if in apclii0 apcli0 eth2.2 eth3 eth2; do
            if ip link show "$try_if" > /dev/null 2>&1; then
                iface="$try_if"
                break
            fi
        done
    fi

    echo "$iface"
}

start_agh() {
    if [ "$(func_nvram_get agh_enable)" != "1" ]; then
        logger -t "AdGuardHome" "Disabled, skipping."
        return 0
    fi
    if [ -f "/usr/bin/adguardhome.sh" ]; then
        sh /usr/bin/adguardhome.sh start
    fi
}

stop_agh() {
    if [ -f "/usr/bin/adguardhome.sh" ]; then
        sh /usr/bin/adguardhome.sh stop
    fi
}

start_sqm() {
    sqm_enable=$(func_nvram_get sqm_enable)
    sqm_download=$(func_nvram_get sqm_download)
    sqm_upload=$(func_nvram_get sqm_upload)
    sqm_qdisc=$(func_nvram_get sqm_qdisc)

    # ✅ Dùng hàm detect mới
    wan_if=$(get_wan_interface)

    if [ -z "$wan_if" ]; then
        logger -t "SQM" "Lỗi: Không tìm thấy WAN interface!"
        return 1
    fi

    if [ "$sqm_enable" = "1" ]; then
        logger -t "SQM" "Đang kích hoạt SQM trên $wan_if: Down $sqm_download Kbps, Up $sqm_upload Kbps ($sqm_qdisc)..."

        stop_sqm

        modprobe ifb numifbs=1 > /dev/null 2>&1
        modprobe sch_cake > /dev/null 2>&1
        modprobe sch_fq_codel > /dev/null 2>&1
        modprobe act_mirred > /dev/null 2>&1
        modprobe cls_u32 > /dev/null 2>&1

        ip link set dev ifb0 up > /dev/null 2>&1

        # EGRESS (upload)
        tc qdisc add dev "$wan_if" root handle 1: htb default 10 > /dev/null 2>&1
        tc class add dev "$wan_if" parent 1: classid 1:1 htb rate "${sqm_upload}kbit" ceil "${sqm_upload}kbit" > /dev/null 2>&1
        if [ "$sqm_qdisc" = "cake" ]; then
            tc qdisc add dev "$wan_if" parent 1:1 handle 10: cake bandwidth "${sqm_upload}kbit" besteffort lan rtt 100ms > /dev/null 2>&1
        else
            tc qdisc add dev "$wan_if" parent 1:1 handle 10: fq_codel limit 1024 target 5ms interval 100ms ecn > /dev/null 2>&1
        fi

        # INGRESS (download) -> ifb0
        tc qdisc add dev "$wan_if" handle ffff: ingress > /dev/null 2>&1
        tc filter add dev "$wan_if" parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb0 > /dev/null 2>&1

        tc qdisc add dev ifb0 root handle 1: htb default 10 > /dev/null 2>&1
        tc class add dev ifb0 parent 1: classid 1:1 htb rate "${sqm_download}kbit" ceil "${sqm_download}kbit" > /dev/null 2>&1
        if [ "$sqm_qdisc" = "cake" ]; then
            tc qdisc add dev ifb0 parent 1:1 handle 10: cake bandwidth "${sqm_download}kbit" besteffort lan rtt 100ms > /dev/null 2>&1
        else
            tc qdisc add dev ifb0 parent 1:1 handle 10: fq_codel limit 1024 target 5ms interval 100ms ecn > /dev/null 2>&1
        fi

        logger -t "SQM" "Đã kích hoạt SQM thành công trên $wan_if."
    fi
}

stop_sqm() {
    # ✅ Detect lại khi stop để đúng interface
    wan_if=$(get_wan_interface)
    [ -z "$wan_if" ] && wan_if="eth3"

    logger -t "SQM" "Đang gỡ bỏ SQM trên giao diện $wan_if..."

    tc qdisc del dev "$wan_if" root > /dev/null 2>&1
    tc qdisc del dev "$wan_if" ingress > /dev/null 2>&1
    tc qdisc del dev ifb0 root > /dev/null 2>&1
    ip link set dev ifb0 down > /dev/null 2>&1
}

case "$1" in
    start)
        start_agh
        start_sqm
        ;;
    stop)
        stop_agh
        stop_sqm
        ;;
    restart)
        stop_agh
        stop_sqm
        sleep 1
        start_agh
        start_sqm
        ;;
    *)
        echo "Sử dụng: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
