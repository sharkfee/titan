#!/bin/bash

# 检查并安装 Docker
if ! command -v docker &> /dev/null; then
    echo "未检测到 Docker，正在安装..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    apt-get install -y docker.io
    echo "Docker 安装完成。"
else
    echo "Docker 已安装。"
fi

# 拉取Docker镜像
echo "正在拉取 Docker 镜像 nezha123/titan-edge..."
docker pull nezha123/titan-edge
echo "镜像拉取完成。"

# 提示用户输入存储目录
read -p "请输入存储目录的完整路径: " storageDir

# 提示用户输入容器数量
read -p "请输入要创建的容器数量 (1-5): " containerCount

# 检查容器数量是否有效
if [[ "$containerCount" -lt 1 ]] || [[ "$containerCount" -gt 5 ]]; then
    echo "容器数量必须在1至5之间。"
    exit 1
fi

# 提示用户输入身份码
read -p "请输入身份码: " identityCode

# 提示用户输入存储空间大小
read -p "请输入每个容器的存储空间大小 (例如：50GB): " storageSize

# 循环创建容器和对应的存储目录
for ((i=1; i<=containerCount; i++)); do
    folderName="titan$i"
    containerName="titan$i"
    
    # 创建对应的存储目录
    echo "创建存储目录：$storageDir/$folderName"
    mkdir -p "$storageDir/$folderName"
    
    # 运行容器，并设置自动重启
    echo "运行容器：$containerName"
    docker run -d --restart unless-stopped -v "$storageDir/$folderName:/root/.titanedge" --name $containerName nezha123/titan-edge
    
    # 等待容器启动
    echo "等待容器启动..."
    sleep 5
    
    # 绑定身份码
    echo "为容器 $containerName 绑定身份码..."
    docker exec $containerName titan-edge bind --hash=$identityCode https://api-test1.container1.titannet.io/api/v2/device/binding
    
    # 设置容器存储空间大小
    echo "设置容器 $containerName 的存储空间大小为 $storageSize..."
    docker exec $containerName titan-edge config set --storage-size $storageSize
    
    # 重启容器以应用更改
    echo "重启容器 $containerName..."
    docker restart $containerName
done

echo "所有操作已完成。"
