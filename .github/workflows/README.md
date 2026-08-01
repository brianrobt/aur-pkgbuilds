# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automating AUR package management.

## Verify packages

`verify-packages.yml` builds each package under `packages/` in an **Arch Linux** container with `makepkg`, installs the resulting archive, and runs light smoke checks (`namcap`, `pacman -Ql`, package-specific file checks).

### Triggers

- **Pull requests** that touch `packages/**`
- **Manual:** Actions → "Verify packages"
- **Reusable:** called by **Publish to AUR** before any AUR push

This is not a full `pkgctl` clean chroot, but it catches broken PKGBUILDs, missing sources/files, bad deps, and failed installs before publish.

## Publish to AUR

`publish-to-aur.yml` copies `packages/<name>/` into the matching AUR git repo and pushes.

### Triggers

- **Manual:** Actions → "Publish to AUR" → Run workflow (optional package name, optional dry-run)
- **Push:** changes under `packages/**` on `master`

Publish always runs **Verify packages** first and skips the AUR push if the build fails.

### Secrets

- `AUR_SSH_PRIVATE_KEY` — private key whose public half is registered on your AUR account

### Local usage

```bash
./scripts/push-to-aur.sh --dry-run gvm2-git
./scripts/push-to-aur.sh gvm2-git
./scripts/push-to-aur.sh --all
```

Package → AUR URL mapping lives in `scripts/repo_urls.txt` (defaults to `ssh://aur@aur.archlinux.org/<dir>.git`).

## Check package updates (nvchecker)

`nvchecker.yml` runs [nvchecker](https://github.com/lilydjwg/nvchecker) against every `packages/*/.nvchecker.toml`, compares results to each package's `pkgver`, and emails a report to `brianrobt@pm.me`.

### Triggers

- **Scheduled:** daily at 14:00 UTC
- **Manual:** Actions → "Check package updates (nvchecker)"

### Email contents

- Updates: package name with `old -> new` versions
- Errors: nvchecker/setup failures (missing config, API errors, etc.)
- Otherwise: `No AUR packages need to be updated.`

### Secrets (SMTP)

Required for the email step (any SMTP provider that can send mail; recipient is ProtonMail):

| Secret | Purpose |
|--------|---------|
| `MAIL_SERVER` | SMTP host (e.g. `smtp.gmail.com`) |
| `MAIL_USERNAME` | SMTP username / From address |
| `MAIL_PASSWORD` | SMTP password or app password |

Port is fixed at `465` (TLS) in the workflow. For Gmail, use an App Password — not your account password.

### Local usage

```bash
brew install nvchecker   # or: pip install nvchecker
make check-updates
# or: ./scripts/check-updates.py
```

`gvm2-git` (VCS / `pkgver()` packages) intentionally has no `.nvchecker.toml`.

> The older `update-git-packages.yml` / `update-github-packages.yml` workflows still assume the pre-`packages/` layout and nested `*-aur` clones. Prefer verify + publish + nvchecker email until those are rewritten.
