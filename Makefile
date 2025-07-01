.PHONY: help pull-all clean clone aur-build update-aur-repos init-submodules

# Default values
CLEAN ?= false

# Build and run AUR package in Docker
aur-build:
	@if [ -z "$(PKG)" ]; then \
		echo "Error: Package name required. Usage: make aur-build PKG=<package-name>"; \
		echo "Example: make aur-build PKG=proton-pass-bin"; \
		exit 1; \
	fi
	@./scripts/aur-build.sh "$(PKG)"

# Clean up temporary files
clean:
	@./scripts/clean.sh

# Update submodule and copy files for a specific package
clone:
	@if [ -z "$(PKG)" ]; then \
		echo "Error: Package name required. Usage: make clone PKG=<package-name>"; \
		echo "Example: make clone PKG=proton-pass-bin"; \
		echo "Optional: CLEAN=true to remove temp directories"; \
		exit 1; \
	fi
	@if [ "$(CLEAN)" = "true" ]; then \
		./scripts/clone.sh "$(PKG)" clean; \
	else \
		./scripts/clone.sh "$(PKG)"; \
	fi

clone-all: clean
	@echo "Example: make clone-all CLEAN=true"
	@echo "Optional: CLEAN=true to remove temp directories"
	@echo "Updating all AUR submodules..."
	@./scripts/clone_all_packages.sh $(CLEAN)

init-submodules:
	git submodule update --init --recursive

# Default target
help:
	@echo "Available commands:"
	@echo "  pull-all      - Pull all AUR repositories"
	@echo "  clean         - Clean up any temporary files"
	@echo "  clone PKG     - Update submodule and copy files for package PKG"
	@echo "                  Optional: CLEAN=true to remove temp directories"
	@echo "                  Example: make clone PKG=python-micromamba CLEAN=true"
	@echo "  aur-build PKG - Update submodule, copy files, build Docker image, and run container"
	@echo "                  Example: make aur-build PKG=python-micromamba"
	@echo "  init-submodules - Initialize and update all Git submodules"
	@echo "  update-aur-repos - Update all AUR submodules to latest versions"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Scripts can also be called directly:"
	@echo "  ./scripts/aur-build.sh <package>"
	@echo "  ./scripts/clone.sh <package> [clean]"
	@echo "  ./scripts/clean.sh"

# Pull all AUR repositories
pull-all:
	@echo "Pulling all AUR repositories..."
	@./scripts/pull_all_repos.sh

update-aur-repos:
	git submodule update --remote