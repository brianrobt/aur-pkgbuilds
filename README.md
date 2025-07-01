# aur-pkgbuilds

PKGBUILDs for AUR packages I maintain.

## Usage: Makefile Commands

This repository provides a Makefile to automate common package maintenance tasks. Below are the most useful commands:

### Clone and Sync Packages

**Clone and sync a single package from its submodule:**
```sh
make clone PKG=<package-name>
# Example:
make clone PKG=alist
```

**Add `CLEAN=true` to remove any temporary directories:**
```sh
make clone PKG=alist CLEAN=true
```

**Clone and sync all packages:**
```sh
make clone-all
# Or with cleanup:
make clone-all CLEAN=true
```

### Build and Run in Docker

**Build and run a package in Docker (if a Dockerfile is present):**
```sh
make aur-build PKG=<package-name>
# Example:
make aur-build PKG=alist
```

### Submodule Management

**Initialize all submodules:**
```sh
make init-submodules
```

**Update all submodules to the latest commit:**
```sh
make update-aur-repos
```

### Clean Temporary Files

**Clean up temporary files and directories:**
```sh
make clean
```

### Help

**Show all available commands:**
```sh
make help
```

---

You can also call the scripts in `scripts/` directly for advanced usage. See the Makefile or run `make help` for more details.
