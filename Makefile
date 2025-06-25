.PHONY: help pull-all clean clone

# Default values
CLEAN ?= false

# Default target
help:
	@echo "Available commands:"
	@echo "  pull-all      - Pull all AUR repositories"
	@echo "  clean         - Clean up any temporary files"
	@echo "  clone PKG     - Clone AUR repository for package PKG"
	@echo "                  Optional: CLEAN=true to remove temp directories"
	@echo "                  Example: make clone PKG=python-micromamba CLEAN=true"
	@echo "  help          - Show this help message"

# Pull all AUR repositories
pull-all:
	@echo "Pulling all AUR repositories..."
	@./scripts/pull_all_repos.sh

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@rm -f pull_log.txt
	@echo "Removing all *.backup directories..."
	@find . -maxdepth 1 -type d -name "*.backup" -exec rm -rf {} + 2>/dev/null || true
	@echo "Removing all temp_clone directories..."
	@find . -type d -name "temp_clone" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleanup complete"

# Clone AUR repository for a specific package
clone:
	@if [ -z "$(PKG)" ]; then \
		echo "Error: Package name required. Usage: make clone PKG=<package-name>"; \
		echo "Example: make clone PKG=proton-pass-bin"; \
		echo "Optional: CLEAN=true to remove temp directories"; \
		exit 1; \
	fi
	@echo "Cloning AUR repository for $(PKG)..."
	@if [ -d "$(PKG)" ]; then \
		echo "Warning: Directory $(PKG) already exists. Backing up to $(PKG).backup"; \
		mv "$(PKG)" "$(PKG).backup"; \
	fi
	@mkdir -p "$(PKG)"
	@cd "$(PKG)" && git clone "https://aur.archlinux.org/$(PKG).git" temp_clone
	@echo "Copying files from cloned repository..."
	@shopt -s dotglob && cp -r "$(PKG)/temp_clone/"* "$(PKG)/"
	@if [ "$(CLEAN)" = "true" ]; then \
		echo "Removing temporary clone directory..."; \
		rm -rf "$(PKG)/temp_clone"; \
	else \
		echo "Keeping temporary clone directory at $(PKG)/temp_clone"; \
	fi
	@echo "Successfully cloned $(PKG) repository"

clone-all: clean
	@echo "Example: make clone-all CLEAN=true"
	@echo "Optional: CLEAN=true to remove temp directories"
	@echo "Cloning all AUR repositories..."
	@./scripts/clone_all_packages.sh $(CLEAN)