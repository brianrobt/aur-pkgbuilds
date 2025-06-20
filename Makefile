.PHONY: help pull-all publish-setup clean

# Default target
help:
	@echo "Available commands:"
	@echo "  pull-all      - Pull all AUR repositories"
	@echo "  publish-setup - Set up temporary directory for publishing changes"
	@echo "  clean         - Clean up any temporary files"
	@echo "  help          - Show this help message"

# Pull all AUR repositories
pull-all:
	@echo "Pulling all AUR repositories..."
	@./scripts/pull_all_repos.sh

# Set up temporary directory for publishing changes
publish-setup:
	@echo "Setting up temporary directory for publishing..."
	@./scripts/publish_workflow.sh

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@rm -f pull_log.txt
	@rm -rf build/
	@echo "Cleanup complete"