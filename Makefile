# Define container backend if not set (prefers podman over docker)
# Override by exporting CONTAINER_BACKEND_COMMAND in your ~/.profile or ~/.bashrc
CONTAINER_BACKEND_COMMAND ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo)

# =============================================================================
# Help Target (Default)
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: help image run release

## Show this help message
help:
	@echo ""
	@echo "============================================================================="
	@echo "  ██╗███╗   ██╗███████╗██████╗  █████╗                                       "
	@echo "  ██║████╗  ██║██╔════╝██╔══██╗██╔══██╗                                      "
	@echo "  ██║██╔██╗ ██║█████╗  ██████╔╝███████║                                      "
	@echo "  ██║██║╚██╗██║██╔══╝  ██╔══██╗██╔══██║                                      "
	@echo "  ██║██║ ╚████║██║     ██║  ██║██║  ██║                                      "
	@echo "  ╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝                                      "
	@echo "        ███████╗███████╗ ██████╗██╗   ██╗██████╗ ███████╗                    "
	@echo "        ██╔════╝██╔════╝██╔════╝██║   ██║██╔══██╗██╔════╝                    "
	@echo "        ███████╗█████╗  ██║     ██║   ██║██████╔╝█████╗                      "
	@echo "        ╚════██║██╔══╝  ██║     ██║   ██║██╔══██╗██╔══╝                      "
	@echo "        ███████║███████╗╚██████╗╚██████╔╝██║  ██║███████╗                    "
	@echo "        ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝                    "
	@echo "       ██████╗██████╗ ███╗   ██╗                                            "
	@echo "      ██╔════╝██╔══██╗████╗  ██║                                            "
	@echo "      ██║     ██████╔╝██╔██╗ ██║                                            "
	@echo "      ██║     ██╔══██╗██║╚██╗██║                                            "
	@echo "      ╚██████╗██║  ██║██║ ╚████║                                            "
	@echo "       ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝                                            "
	@echo "============================================================================="
	@echo ""
	@echo "$(shell tput bold)Secure CDN Container:$(shell tput sgr0)"
	@echo "  $(shell tput setaf 2)image$(shell tput sgr0)           Build secure CDN container image"
	@echo "  $(shell tput setaf 2)run$(shell tput sgr0)             Run CDN container interactively"
	@echo "  $(shell tput setaf 2)release$(shell tput sgr0)         Build and release image to registry"
	@echo ""

# =============================================================================
# Container Commands
# =============================================================================

image: ## Build secure CDN container image
	$(CONTAINER_BACKEND_COMMAND) build . -t ghcr.io/tradaware/secure-cdn:local

run: ## Run CDN container interactively
	$(CONTAINER_BACKEND_COMMAND) run --rm -it ghcr.io/tradaware/secure-cdn:local

# =============================================================================
# Release
# =============================================================================

release: ## Build and release image to registry
	python3 bin/release.py
