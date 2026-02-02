# llm-switch 离线安装指南

本指南适用于无法访问 GitHub 的环境，帮助你在离线场景下部署 `llm-switch`。

## 前置要求

- Bash 或 Zsh（系统默认即可）
- 基础 UNIX 工具（tar、cp、mkdir 等）
- 能够执行 `install.sh`

## 安装步骤

### 1. 打包 llm-switch 目录

在可以访问仓库的机器上，进入项目目录并打包：

```sh
cd llm-switch
tar -czf llm-switch.tar.gz \
  llm-switch.zsh \
  llm-switch.bash \
  install.sh \
  README.md
```

### 2. 传输到目标机器

将压缩包上传到需要安装的服务器（示例使用 `scp`）：

```sh
scp llm-switch.tar.gz user@server:/tmp/
```

### 3. 解压并执行安装

```sh
ssh user@server
cd /tmp
tar -xzf llm-switch.tar.gz
cd llm-switch
./install.sh
```

### 4. 重新加载 Shell 配置并验证

```sh
# Zsh
source ~/.zshrc

# 或 Bash
source ~/.bashrc

llm-switch list
```

## 环境配置
每个环境文件（.env）包含：
```sh
export LLM_PROVIDER=""
export LLM_API_KEY=""
export LLM_BASE_URL=""
export LLM_MODEL_NAME=""
```

### Vision 视觉能力支持
`visionuse` 主要用于配合 [llm-inline](https://github.com/iblueer/llm-inline) 的 `genimage` 技能，为图像生成设置独立的 Vision 模型环境变量。

支持的环境变量：
- `LLM_VISION_MODEL_NAME` (或 `LLM_VISION_MODEL`)
- `LLM_VISION_API_KEY`
- `LLM_VISION_BASE_URL`

用法示例：
```sh
llm-switch use doubao       # 切换主 LLM（用于文本）
llm-switch visionuse gpt4o  # 切换 Vision 模型（用于图像生成）
llmi genimage "一只猫"       # 使用 Vision 模型生成图像
```
`visionuse` 会自动从指定的配置文件中提取对应的 API Key 和 URL，使主 LLM 和视觉模型可以独立配置、同时生效。

## 常用指令
- `llm-switch list`: 列出所有环境
- `llm-switch use <name>`: 切换到指定环境
- `llm-switch visionuse <name>`: 设置 Vision 变量
- `llm-switch show`: 显示当前生效变量
- `llm-switch new <name>`: 创建新环境

## 调试

若需要查看详细安装过程，可启用调试：

```sh
LLM_SWITCH_DEBUG=1 ./install.sh
```

## 卸载

```sh
rm -rf ~/.llm-switch

# 并从 ~/.zshrc 或 ~/.bashrc 中删除以下标记之间的内容：
# >>> iblueer/zsh-claude-tools/llm-switch BEGIN (managed) >>>
# ...
# <<< iblueer/zsh-claude-tools/llm-switch END   <<<
```
