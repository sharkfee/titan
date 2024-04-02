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

# 列出所有titan相关的容器
titanContainers=$(docker ps -a --filter "name=titan" --format "{{.Names}}")

# 如果存在titan容器，则删除并拉取最新镜像
if [ -n "$titanContainers" ]; then
    # 提示用户输入存储目录
    read -p "请输入原先设置的存储目录: " storageDir

    # 检查存储目录下是否存在按脚本规则命名的存储文件夹
    for containerName in $titanContainers; do
        if [ ! -d "$storageDir/$containerName" ]; then
            echo "在存储目录下未找到与容器名称相对应的文件夹：$containerName"
            exit 1
        fi
    done

    echo "检测到现有的 titan 容器，正在删除..."
    docker rm -f $titanContainers
    echo "现有的 titan 容器已删除。"

    # 拉取最新Docker镜像
    echo "正在拉取最新的 Docker 镜像 nezha123/titan-edge..."
    docker pull nezha123/titan-edge
    echo "镜像拉取完成。"

    # 重新创建之前的titan容器
    for containerName in $titanContainers; do
        echo "重新创建容器：$containerName"
        # 运行容器，并设置自动重启
        docker run -d --restart unless-stopped -v "$storageDir/$containerName:/root/.titanedge" --name $containerName nezha123/titan-edge
    done
else
    # 没有检测到titan容器，请求用户输入信息来创建新的容器
    echo "没有检测到现有的 titan 容器。"

    # 提示用户输入存储目录
    read -p "请输入存储目录的完整路径: " storageDir

    # 提示用户输入容器数量
    read -p "请输入要创建的容器数量 (1-5): " containerCount

    # 检查容器数量是否有效
    if [[ "$containerCount" -lt 1 ]] || [[ "$containerCount" -gt 5 ]]; then
        echo "容器数量必须在1至5之间。"
        exit 1
    fi

    # 提示用户输入身份码，允许为空
    read -p "请输入身份码（如果不需要绑定身份，请留空）: " identityCode

    # 提示用户输入存储空间大小（单位：GB），并确保输入是一个整数
    while :; do
        read -p "请输入每个容器的存储空间大小（单位：GB，必须为整数）: " storageSizeGB
        if [[ "$storageSizeGB" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "错误：存储空间大小必须是一个整数。"
        fi
    done

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

        # 如果提供了身份码，则执行绑定操作
        if [ -n "$identityCode" ]; then
            echo "为容器 $containerName 绑定身份码..."
            docker exec $containerName titan-edge bind --hash=$identityCode https://api-test1.container1.titannet.io/api/v2/device/binding
        else
            echo "跳过绑定身份码。"
        fi

        # 设置容器存储空间大小
        storageSize="${storageSizeGB}GB"
        echo "设置容器 $containerName 的存储空间大小为 $storageSize..."
        docker exec $containerName titan-edge config set --storage-size $storageSize

        # 重启容器以应用更改
        echo "重启容器 $containerName..."
        docker restart $containerName
    done

    echo "所有操作已完成。"
fi
