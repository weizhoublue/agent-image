# agent-claude 镜像设计规格

**日期:** 2026-05-22  
**状态:** 已实现（2026-05-22）  
**需求来源:** 仓库根目录 `require`

## 1. 目标

构建并维护一个 Docker 镜像，在容器内提供可自动更新的 **Claude Code** 及完整插件生态（MCP、CLI、Skill、官方插件）。用户于宿主机预先配置目录后挂载进容器；每次容器启动时按配置强制同步到最新版本。镜像通过 GitHub Actions 在 tag/PR 时构建与冒烟验证，并发布到 GitHub Container Registry (GHCR)。

## 2. 非目标

- 不在镜像构建阶段安装需 API Key 才可完整验证的 MCP（仅在运行时按环境变量安装）。
- 不实现 `setpriv` / capabilities 降权方案（首期使用 `gosu`；若后续 Claude 策略变化再评估）。
- 不使用 `install-env` 文件；组件开关仅通过 `docker run -e` / Dockerfile `ENV` 配置。

## 3. 架构概览

```
宿主机 ~/.claude-test/          docker run -e ENABLE_*=...
└── .claude/ (持久化)  ──mount──► /home/agent/.claude/

容器启动:
  entrypoint (root)
    → 读取容器环境变量 (Dockerfile ENV / docker run -e)
    → root: 全局 CLI 安装 (npm -g, rtk, ...)
    → chown -R agent:agent /home/agent
    → gosu agent:  claude mcp / plugin / skills (强制更新)
    → exec CMD (默认 sleep infinity)

用户执行 claude:
  /usr/local/bin/claude → gosu agent claude.real ...
```

### 3.1 身份模型

| 阶段 | Unix 用户 | 职责 |
|------|-----------|------|
| entrypoint 安装 | `root` | 全局 `npm install -g`、系统依赖、`chown` 挂载卷 |
| Claude 配置与运行 | `agent` (uid/gid 1000) | `claude mcp add`、`plugin install`、`npx skills`、日常 `claude` |
| 宿主机 docker 调用方 | 任意（含 root） | 仅影响能否调用 Docker；与容器内用户无关 |

**原则:** Claude 不允许 root 使用 `--allow-dangerously-skip-permissions`；所有 Claude 相关操作统一在 `agent` 下执行，避免 root 与非 root 配置分裂。

## 4. 镜像构建 (Dockerfile)

**基础:** `ubuntu:24.04`（保持现有 Node LTS、Python3+uv、LSP、基础 apt 包）。

**新增:**

- 创建用户 `agent`，固定 `UID=1000`、`GID=1000`，`HOME=/home/agent`。
- 安装 `gosu`（`apt install gosu` 或等价包）。
- 保持 `ENTRYPOINT ["/script/entrypoint.sh"]`，**不**设置 `USER agent`（entrypoint 需 root 权限）。
- `CMD ["sleep", "infinity"]`（长驻容器，便于 restart 触发重装）。
- 安装 `claude` 包装脚本至 `/usr/local/bin/claude`，实际二进制为 `claude.real`（由 entrypoint 中 `npm install -g @anthropic-ai/claude-code` 提供）。

## 5. 配置：环境变量

### 5.1 Dockerfile 默认值

```dockerfile
ENV ENABLE_ALL=false
ENV ENABLE_AGENT_BROWSER=false
ENV ENABLE_MCP_EXA=false
# ... 其余 ENABLE_* 均为 false
ENV STRICT_INSTALL=true
```

### 5.2 docker run 传入

```bash
docker run -d --name agent-claude \
  -e ENABLE_ALL=true \
  -e CONTEXT7_API_KEY="..." \
  -e GITHUB_API_KEY="..." \
  -v "${HOME}/.claude-test:/home/agent:rw" \
  ...
```

也可使用 `--env-file agent-claude.env`。

### 5.3 数据卷挂载（与开关无关）

