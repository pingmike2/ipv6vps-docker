#!/bin/bash
set -e

echo "🚀 开始安装 Docker..."

# 1. 卸载旧版本
apt-get remove -y docker docker-engine docker.io containerd runc || true

# 2. 安装依赖
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# 3. 添加 Docker 官方 GPG key
mkdir -p /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

# 4. 添加 Docker 官方源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 更新并安装 Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. 测试 Docker
echo "✅ Docker 安装完成，测试运行 hello-world..."
docker run --rm hello-world

echo "🎉 Docker 已经可以正常使用！"
