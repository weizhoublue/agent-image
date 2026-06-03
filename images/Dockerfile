# 基于最新的 Ubuntu 24.04
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NPM_CONFIG_PREFIX=/usr/local

# 1. 运行时依赖（去掉 vim/htop/build-essential/*-dev 等开发/调试包以缩小镜像）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    gh \
    jq \
    libsecret-1-0 \
    sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. 非 root 运行 Claude 的用户（uid 1000；Ubuntu 基础镜像可能已占用 gid 1000）
RUN set -eux; \
    if getent passwd 1000 >/dev/null; then \
      u="$(getent passwd 1000 | cut -d: -f1)"; \
      usermod -l agent -d /home/agent -m "${u}"; \
    else \
      g="$(getent group 1000 | cut -d: -f1)"; \
      useradd --uid 1000 --gid "${g}" --create-home --home-dir /home/agent --shell /bin/bash agent; \
    fi; \
    mkdir -p /home/agent; \
    chown 1000:1000 /home/agent

# 3. Node.js LTS（nodesource）
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 4. Python 3 + uv（不装 pip；uv 装到 /usr/local，避免 /root/.local 占空间）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
    && rm -rf /root/.local

# 5. 预装 LSP（无 build-essential；原生模块均使用预编译包）
RUN npm install -g --omit=dev typescript typescript-language-server pyright \
    && npm cache clean --force

# 6. 启动脚本与 claude 包装器
COPY script /script
RUN chmod +x /script/*.sh /script/install/*.sh

ENV ANTHROPIC_BASE_URL="http://localhost:20128/v1"
ENV ANTHROPIC_AUTH_TOKEN=""
ENV ANTHROPIC_MODEL="free"
ENV ANTHROPIC_DEFAULT_HAIKU_MODEL="free"
ENV ANTHROPIC_DEFAULT_SONNET_MODEL="free"
ENV ANTHROPIC_DEFAULT_OPUS_MODEL="free"
ENV CLAUDE_CODE_SUBAGENT_MODEL="free"
ENV CLAUDE_CODE_EFFORT_LEVEL="high"

# 可选组件开关（默认仅安装 claude-code；用 docker run -e 覆盖）
ENV ENABLE_ALL=false
ENV ENABLE_AGENT_BROWSER=false
ENV ENABLE_MCP_EXA=false
ENV ENABLE_MCP_CONTEXT7=false
ENV ENABLE_MCP_GITHUB=false
ENV ENABLE_MCP_CODEGRAPH=false
ENV ENABLE_PLUGIN_SUPERPOWER=false
ENV ENABLE_RTK=false
ENV ENABLE_QUERY_SESSION=false
ENV STRICT_INSTALL=true
ENV CONTEXT7_API_KEY=
ENV GITHUB_API_KEY=

WORKDIR /workspace

ENTRYPOINT ["/script/entrypoint.sh"]
CMD ["sleep", "infinity"]
