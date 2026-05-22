# 开发文档

本文面向维护本镜像的开发者：仓库结构、本地构建、冒烟测试、CI 发布，以及 **root 安装 + 非 root 运行 Claude** 的实现方式。

## 仓库结构

```
agent-image/
├── images/
│   ├── Dockerfile              # 基础镜像、agent 用户、gosu、默认 ENV
│   └── script/
│       ├── entrypoint.sh       # 启动入口
│       ├── claude-wrapper.sh   # claude → gosu agent → claude.real
│       ├── query-session-wrapper.sh  # query-session → gosu agent → query-session.real
│       ├── install-helpers.sh  # 日志、is_enabled、agent_run、chown
│       ├── run-optional-installs.sh
│       └── install/
│           ├── install-claude-code.sh   # 必需
│           ├── install-agent-browser.sh
│           ├── install-mcp-*.sh
│           ├── install-plugin-superpowers.sh
│           ├── install-rtk.sh
│           ├── CLAUDE.md              # 卷内无文件时的默认模板
│           └── settings.json
├── Makefile                    # build / run / smoke / buildx-push
├── scripts/ci-smoke.sh         # CI 与 make smoke 共用
├── .github/workflows/          # PR 与 tag 发布
└── docs/
    ├── usage.md
    └── development.md          # 本文
```

## 本地构建

镜像名由 Git remote 推导（`owner/repo`，与仓库名一致）：

```bash
make build              # 单架构，匹配当前机器
make -s print-image     # 本地 tag
make -s print-ghcr-image # ghcr.io/owner/repo（小写）
```

等价手动命令：

```bash
cd images && docker build -t "$(git remote get-url origin | sed ...):latest" .
```

### 多架构构建并推送（与 CI release 一致）

```bash
make buildx-push
# 或
docker buildx build --platform linux/amd64,linux/arm64 \
  -f images/Dockerfile -t ghcr.io/<owner>/<repo>:latest --push images
```

需要已 `docker login ghcr.io`。

## 本地冒烟

```bash
make smoke
```

内部执行 `scripts/ci-smoke.sh`：以 `ENABLE_ALL=true` 启动容器、跑完 entrypoint 后 `CMD=true` 退出，并检查日志中是否出现 `Environment ready`、是否因 `STRICT_INSTALL` 中止。

可调超时：

```bash
SMOKE_TIMEOUT=900 ./scripts/ci-smoke.sh "$(make -s print-image):latest"
```

指定平台（与 release workflow 一致）：

```bash
SMOKE_PLATFORM=linux/arm64 ./scripts/ci-smoke.sh <image:tag>
```

## CI

| Workflow | 触发 | 行为 |
|----------|------|------|
| [.github/workflows/pr.yml](../.github/workflows/pr.yml) | PR → `main` | buildx 构建 `amd64+arm64`（不 push）+ 加载 `amd64` 镜像冒烟 |
| [.github/workflows/release.yml](../.github/workflows/release.yml) | tag `v*` | push 多架构 manifest 到 GHCR + `amd64`/`arm64` 各跑一次冒烟 |

镜像路径：`ghcr.io/<github.repository>:<tag>`，同时打 `latest`。

## 非 root 运行 Claude：问题与方案

### 背景

Claude Code 不允许 **root** 使用 `--allow-dangerously-skip-permissions` 等危险权限模式。  
同时 entrypoint 需要 **root** 才能：

- 全局 `npm install -g`
- 对挂载卷 `chown`（修正宿主机 uid 与容器 agent 不一致）
- 安装系统级依赖（如 rtk 安装脚本）

因此采用 **「安装用 root，运行用 agent」** 的双用户模型，而不是把整个容器 `USER` 设为 agent。

### 当前方案：`gosu` + `claude` 包装器

```
entrypoint (root)
  ├─ npm install -g @anthropic-ai/claude-code  → /usr/local/bin/claude.real
  ├─ cp claude-wrapper.sh → /usr/local/bin/claude
  ├─ chown 挂载卷
  └─ gosu 1000: claude mcp / plugin / npx skills  (install-helpers: agent_run / claude_agent)

用户/CI: docker exec … claude …
  └─ claude-wrapper.sh
       └─ exec gosu 1000 env HOME=/home/agent USER=agent claude.real "$@"
```

