# AUR PKGBUILDs

A collection of PKGBUILDs for packages I maintain in the Arch User Repository (AUR).

## About

This repository contains build scripts and configuration files for 20+ packages in the AUR, including development tools, Python libraries, games, and system utilities. Each package is organized as a git submodule linked to its corresponding AUR repository, enabling streamlined maintenance and automated workflows.

### Package Categories

- **Development Tools**: `htmlhint`, `micromamba`, `rapidyaml`, `arduino-avr-core`
- **Python Libraries**: `python-conda`, `python-libmamba`, `python-abydos`, `python-hunspell`, and more
- **System Utilities**: `netclient`, `nmctl`, `rot8-git`, `gnome-shell-extension-panel-osd`
- **Games**: `openmohaa`, `openmohaa-git`
- **Applications**: `alist`, `outwiker`, `proton-pass-bin`, `stable-diffusion-cpp-vulkan-git`

## Features

- **Automated Build System**: Docker-based builds for consistent packaging
- **Submodule Management**: Synchronized git submodules for each AUR package
- **Makefile Automation**: Simple commands for common maintenance tasks
- **Batch Operations**: Clone, build, and update multiple packages at once

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

## Prerequisites

- **Linux**, **macOS**, or **WSL**
- **Git** with submodule support
- **Docker** (for containerized builds)
- **SSH access** to AUR (for maintainers)

## Repository Structure

```
aur-pkgbuilds/
├── Makefile              # Main automation commands
├── scripts/              # Helper scripts
│   ├── repo_urls.txt    # AUR repository URLs
│   ├── clone.sh         # Package cloning script
│   └── aur-build.sh     # Docker build script
├── <package-name>/       # Local package files
│   ├── PKGBUILD         # Build script
│   ├── Dockerfile       # Docker build config (if applicable)
│   └── <package-name>-aur/  # AUR submodule
└── README.md
```

## Advanced Usage

You can also call the scripts in `scripts/` directly for advanced usage:

```bash
# Clone a specific package
./scripts/clone.sh <package-name>

# Build in Docker
./scripts/aur-build.sh <package-name>

# Update all AUR repositories
./scripts/pull_all_repos.sh
```

See the Makefile or run `make help` for more details.

## Contributing

This repository is primarily for personal package maintenance, but contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with your changes

For new package suggestions, please open an issue first.

## License

The build scripts and configuration files in this repository are provided as-is for educational and maintenance purposes. Individual packages maintain their original licenses as specified in their respective PKGBUILDs.
