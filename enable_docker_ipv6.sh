#!/bin/bash
set -e

echo "=== 检查并启用 Docker IPv6 ==="

CONFIG_FILE="/etc/docker/daemon.json"

# 如果配置文件不存在就新建
if [ ! -f "$CONFIG_FILE" ]; then
    echo "{}" > "$CONFIG_FILE"
fi

# 先备份原配置
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
if docker network inspect bridge | grep -q '"EnableIPv6": true'; then
    echo "[OK] Docker bridge 网络已启用 IPv6"
else
    echo "[ERROR] Docker bridge 网络未启用 IPv6"
fi

# 宿主机 IPv6 出口
echo "=== 宿主机 IPv6 出口地址 ==="
host_ip=$(curl -6 -s --max-time 10 ifconfig.io || echo "获取失败")
echo "$host_ip"

if [ "$host_ip" != "获取失败" ]; then
    host_isp=$(curl -6 -s https://ipinfo.io/$host_ip/json | grep -E '"org"' | sed 's/.*: "\(.*\)".*/\1/')
    echo "宿主机出口 ISP/ASN: $host_isp"
fi

# 测试容器 IPv6 地址
echo "=== 测试容器 IPv6 地址 ==="
docker run --rm busybox ip -6 addr | grep "inet6" || echo "容器未分配 IPv6 地址"

# 容器 IPv6 出口
echo "=== 容器 IPv6 出口地址 ==="
container_ip=$(docker run --rm curlimages/curl -6 -s --max-time 10 ifconfig.io || echo "获取失败")
echo "$container_ip"

if [ "$container_ip" != "获取失败" ]; then
    container_isp=$(docker run --rm curlimages/curl -6 -s https://ipinfo.io/$container_ip/json | grep -E '"org"' | sed 's/.*: "\(.*\)".*/\1/')
    echo "容器出口 ISP/ASN: $container_isp"
fi

# 判断是否和宿主机一致
if [ "$host_ip" = "$container_ip" ] && [ "$host_ip" != "获取失败" ]; then
    echo "[OK] 容器出口与宿主机一致 → 可能走的是 WARP"
else
    echo "[INFO] 容器出口与宿主机不同"
fi

# 测试 IPv6 连通性
echo "=== 容器 IPv6 连通性测试 ==="
docker run --rm busybox ping6 -c 3 google.com || echo "容器 IPv6 出口不可用"