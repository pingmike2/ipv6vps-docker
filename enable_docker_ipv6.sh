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

# 检查 IPv6 是否启用
echo "=== Docker 信息 ==="
docker info | grep IPv6 || echo "未检测到 IPv6"

# 查看 bridge 网络
echo "=== Docker 默认网络配置 ==="
docker network inspect bridge | grep -E 'EnableIPv6|Subnet'

# 启动测试容器
echo "=== 启动测试容器 ==="
docker run --rm busybox ping6 -c 3 google.com || echo "容器 IPv6 测试失败"
