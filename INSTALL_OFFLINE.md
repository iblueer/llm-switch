# llm-switch 离线安装指南

本指南适用于无法访问 GitHub 的环境，帮助你在离线场景下部署 `llm-switch`。

## 前置要求

- Bash 或 Zsh（系统默认即可）
- 基础 UNIX 工具（tar、cp、mkdir 等）
- 能够执行 `install-locally.sh`

## 安装步骤

### 1. 打包 llm-switch 目录

在可以访问仓库的机器上，进入项目的 `llm-switch` 子目录并打包：

```sh
cd zsh-claude-tools/llm-switch
tar -czf llm-switch.tar.gz \
  llm-switch.zsh \
  llm-switch.bash \
  install-locally.sh \
  INSTALL_OFFLINE.md
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
./install-locally.sh
```

### 4. 重新加载 Shell 配置并验证

```sh
# Zsh
source ~/.zshrc

# 或 Bash
source ~/.bashrc

llm-switch list
```

## 默认环境文件

安装脚本会在 `~/.llm-switch/envs/default.env` 生成默认模板：

```sh
export LLM_PROVIDER=""
export LLM_API_KEY=""
export LLM_BASE_URL=""
export LLM_MODEL_NAME=""
```

根据实际需求填写后，可通过 `llm-switch default` 快速生效。

## 调试

若需要查看详细安装过程，可启用调试：

```sh
LLM_SWITCH_DEBUG=1 ./install-locally.sh
```

## 卸载

```sh
rm -rf ~/.llm-switch

# 并从 ~/.zshrc 或 ~/.bashrc 中删除以下标记之间的内容：
# >>> iblueer/zsh-claude-tools/llm-switch BEGIN (managed) >>>
# ...
# <<< iblueer/zsh-claude-tools/llm-switch END   <<<
```
