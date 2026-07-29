# AUR PKGBUILDs

A collection of PKGBUILDs for packages I maintain in the Arch User Repository (AUR).

## Layout

```text
packages/<pkg>/     # PKGBUILD + supporting files (source of truth)
scripts/            # import / publish helpers
.github/workflows/  # verify (Arch makepkg) + publish to AUR
```

Each package is plain files in this monorepo (not git submodules). Publish copies
`packages/<pkg>/` to the matching AUR git repo.

## Makefile

```sh
make help
make list

# Adopt / import from AUR (no .git directory)
make import PKG=netclient
make import PKG=netclient FORCE=1
make import PKG=netclient SSH=1

# Bump upstream version + regenerate checksums / .SRCINFO (uses Docker/Arch)
make update PKG=jay-aur VER=7.5.5
make update PKG=jay-aur VER=7.5.5 PKGREL=2

# After editing PKGBUILD yourself (pkgver already set)
make refresh PKG=jay-aur

# Publish to AUR
make push PKG=gvm2-git
make push PKG=gvm2-git DRY_RUN=1
make push-all

# Remove local makepkg leftovers
make clean
```

Scripts: `scripts/import-from-aur.sh`, `scripts/update-pkgbuild.sh`, `scripts/push-to-aur.sh`.

## GitHub Actions

- **Verify packages** — build/install each `packages/*/PKGBUILD` in Arch Linux (PRs + before publish)
- **Publish to AUR** — push to AUR after verify succeeds

See [`.github/workflows/README.md`](.github/workflows/README.md).

## Prerequisites

- Git
- SSH key registered on your AUR account (for `make push`)
- Docker (optional; used by CI verify, not required locally)

## Contributing

This repository is primarily for personal package maintenance, but contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with your changes

For new package suggestions, please open an issue first.

## License

The build scripts and configuration files in this repository are provided as-is for educational and maintenance purposes. Individual packages maintain their original licenses as specified in their respective PKGBUILDs.
