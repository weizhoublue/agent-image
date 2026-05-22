# agent-image

用于运行 **Claude Code** 及插件生态（MCP、CLI、Skill）的 Docker 镜像。Claude 配置与状态通过挂载目录持久化；组件开关通过 **`docker run -e`** 传入（不使用 `install-env` 文件）。

## 文档

| 文档 | 说明 |
|------|------|
| [**使用文档**](docs/usage.md) | 启动容器、环境变量、挂载、以非 root 运行 `claude` |
| [**开发文档**](docs/development.md) | 本地构建、冒烟、CI、root/非 root 实现与扩展组件 |
| [设计规格](docs/superpowers/specs/2026-05-22-agent-claude-image-design.md) | 架构与设计决策 |
| [需求](require) | 原始需求说明 |

## 快速开始

```bash
make build
make run          # 或见 docs/usage.md 中的 docker run 示例
docker exec -it agent-claude claude --version
```

从 GHCR 拉取：`docker pull ghcr.io/<owner>/<repo>:latest`（同一 tag，多架构 manifest；镜像名与仓库名一致）。

详细步骤、环境变量表与平台说明见 **[docs/usage.md](docs/usage.md)**。
