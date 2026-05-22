# query-session 可选组件设计

**日期:** 2026-05-22  
**状态:** 已批准  
**上游:** https://github.com/weizhoublue/query-session

## 目标

在 agent-image 容器启动时，按 `ENABLE_QUERY_SESSION`（或 `ENABLE_ALL`）从 GitHub Release 安装 `query-session` CLI，供 **agent** 用户查询本机 Claude / Codex / Cursor 会话；安装日志打印 **release tag** 与资产名。

## 配置

| 变量 | Dockerfile 默认 | 说明 |
|------|-----------------|------|
| `ENABLE_QUERY_SESSION` | `false` | 安装 query-session |
| `ENABLE_ALL` | `false` | `true` 时包含本组件 |

无额外 API Key 环境变量（CLI 只读 `$HOME` 下 `.claude` / `.codex` / `.cursor`）。

## 架构映射（容器内 Linux）

| `uname -m` | Release 资产 | 安装路径 |
|------------|--------------|----------|
| `x86_64` | `query-session-linux-amd64` | `/usr/local/bin/query-session` |
| `aarch64` | `query-session-linux-arm64` | `query-session.real` + wrapper `query-session` |

**v0.5.0+** 提供 `query-session-linux-arm64`，Mac ARM 上默认的 linux/arm64 容器可安装运行。  
`query-session-macos-arm64` 仅用于 macOS 宿主机，不在容器内使用。

## Wrapper（与 claude 一致）

- `/usr/local/bin/query-session.real` — 自 GitHub 下载的二进制
- `/usr/local/bin/query-session` — `query-session-wrapper.sh`，`gosu 1000 env HOME=/home/agent USER=agent` 执行 `.real`

root 在容器内直接敲 `query-session` 也会以 agent 身份读 `/home/agent/.claude`，不会访问 `/root/.claude`。

## 安装流程（`install-query-session.sh`）

1. root 调用 GitHub API `GET /repos/weizhoublue/query-session/releases/latest` 取 `tag_name`（如 `v0.5.0`）。
2. 按架构选择资产，`curl -fsSL` 下载到 `/tmp/query-session.bin`。
3. `install -m 755` → `/usr/local/bin/query-session.real`，再 `cp query-session-wrapper.sh` → `/usr/local/bin/query-session`。
4. 日志：`query-session installed tag=<tag> asset=<asset> real=... wrapper=...`。
5. 以 wrapper 空参 smoke（需 `${AGENT_HOME}/.claude/projects` 存在）。
6. 失败：`log_fail` + `return 1`（计入 `INSTALL_FAILURES`）。

不使用 `releases/latest/download/...` 直链，以便 tag 与下载 URL 一致、日志可核对版本。

## 运行

- 挂载宿主机 agent 家目录到 `/home/agent` 后，root 或 agent 均可直接 `query-session -t claude|codex|cursor`（经 wrapper 统一 `HOME=/home/agent`）。

## CI

- `ENABLE_ALL=true` 冒烟：amd64 / arm64 镜像均应安装成功并出现 tag 日志。
- 未知 `uname -m`：`log_fail` 并计入失败。

## 文档

- `docs/usage.md` 环境变量表增加 `ENABLE_QUERY_SESSION`。
- `docs/development.md` 扩展组件说明。

## 非目标

- 不在镜像构建期预置二进制。
- 不安装 macOS 资产到 Linux 容器。
- 不增加 `QUERY_SESSION_VERSION` 等版本 pin（仅用 latest release）。
