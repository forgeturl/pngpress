#!/bin/bash
set -ve

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
        # 其他安装方式 https://help.aliyun.com/zh/cli/install-cli-on-macos
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
    echo "错误：请提供图片文件路径"
    echo "用法: ./presspng.sh file.[png|jpg|jpeg|webp|avif]"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$1" ]; then
    echo "错误：文件 $1 不存在"
    exit 1
fi

# 检查文件扩展名
if [[ ! "$1" =~ \.(png|jpg|jpeg|webp|avif)$ ]]; then
    echo "错误：文件必须是PNG、JPEG、WebP或AVIF格式"
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
REGION=$(jq -r '.aliyun.region' config.json)

# 检查配置是否完整
if [ "$TINYPNG_API_KEY" = "YOUR_TINYPNG_API_KEY" ] || \
   [ "$ALIYUN_ACCESS_KEY_ID" = "YOUR_ACCESS_KEY_ID" ] || \
   [ "$ALIYUN_ACCESS_KEY_SECRET" = "YOUR_ACCESS_KEY_SECRET" ] || \
   [ "$BUCKET" = "YOUR_BUCKET_NAME" ] || \
   [ "$CDN_DOMAIN" = "YOUR_CDN_DOMAIN" ] || \
   [ "$REGION" = "YOUR_REGION" ]; then
    echo "错误：请先配置config.json文件"
    exit 1
fi

# 配置阿里云CLI
# 阿里云配置文件在 .aliyun/config.json
echo "配置阿里云CLI..."
aliyun configure set --mode AK --region "$REGION" --access-key-id "$ALIYUN_ACCESS_KEY_ID" --access-key-secret "$ALIYUN_ACCESS_KEY_SECRET"

# 获取当前日期
DATE=$(date +%y%m%d)

# 获取文件扩展名
FILE_EXT="${1##*.}"

# 压缩图片
echo "正在压缩图片文件..."
TEMP_RESPONSE=$(mktemp)
curl -u "api:$TINYPNG_API_KEY" --data-binary @"$1" -i https://api.tinify.com/shrink --dump-header /dev/stdout > "$TEMP_RESPONSE"

# 检查响应状态
if ! grep -q "HTTP/2 201" "$TEMP_RESPONSE"; then
    echo "错误：TinyPNG API请求失败"
    cat "$TEMP_RESPONSE"
    rm "$TEMP_RESPONSE"
    exit 1
fi

# 提取JSON响应
JSON_RESPONSE=$(tail -n 1 "$TEMP_RESPONSE")
rm "$TEMP_RESPONSE"

# 获取压缩后的图片URL
COMPRESSED_URL=$(echo "$JSON_RESPONSE" | jq -r '.output.url')
if [ -z "$COMPRESSED_URL" ]; then
    echo "错误：无法获取压缩后的图片URL"
    exit 1
fi

# 下载压缩后的图片到临时文件
TEMP_FILE=$(mktemp)
echo "正在下载压缩后的图片..."
curl -o "$TEMP_FILE" "$COMPRESSED_URL"

# 检查下载是否成功
if [ ! -f "$TEMP_FILE" ]; then
    echo "错误：下载压缩后的图片失败"
    exit 1
fi

# 计算压缩后文件的MD5
FILE_MD5=$(md5 -q "$TEMP_FILE")
COMPRESSED_FILE="./pngpress/${DATE}${FILE_MD5}.${FILE_EXT}"

# 移动临时文件到最终位置
mv "$TEMP_FILE" "$COMPRESSED_FILE"

echo "图片压缩成功，文件保存在: $COMPRESSED_FILE"

# 上传到阿里云OSS
echo "正在上传到阿里云OSS..."
if ! aliyun oss cp "$COMPRESSED_FILE" "oss://$BUCKET/$PREFIX/$(basename "$COMPRESSED_FILE")"; then
    echo "错误：上传到阿里云OSS失败"
    exit 1
fi

# 生成CDN URL
CDN_URL="http://$CDN_DOMAIN/$PREFIX/$(basename "$COMPRESSED_FILE")"
echo "上传成功！CDN URL: $CDN_URL"

# 复制URL到剪贴板
echo "$CDN_URL" | pbcopy
echo "URL已复制到剪贴板" 