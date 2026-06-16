#!/bin/sh

# Trình quản lý khởi động AdGuard Home & SQM CAKE/FQ_CoDel trên Padavan
# Thiết kế tối ưu riêng cho Newifi D2

func_nvram_get() {
    nvram get "$1"
}

start_agh() {
    agh_enable=$(func_nvram_get agh_enable)
    agh_port=$(func_nvram_get agh_port)
    [ -z "$agh_port" ] && agh_port="3000"
    
    if [ "$agh_enable" = "1" ]; then
        # Kiểm tra file thực thi AdGuard Home trong hệ thống
        if [ ! -f "/usr/bin/AdGuardHome" ] && [ ! -f "/sbin/AdGuardHome" ]; then
            logger -t "AdGuardHome" "Lỗi: Không tìm thấy file chạy AdGuardHome trong /usr/bin hoặc /sbin!"
            return 1
        fi
        
        AGH_BIN="/usr/bin/AdGuardHome"
        [ ! -f "$AGH_BIN" ] && AGH_BIN="/sbin/AdGuardHome"
        
        # Thư mục cấu hình (Flash) và Thư mục Cache/Log (RAM)
        CONF_DIR="/etc/storage/AdGuardHome"
        WORK_DIR="/tmp/AdGuardHome"
        CONF_FILE="$CONF_DIR/AdGuardHome.yaml"
        
        mkdir -p "$CONF_DIR"
        mkdir -p "$WORK_DIR"
        
        if pidof AdGuardHome > /dev/null; then
            logger -t "AdGuardHome" "Dịch vụ đã đang chạy."
            return 0
        fi
        
        logger -t "AdGuardHome" "Đang khởi động AdGuard Home (Cổng WebUI: $agh_port)..."
        $AGH_BIN -c "$CONF_FILE" -w "$WORK_DIR" --no-check-update > /dev/null 2>&1 &
    fi
}

stop_agh() {
    if pidof AdGuardHome > /dev/null; then
        logger -t "AdGuardHome" "Đang dừng AdGuard Home..."
        killall -9 AdGuardHome > /dev/null 2>&1
    fi
}

start_sqm() {
    sqm_enable=$(func_nvram_get sqm_enable)
    sqm_download=$(func_nvram_get sqm_download)
    sqm_upload=$(func_nvram_get sqm_upload)
    sqm_qdisc=$(func_nvram_get sqm_qdisc)
    
    # Tự động nhận diện Interface mạng WAN
    wan_if=$(func_nvram_get wan_ifname)
    [ -z "$wan_if" ] && wan_if="eth3" # Mặc định cổng WAN của Newifi D2 thường là eth3
    
    if [ "$sqm_enable" = "1" ]; then
        logger -t "SQM" "Đang kích hoạt SQM trên $wan_if: Down $sqm_download Kbps, Up $sqm_upload Kbps ($sqm_qdisc)..."
        
        # Xóa cấu hình cũ trước khi nạp mới
        stop_sqm
        
        # Nạp các Module Kernel cần thiết
        modprobe ifb numifbs=1 > /dev/null 2>&1
        modprobe sch_cake > /dev/null 2>&1
        modprobe sch_fq_codel > /dev/null 2>&1
        modprobe act_mirred > /dev/null 2>&1
        modprobe cls_u32 > /dev/null 2>&1
        
        # Kích hoạt card mạng ảo ifb0 để định hình Download (Ingress)
        ip link set dev ifb0 up > /dev/null 2>&1
        
        # --- 1. ĐỊNH HÌNH UPLOAD (EGRESS trên cổng WAN) ---
        tc qdisc add dev "$wan_if" root handle 1: htb default 10 > /dev/null 2>&1
        tc class add dev "$wan_if" parent 1: classid 1:1 htb rate "${sqm_upload}kbit" ceil "${sqm_upload}kbit" > /dev/null 2>&1
        if [ "$sqm_qdisc" = "cake" ]; then
            tc qdisc add dev "$wan_if" parent 1:1 handle 10: cake bandwidth "${sqm_upload}kbit" besteffort lan rtt 100ms > /dev/null 2>&1
        else
            tc qdisc add dev "$wan_if" parent 1:1 handle 10: fq_codel limit 1024 target 5ms interval 100ms ecn > /dev/null 2>&1
        fi
        
        # --- 2. ĐỊNH HÌNH DOWNLOAD (INGRESS trên cổng WAN -> Chuyển hướng sang ifb0) ---
        tc qdisc add dev "$wan_if" handle ffff: ingress > /dev/null 2>&1
        tc filter add dev "$wan_if" parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb0 > /dev/null 2>&1
        
        # Áp dụng giới hạn tốc độ trên ifb0
        tc qdisc add dev ifb0 root handle 1: htb default 10 > /dev/null 2>&1
        tc class add dev ifb0 parent 1: classid 1:1 htb rate "${sqm_download}kbit" ceil "${sqm_download}kbit" > /dev/null 2>&1
        if [ "$sqm_qdisc" = "cake" ]; then
            tc qdisc add dev ifb0 parent 1:1 handle 10: cake bandwidth "${sqm_download}kbit" besteffort lan rtt 100ms > /dev/null 2>&1
        else
            tc qdisc add dev ifb0 parent 1:1 handle 10: fq_codel limit 1024 target 5ms interval 100ms ecn > /dev/null 2>&1
        fi
        
        logger -t "SQM" "Đã kích hoạt SQM thành công."
    fi
}

stop_sqm() {
    wan_if=$(func_nvram_get wan_ifname)
    [ -z "$wan_if" ] && wan_if="eth3"
    
    logger -t "SQM" "Đang gỡ bỏ SQM trên giao diện $wan_if..."
    
    # Xóa luật trên card WAN chính
    tc qdisc del dev "$wan_if" root > /dev/null 2>&1
    tc qdisc del dev "$wan_if" ingress > /dev/null 2>&1
    
    # Xóa luật trên card ảo ifb0
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
