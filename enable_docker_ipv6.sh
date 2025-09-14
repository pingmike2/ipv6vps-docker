#!/bin/bash
set -e

echo "=== 检查并启用 Docker IPv6 ==="

CONFIG_FILE="/etc/docker/daemon.json"

# 如果配置文件不存在就新建
[ ! -f "$CONFIG_FILE" ] && echo "{}" > "$CONFIG_FILE"

# 备份原配置
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%s)"

# 写入 IPv6 配置
cat > "$CONFIG_FILE" <<EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:dead:beef::/48"
}
EOF

echo "[OK] 已写入 $CONFIG_FILE"

# 重启 Docker
systemctl restart docker
sleep 3

echo "=== Docker IPv6 检测 ==="
docker network inspect bridge | grep -q '"EnableIPv6": true' \
  && echo "[OK] Docker bridge 网络已启用 IPv6" \
  || echo "[ERROR] Docker bridge 网络未启用 IPv6"

# 宿主机 IPv6 出口
echo "=== 宿主机 IPv6 出口地址 ==="
host_ip=$(curl -6 -s --max-time 10 ifconfig.io || echo "获取失败")
echo "$host_ip"

# 获取宿主机 ISP/ASN
host_isp=$(curl -6 -s https://ipinfo.io/$host_ip/json 2>/dev/null | grep -E '"org"' | sed 's/.*: "\(.*\)".*/\1/')
[ -z "$host_isp" ] && host_isp="未知"
echo "宿主机出口 ISP/ASN: $host_isp"

# 测试容器 IPv6 地址
echo "=== 容器 IPv6 地址 ==="
docker run --rm busybox ip -6 addr | grep "inet6" || echo "容器未分配 IPv6 地址"

# 容器 IPv6 出口
echo "=== 容器 IPv6 出口地址 ==="
container_ip=$(docker run --rm curlimages/curl -6 -s --max-time 10 ifconfig.io || echo "获取失败")
echo "$container_ip"

# 获取容器 ISP/ASN
container_isp=$(docker run --rm curlimages/curl -6 -s https://ipinfo.io/$container_ip/json 2>/dev/null | grep -E '"org"' | sed 's/.*: "\(.*\)".*/\1/')
[ -z "$container_isp" ] && container_isp="未知"
echo "容器出口 ISP/ASN: $container_isp"

# 判断是否和宿主机一致
if [ "$host_ip" = "$container_ip" ] && [ "$host_ip" != "获取失败" ]; then
    echo "[OK] 容器出口与宿主机一致 → 可能走的是 WARP"
else
    echo "[INFO] 容器出口与宿主机不同"
fi

# 测试容器 IPv6 连通性
echo "=== 容器 IPv6 连通性测试 ==="
docker run --rm busybox ping6 -c 3 google.com || echo "容器 IPv6 出口不可用"