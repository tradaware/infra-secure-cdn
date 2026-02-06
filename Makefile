# Define container backend if not set (prefers podman over docker)
# Override by exporting CONTAINER_BACKEND_COMMAND in your ~/.profile
CONTAINER_BACKEND_COMMAND ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo)

image:
	$(CONTAINER_BACKEND_COMMAND) build . -t ghcr.io/tradaware/secure-cdn:local

run:
	$(CONTAINER_BACKEND_COMMAND) run --rm -it ghcr.io/tradaware/secure-cdn:local

release:
	python3 bin/release.py