```bash
-v "${HOME}/.claude-test:/home/agent:rw"
-v "${HOME}/.gitconfig:/home/agent/.gitconfig:ro"
-v "${HOME}/.config/gh:/home/agent/.config/gh:ro"
-v "${HOME}/.ssh:/home/agent/.ssh:ro"
```

### 5.4 环境变量开关

| 变量 | 优先级 | 行为 |
|------|--------|------|
| `ENABLE_ALL=true` | 最高 | 启用下列全部可选组件 |
| `ENABLE_AGENT_BROWSER=true` | | 见 §6.1 |
| `ENABLE_MCP_EXA=true` | | 见 §6.2 |
| `ENABLE_MCP_CONTEXT7=true` | 需 `CONTEXT7_API_KEY` | 见 §6.3 |
| `ENABLE_MCP_GITHUB=true` | 需 `GITHUB_API_KEY` | 见 §6.4 |
| `ENABLE_PLUGIN_SUPERPOWER=true` | | 见 §6.5 |
| `ENABLE_RTK=true` | | 见 §6.6 |
| `ENABLE_QUERY_SESSION=true` | | 见 [query-session 设计](2026-05-22-query-session-design.md) |

**缺省:** Dockerfile 默认全部 `ENABLE_*=false`，仅执行 `claude-code` 全局更新。

## 6. entrypoint 安装清单

所有 `claude` / `npx` 相关步骤在 `gosu agent` 下执行。每次启动对可变组件采用**强制更新**策略（先移除再添加，或等价幂等重装），以覆盖卷内旧版 plugin/skill。

### 6.1 agent-browser（ENABLE_AGENT_BROWSER / ENABLE_ALL）

```bash
npm install -g agent-browser@latest
agent-browser install
npx skills add vercel-labs/agent-browser --yes  # 非交互
```

### 6.2 Exa MCP（ENABLE_MCP_EXA / ENABLE_ALL）

```bash
claude mcp remove exa -s user 2>/dev/null || true
claude mcp add -s user --transport http exa https://mcp.exa.ai/mcp
```

### 6.3 Context7 MCP（ENABLE_MCP_CONTEXT7 / ENABLE_ALL）

仅当 `CONTEXT7_API_KEY` 非空:

```bash
claude mcp remove context7 -s user 2>/dev/null || true
claude mcp add -s user --transport http context7 https://mcp.context7.com/mcp \
  --header "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}" \
  --header "Accept: application/json, text/event-stream"
```

### 6.4 GitHub MCP（ENABLE_MCP_GITHUB / ENABLE_ALL）

仅当 `GITHUB_API_KEY` 非空:

```bash
claude mcp remove github -s user 2>/dev/null || true
claude mcp add -s user github "https://api.githubcopilot.com/mcp" \
  --transport http \
  --header "Authorization: Bearer ${GITHUB_API_KEY}" \
  --header "X-MCP-Toolsets: context,issues,repos,pull_requests"
```

### 6.5 Superpowers 插件（ENABLE_PLUGIN_SUPERPOWER / ENABLE_ALL）

```bash
# 以 Claude Code 当前 CLI 为准（require 示例为 plugin 子命令）
claude plugin install superpowers@claude-plugins-official
# 若旧版已存在，先 uninstall 再 install，保证幂等
```

### 6.6 RTK（ENABLE_RTK / ENABLE_ALL）

root 执行:

```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
gosu agent rtk init --global
```

### 6.7 Claude Code 本体（始终）

root 执行:

```bash
npm install -g @anthropic-ai/claude-code@latest --no-audit --no-fund
```

### 6.8 卷权限

root 在 agent 阶段之前:

```bash
chown -R agent:agent /home/agent
```

## 7. Claude 命令包装

路径 `/usr/local/bin/claude`:

```bash
#!/bin/bash
exec gosu agent "$(command -v claude.real || echo claude)" "$@"
```

`claude.real` 为 npm 全局安装的真实二进制（可在 entrypoint 中用 symlink 固定路径）。文档与示例统一使用 `claude` 命令。

## 8. 构建 (Makefile)

从 git remote 解析仓库名:

