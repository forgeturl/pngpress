#!/bin/bash

# 检查必要的工具是否安装
check_dependencies() {
    echo "检查必要的工具..."
    
    # 检查jq
    if ! command -v jq &> /dev/null; then
        echo "安装jq..."
        brew install jq
    fi
    
    # 检查aliyun-cli
    if ! command -v aliyun &> /dev/null; then
        echo "安装aliyun-cli..."
        brew install aliyun-cli
    fi
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        echo "安装curl..."
        brew install curl
    fi
}

# 创建必要的目录
mkdir -p ./pngpress

# 检查参数
if [ $# -eq 0 ]; then
    echo "错误：请提供PNG文件路径"
    echo "用法: ./presspng.sh file.png"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$1" ]; then
    echo "错误：文件 $1 不存在"
    exit 1
fi

# 检查文件扩展名
if [[ ! "$1" =~ \.png$ ]]; then
    echo "错误：文件必须是PNG格式"
    exit 1
fi

# 检查配置文件
if [ ! -f "config.json" ]; then
    echo "错误：config.json 配置文件不存在"
    exit 1
fi

# 检查依赖
check_dependencies

# 读取配置
TINYPNG_API_KEY=$(jq -r '.tinypng.apiKey' config.json)
ALIYUN_ACCESS_KEY_ID=$(jq -r '.aliyun.accessKeyId' config.json)
ALIYUN_ACCESS_KEY_SECRET=$(jq -r '.aliyun.accessKeySecret' config.json)
BUCKET=$(jq -r '.aliyun.bucket' config.json)
PREFIX=$(jq -r '.aliyun.prefix' config.json)
CDN_DOMAIN=$(jq -r '.aliyun.cdnDomain' config.json)

# 检查配置是否完整
if [ "$TINYPNG_API_KEY" = "YOUR_TINYPNG_API_KEY" ] || \
   [ "$ALIYUN_ACCESS_KEY_ID" = "YOUR_ACCESS_KEY_ID" ] || \
   [ "$ALIYUN_ACCESS_KEY_SECRET" = "YOUR_ACCESS_KEY_SECRET" ] || \
   [ "$BUCKET" = "YOUR_BUCKET_NAME" ] || \
   [ "$CDN_DOMAIN" = "YOUR_CDN_DOMAIN" ]; then
    echo "错误：请先配置config.json文件"
    exit 1
fi

# 获取当前日期
DATE=$(date +%y%m%d)

# 压缩PNG
echo "正在压缩PNG文件..."
COMPRESSED_FILE="./pngpress/${DATE}$(md5 -q "$1").png"
curl -u "api:$TINYPNG_API_KEY" --data-binary @"$1" -i https://api.tinify.com/shrink > "$COMPRESSED_FILE"

# 检查压缩是否成功
if [ ! -f "$COMPRESSED_FILE" ]; then
    echo "错误：PNG压缩失败"
    exit 1
fi

echo "PNG压缩成功，文件保存在: $COMPRESSED_FILE"

# 上传到阿里云OSS
echo "正在上传到阿里云OSS..."
aliyun oss cp "$COMPRESSED_FILE" "oss://$BUCKET/$PREFIX/$(basename "$COMPRESSED_FILE")"

# 生成CDN URL
CDN_URL="http://$CDN_DOMAIN/$PREFIX/$(basename "$COMPRESSED_FILE")"
echo "上传成功！CDN URL: $CDN_URL"

# 复制URL到剪贴板
echo "$CDN_URL" | pbcopy
echo "URL已复制到剪贴板" 