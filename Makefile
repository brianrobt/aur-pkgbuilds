# AUR PKGBUILD helpers
#
#   make help
#   make list
#   make import PKG=netclient
#   make update PKG=jay-aur VER=7.5.5
#   make refresh PKG=jay-aur
#   make push PKG=gvm2-git DRY_RUN=1
#   make push-all
#   make check-updates
#   make clean

.DEFAULT_GOAL := help

SCRIPTS      := scripts
PACKAGES_DIR := packages

PKG     ?=
VER     ?=
PKGREL  ?=
FORCE   ?= 0
SSH     ?= 0
DRY_RUN ?= 0
DOCKER  ?= 0

.PHONY: help list import update refresh push push-all check-updates clean

help:
	@echo "AUR PKGBUILD helpers"
	@echo ""
	@echo "Targets:"
	@echo "  make list                              List packages under $(PACKAGES_DIR)/"
	@echo "  make import PKG=<name>                 Import from AUR (no .git / no submodule)"
	@echo "  make import PKG=<name> FORCE=1         Replace existing packages/<name>/"
	@echo "  make import PKG=<name> SSH=1           Clone via SSH instead of HTTPS"
	@echo "  make update PKG=<name> VER=<version>   Set pkgver (+ pkgrel=1), checksums, .SRCINFO"
	@echo "  make refresh PKG=<name>                Regenerate checksums + .SRCINFO only"
	@echo "  make push PKG=<name>                   Push packages/<name>/ to AUR"
	@echo "  make push PKG=<name> DRY_RUN=1         Show AUR diff without pushing"
	@echo "  make push-all                          Push every package to AUR"
	@echo "  make push-all DRY_RUN=1                Dry-run all packages"
	@echo "  make check-updates                     Run nvchecker vs packages/*/.nvchecker.toml"
	@echo "  make clean                             Remove makepkg build artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make update PKG=jay-aur VER=7.5.5"
	@echo "  make refresh PKG=jay-aur"
	@echo "  make update PKG=jay-aur VER=7.5.5 DOCKER=1   # force Arch container"
	@echo "  make push PKG=gvm2-git DRY_RUN=1"
	@echo "  make check-updates"

list:
	@find $(PACKAGES_DIR) -mindepth 1 -maxdepth 1 -type d \
		-exec test -f '{}/PKGBUILD' \; -print \
		| xargs -n1 basename \
		| sort

import:
	@if [ -z "$(PKG)" ]; then \
		echo "error: PKG= is required (e.g. make import PKG=netclient)" >&2; \
		exit 1; \
	fi
	@args="$(PKG)"; \
	if [ "$(FORCE)" = "1" ]; then args="--force $$args"; fi; \
	if [ "$(SSH)" = "1" ]; then args="--ssh $$args"; fi; \
	$(SCRIPTS)/import-from-aur.sh $$args

update:
	@if [ -z "$(PKG)" ] || [ -z "$(VER)" ]; then \
		echo "error: PKG= and VER= are required (e.g. make update PKG=jay-aur VER=7.5.5)" >&2; \
		exit 1; \
	fi
	@args="$(PKG) --version $(VER)"; \
	if [ -n "$(PKGREL)" ]; then args="$$args --pkgrel $(PKGREL)"; fi; \
	if [ "$(DOCKER)" = "1" ]; then args="$$args --docker"; fi; \
	$(SCRIPTS)/update-pkgbuild.sh $$args

refresh:
	@if [ -z "$(PKG)" ]; then \
		echo "error: PKG= is required (e.g. make refresh PKG=jay-aur)" >&2; \
		exit 1; \
	fi
	@args="$(PKG)"; \
	if [ -n "$(PKGREL)" ]; then args="$$args --pkgrel $(PKGREL)"; fi; \
	if [ "$(DOCKER)" = "1" ]; then args="$$args --docker"; fi; \
	$(SCRIPTS)/update-pkgbuild.sh $$args

push:
	@if [ -z "$(PKG)" ]; then \
		echo "error: PKG= is required (e.g. make push PKG=gvm2-git)" >&2; \
		exit 1; \
	fi
	@args="$(PKG)"; \
	if [ "$(DRY_RUN)" = "1" ]; then args="--dry-run $$args"; fi; \
	$(SCRIPTS)/push-to-aur.sh $$args

push-all:
	@args="--all"; \
	if [ "$(DRY_RUN)" = "1" ]; then args="--dry-run $$args"; fi; \
	$(SCRIPTS)/push-to-aur.sh $$args

check-updates:
	@$(SCRIPTS)/check-updates.sh

clean:
	@echo "Removing makepkg artifacts under $(PACKAGES_DIR)/ ..."
	@rm -rf $(PACKAGES_DIR)/*/src \
		$(PACKAGES_DIR)/*/pkg \
		$(PACKAGES_DIR)/*/*.pkg.tar.* \
		$(PACKAGES_DIR)/*/*.src.tar.* \
		$(PACKAGES_DIR)/*/*.log
	@echo "Done."
