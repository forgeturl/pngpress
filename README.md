# PNG压缩上传工具

这是一个用于压缩PNG图片并上传到阿里云OSS的命令行工具。

## 功能特点

- 使用TinyPNG API压缩PNG图片
- 自动上传到阿里云OSS
- 自动复制CDN URL到剪贴板
- 自动安装所需依赖

## 使用前准备

1. 获取TinyPNG API Key
   - 访问 https://tinypng.com/developers
   - 注册并获取API Key

2. 配置阿里云OSS
   - 获取阿里云AccessKey ID和AccessKey Secret
   - 创建OSS Bucket
   - 配置CDN域名

3. 配置config.json
   - 复制config.json.example为config.json
   - 填入相应的配置信息

## 使用方法

1. 给脚本添加执行权限：
```bash
chmod +x presspng.sh
```

2. 运行脚本：
```bash
./presspng.sh your-image.png
```

## 注意事项

- 确保系统已安装Homebrew
- 首次运行时会自动安装必要的依赖
- 压缩后的图片会保存在./pngpress目录下
- 上传成功后的CDN URL会自动复制到剪贴板
