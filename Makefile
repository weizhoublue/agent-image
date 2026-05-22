.PHONY: build buildx buildx-push print-image run smoke clean

# Multi-arch manifest (CI 同款); 本地 push 需已 docker login ghcr.io
PLATFORMS ?= linux/amd64,linux/arm64

REPO_FULL_NAME := $(shell git remote get-url origin 2>/dev/null | sed -E \
	-e 's|^git@github.com:||' \
	-e 's|^https://github.com/||' \
	-e 's|^ssh://git@github.com/||' \
	-e 's|\.git$$||')

# Local tag: owner/repo；GHCR: ghcr.io/owner/repo（与仓库名一致，无额外路径段）
IMAGE_LOCAL := $(REPO_FULL_NAME)
GHCR_IMAGE := ghcr.io/$(shell echo '$(REPO_FULL_NAME)' | tr '[:upper:]' '[:lower:]')


# 本地单架构（当前机器架构，Mac ARM → arm64，Linux x86 → amd64）
build:
	cd images && docker build -t $(IMAGE_LOCAL):latest -t $(GHCR_IMAGE):latest .

# 构建 amd64+arm64 并推送同一 tag（manifest list，docker pull 自动选架构）
buildx-push:
	docker buildx build \
		--platform $(PLATFORMS) \
		-f images/Dockerfile \
		-t $(GHCR_IMAGE):latest \
		--push \
		images

print-image:
	@echo $(IMAGE_LOCAL)

print-ghcr-image:
	@echo $(GHCR_IMAGE)

# 示例：通过 -e 传入组件开关；API Key 用 -e CONTEXT7_API_KEY=... -e GITHUB_API_KEY=...
run:
	docker stop agent-claude 2>/dev/null || true
	docker rm -f agent-claude 2>/dev/null || true
	docker run -d --name agent-claude \
		--network host \
		-v $${HOME}/.claude-test:/home/agent:rw \
		-v $${HOME}/.gitconfig:/home/agent/.gitconfig:ro \
		-v $${HOME}/.config/gh:/home/agent/.config/gh:ro \
		-v $${HOME}/.ssh:/home/agent/.ssh:ro \
		-v $${HOME}/Documents/git:/home/agent/Documents/git:rw \
		-v $${HOME}/Documents/forkgit:/home/agent/Documents/forkgit:rw \
		-e ENABLE_ALL=true \
		-e ENABLE_AGENT_BROWSER=false \
		-e ENABLE_MCP_EXA=false \
		-e ENABLE_MCP_CONTEXT7=false \
		-e CONTEXT7_API_KEY=changeme \
		-e ENABLE_MCP_GITHUB=false \
		-e GITHUB_API_KEY=changeme \
		-e ENABLE_PLUGIN_SUPERPOWER=false \
		-e ENABLE_RTK=false \
		-e STRICT_INSTALL=true \
		$(IMAGE_LOCAL):latest

smoke: build
	./scripts/ci-smoke.sh $(IMAGE_LOCAL):latest

clean:
	-docker rm -f agent-claude 2>/dev/null
