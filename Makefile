.PHONY: help pull-all clean clone

# Default target
help:
	@echo "Available commands:"
	@echo "  pull-all      - Pull all AUR repositories"
	@echo "  clean         - Clean up any temporary files"
	@echo "  clone PKG     - Clone AUR repository for package PKG"
	@echo "  help          - Show this help message"

# Pull all AUR repositories
pull-all:
	@echo "Pulling all AUR repositories..."
	@./scripts/pull_all_repos.sh

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@rm -f pull_log.txt
	@echo "Cleanup complete"

# Clone AUR repository for a specific package
clone:
	@if [ -z "$(PKG)" ]; then \
		echo "Error: Package name required. Usage: make clone PKG=<package-name>"; \
		echo "Example: make clone PKG=proton-pass-bin"; \
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
	@rm -rf "$(PKG)/temp_clone"
	@echo "Successfully cloned $(PKG) repository"