关键文件：

- [`images/script/claude-wrapper.sh`](../images/script/claude-wrapper.sh) — 对外暴露的 `claude` 命令
- [`images/script/install-helpers.sh`](../images/script/install-helpers.sh) — `agent_run`、`claude_agent`

**Dockerfile 故意不设置 `USER agent`**，否则 entrypoint 无法 chown / 全局 npm。

### 未采用的方案：`setpriv`

`require` 中曾提到用 `setpriv --reuid=1000` 在 root shell 里降权。当前 **未实现**，原因：

- 容器内用固定 uid/gid 1000 的 `agent` 用户更简单，与卷权限一致
- `gosu` 在 Docker 生态中成熟、行为明确
- `setpriv` 与 capabilities 组合在部分环境更难排查

若未来 Claude 策略或 Kubernetes securityContext 有变，可再评估；设计规格见 [非目标说明](superpowers/specs/2026-05-22-agent-claude-image-design.md#2-非目标)。

### 开发时注意

1. **组件安装脚本**里凡涉及 `claude mcp`、`claude plugin`、`npx skills` 的，应通过 `claude_agent` 或 `agent_run` 以 uid 1000 执行（见各 `install/*.sh`）。
2. **组件脚本用 `return` 不用 `exit`**：它们被 `source`，`exit 1` 会直接终止 entrypoint。
3. **验证 MCP** 使用 `claude_agent mcp list 2>&1`（无 `-s user`；`mcp list` 不支持该参数）。
4. **验证 agent-browser** 不要对 agent 用 `gosu … command -v`（`command` 是 shell 内建）；改为检查 `/usr/local/bin/agent-browser` 可执行性并用 `agent_run agent-browser -h`。
5. **linux/arm64**：`install-agent-browser.sh` 在 `aarch64` 上整段跳过（`return 0`），不算安装失败。

### 调试非 root 行为

```bash
# 包装器是否生效（应显示 agent 侧版本）
docker exec agent-claude claude --version

# 对比 root 直调 real（可能受策略限制）
docker exec agent-claude claude.real --version

# 在容器内确认进程用户
docker exec agent-claude bash -c 'claude -p "echo ok" & sleep 1; ps aux | grep claude'
```

## 添加或修改可选组件

1. 新增 `images/script/install/install-<name>.sh`（`source install-helpers.sh`，失败 `return 1`）。
2. 在 `images/script/run-optional-installs.sh` 中按 `is_enabled ENABLE_<NAME>` 调用。
3. 在 `images/Dockerfile` 增加 `ENV ENABLE_<NAME>=false`（若需要默认关）。
4. 更新 [使用文档](usage.md) 环境变量表。
5. 运行 `make smoke` 或本地 `make run` + `docker logs` 验证。

`ENABLE_ALL=true` 时 `is_enabled` 对任意 `ENABLE_*` 均返回 true（见 `install-helpers.sh`）。

**query-session：** 从 GitHub Release 按架构下载（`linux-amd64` / `linux-arm64`，v0.5.0+），日志打印 `tag=` 与 `asset=`。详见 [设计 spec](superpowers/specs/2026-05-22-query-session-design.md)。

## entrypoint 流程

```
entrypoint.sh
  → log_install_config
  → source install-claude-code.sh   # 失败则 exit 1
  → source run-optional-installs.sh # 按 ENABLE_* 安装，累计 INSTALL_FAILURES
  → abort_if_install_failed         # STRICT_INSTALL 时可能 exit 1
  → exec "$@"                       # 默认 sleep infinity；冒烟时 CMD=true
```

## Makefile 目标

| 目标 | 说明 |
|------|------|
| `build` | 本地单架构 `docker build` |
| `buildx-push` | 双架构 push 到 GHCR |
| `run` | 停止旧容器并以当前 Makefile 中的 `-e` 启动（开发用，含 API Key 时请勿提交） |
| `smoke` | build + ci-smoke.sh |
| `clean` | 删除 `agent-claude` 容器 |

## 相关文档

- [使用文档](usage.md)
- [设计规格](superpowers/specs/2026-05-22-agent-claude-image-design.md)
- [需求](../require)