```makefile
REPO_FULL_NAME := $(shell git remote get-url origin 2>/dev/null | sed -E \
  -e 's#^git@github.com:##' \
  -e 's#^https://github.com/##' \
  -e 's#^ssh://git@github.com/##' \
  -e 's#\.git$$##')
IMAGE := $(REPO_FULL_NAME)

build:
	cd images && docker build -t $(IMAGE):latest .

# 可选: run, smoke 本地目标
```

镜像构建上下文: `images/`（含 `Dockerfile`、`script/`）。

## 9. GitHub Actions

### 9.1 Release（push tag）

触发: `push` tags `v*`

步骤:

1. Checkout 对应 tag
2. `docker buildx build --platform linux/amd64,linux/arm64 --push` → `ghcr.io/<owner>/<repo>:<tag>`（manifest list，同 tag 多架构；镜像名与仓库名一致）
3. 冒烟: 分别 `docker pull --platform linux/amd64|arm64` 后运行 `scripts/ci-smoke.sh`（`SMOKE_PLATFORM`）
4. 同时推送 `:latest`

权限: `packages: write`；需 `setup-qemu-action` + `setup-buildx-action`。

### 9.2 PR 检查

触发: PR 至默认分支

步骤: buildx 构建 `linux/amd64,linux/arm64`（`push: false` 校验双架构 Dockerfile）→ 单独 `load` amd64 镜像冒烟；**不** push PR 镜像。

### 9.3 CI 密钥

- 冒烟使用 `ENABLE_ALL=true`；不需真实 `CONTEXT7_API_KEY` / `GITHUB_API_KEY` 的步骤应跳过或 mock（无 key 时不安装对应 MCP，不视为失败）。
- 需要网络的步骤失败时，job 失败并输出 entrypoint 日志尾部。

## 10. 本地运行示例

```bash
make build

mkdir -p "${HOME}/.claude-test"

docker run -d --name agent-claude \
  --network host \
  -e ENABLE_AGENT_BROWSER=true \
  -e ENABLE_MCP_EXA=true \
  -v "${HOME}/.claude-test:/home/agent:rw" \
  -v "${HOME}/.gitconfig:/home/agent/.gitconfig:ro" \
  -v "${HOME}/.config/gh:/home/agent/.config/gh:ro" \
  -v "${HOME}/.ssh:/home/agent/.ssh:ro" \
  "$(make -s print-image 2>/dev/null || echo agent-image):latest"
```

## 11. 测试与验收标准

| 场景 | 验收 |
|------|------|
| `docker run -e ENABLE_ALL=true` | 容器启动后日志含各组件成功标记；`gosu agent claude --version` 成功 |
| 默认无 `ENABLE_*` | 仅 claude-code 更新成功，无 MCP 安装错误 |
| 重启同一卷 | 组件版本可更新，无权限拒绝写 `/home/agent` |
| PR CI | build + smoke 绿 |
| Tag CI | build + smoke + push GHCR 绿 |

## 12. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 卷 uid 与容器 agent 不一致 | entrypoint `chown -R agent:agent /home/agent` |
| npm/MCP 网络失败 | entrypoint 分步日志；CI 重试一次 |
| plugin 持久化导致旧版残留 | 强制 remove + reinstall |
| root 误跑 claude | 仅通过 `gosu` 包装命令暴露 |

## 13. 与 require 原文差异

| require | 本设计 |
|---------|--------|
| `install-env` 文件 | `docker run -e` / Dockerfile `ENV` |
| `-v ~/.claude-test:/root` | `-v ~/.claude-test:/home/agent` |
| `setpriv` 降权 | `gosu agent`（首期） |

## 14. 实现顺序（供 writing-plans 使用）

1. Dockerfile: `agent` 用户 + `gosu` + wrapper 脚本骨架
2. `entrypoint.sh`: 读取 ENV、分阶段安装、chown
3. `Makefile`: build / 辅助 target
4. `.github/workflows`: pr.yml、release.yml
5. README: 更新运行说明，与 require 对齐
