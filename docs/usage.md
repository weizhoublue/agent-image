# 使用文档

本文说明如何拉取/启动镜像、配置可选组件、进入容器并以非 root 运行 Claude Code。

## 获取镜像

### 本地构建

```bash
make build
make -s print-image   # 查看本地镜像名，形如 owner/repo（与 Git 仓库名一致）
```

### 从 GHCR 拉取

同一 tag 对应多架构 manifest，Docker 会按宿主机自动选择 `linux/amd64` 或 `linux/arm64`：

```bash
docker pull ghcr.io/weizhoublue/agent-image:latest
```

## 启动容器

### 最大安装启动


```bash

# Claude 配置、MCP、插件、Skill 等映射到宿主机目录 持久化
PROFILE_DIR="${HOME}/.claude-test"

mkdir -p "${PROFILE_DIR}
docker stop agent-claude 2>/dev/null || true
docker rm -f agent-claude 2>/dev/null || true
# 每次重建容器，就可以升级所有组件到最新版本
docker run -d --name agent-claude \
  --network host \
  -v "${PROFILE_DIR}:/home/agent:rw" \
  -v "${HOME}/.gitconfig:/home/agent/.gitconfig:ro" \
  -v "${HOME}/.config/gh:/home/agent/.config/gh:ro" \
  -v "${HOME}/.ssh:/home/agent/.ssh:ro" \
	-e ENABLE_ALL=true \
  -e ANTHROPIC_BASE_URL="http://100.117.111.4:20128/v1" \
  ghcr.io/weizhoublue/agent-image:latest

# 每次创建容器时，会新安装 claude ，并且 ENABLE_ALL 会安装所有的配套工具
docker logs -f agent-claude

# 定制文件
  vi  ${HOME}/.claude-test/.claude/CLAUDE.md

# 交互会话
docker exec -it agent-claude claude

# 一次性调用
docker exec -it agent-claude claude -p '今天上海气温'

# 封装调用
docker exec -it \
  -e ANTHROPIC_BASE_URL="http://100.117.111.4:20128/v1" \
  -e ANTHROPIC_AUTH_TOKEN="changeme" \
  -e ANTHROPIC_MODEL="free" \
  -e ANTHROPIC_DEFAULT_HAIKU_MODEL="free" \
  -e ANTHROPIC_DEFAULT_SONNET_MODEL="free" \
  -e ANTHROPIC_DEFAULT_OPUS_MODEL="free" \
  -e CLAUDE_CODE_SUBAGENT_MODEL="free" \
  -e CLAUDE_CODE_EFFORT_LEVEL="high" \
  agent-claude \
  claude -p '今天上海气温'

```

## Claude 命令

容器内的 claude 命令
- 真正的 claude 命令在 /usr/local/bin/claude.real
- `/usr/local/bin/claude` 是包装脚本，调用它，已经解决了以非 root 用户来使用 claude 的 --allow-dangerously-skip-permissions 问题
  `/usr/local/bin/claude` 内部用 `gosu` 以 uid **1000**（`agent`）执行 `claude.real`，`HOME=/home/agent`。  

## query-session 命令

启用 `ENABLE_QUERY_SESSION=true` 后：

- 真实二进制：`/usr/local/bin/query-session.real`
- `/usr/local/bin/query-session` 为包装脚本，与 `claude` 相同，用 `gosu` 以 **agent**（uid 1000）、`HOME=/home/agent` 执行

因此 **root 直接运行 `query-session` 也会读 `/home/agent/.claude`**，不会误用 `/root/.claude`。请挂载 agent 家目录（如 `-v "$HOME/.claude-test:/home/agent"`），否则会话数据为空。


## 环境变量

| 变量 | Dockerfile 默认 | 说明 |
|------|-----------------|------|
| `ENABLE_ALL` | `true` | `true` 时启用全部可选组件 |
| `ENABLE_AGENT_BROWSER` | `false` | agent-browser CLI + skill |
| `ENABLE_MCP_EXA` | `false` | Exa MCP |
| `ENABLE_MCP_CONTEXT7` | `false` | Context7 MCP（需 `CONTEXT7_API_KEY`） |
| `ENABLE_MCP_GITHUB` | `false` | GitHub MCP（需 `GITHUB_API_KEY`） |
| `ENABLE_MCP_CODEGRAPH` | `false` | CodeGraph MCP |
| `ENABLE_PLUGIN_SUPERPOWER` | `false` | superpowers 插件 |
| `ENABLE_RTK` | `false` | rtk CLI |
| `ENABLE_QUERY_SESSION` | `false` | [query-session](https://github.com/weizhoublue/query-session) CLI（查 Claude/Codex/Cursor 会话） |
| `CONTEXT7_API_KEY` | （未设置） | Context7 密钥 |
| `GITHUB_API_KEY` | （未设置） | GitHub MCP 密钥 |
| `STRICT_INSTALL` | `true` | 已启用组件失败时是否阻止容器继续启动 |

`ENABLE_ALL=true` 时等价打开上述全部 `ENABLE_*`（缺 API Key 的 MCP 安装脚本仍会按逻辑处理）。

ENV ANTHROPIC_BASE_URL="http://localhost:20128/v1"
ENV ANTHROPIC_AUTH_TOKEN="changeme"
ENV ANTHROPIC_MODEL="free"
ENV ANTHROPIC_DEFAULT_HAIKU_MODEL="free"
ENV ANTHROPIC_DEFAULT_SONNET_MODEL="free"
ENV ANTHROPIC_DEFAULT_OPUS_MODEL="free"
ENV CLAUDE_CODE_SUBAGENT_MODEL="free"
ENV CLAUDE_CODE_EFFORT_LEVEL="high"


## 推荐挂载

| 宿主机路径 | 容器路径 | 说明 |
|------------|----------|------|
| `~/.claude-test`（自定） | `/home/agent` | Claude 配置与状态持久化 |
| `~/.gitconfig` | `/home/agent/.gitconfig` | Git 身份（只读） |
| `~/.config/gh` | `/home/agent/.config/gh` | `gh` CLI（只读） |
| `~/.ssh` | `/home/agent/.ssh` | SSH 密钥（只读） |

首次启动时，若卷内没有 `CLAUDE.md` / `settings.json`，entrypoint 会从镜像内默认模板复制到 `/home/agent/.claude/`。


## agent-browser 在 macos 上不安装

- **linux/arm64 容器**：即使 `ENABLE_AGENT_BROWSER=true`，也会**静默跳过**整组件（无 Chrome for Testing），不报错、不计入失败。
- **linux/amd64 容器**：按配置正常安装。
- **macOS 宿主机**：请在本机使用 agent-browser；不要指望 ARM Linux 容器内的浏览器包。
