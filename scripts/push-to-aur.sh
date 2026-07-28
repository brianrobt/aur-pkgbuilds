#!/usr/bin/env bash
# Push package directories from packages/ to their AUR git remotes.
#
# Usage:
#   ./scripts/push-to-aur.sh <pkg> [<pkg> ...]
#   ./scripts/push-to-aur.sh --all
#   ./scripts/push-to-aur.sh --dry-run --all
#
# Env:
#   AUR_GIT_PREFIX   SSH URL prefix (default: ssh://aur@aur.archlinux.org)
#   GIT_AUTHOR_NAME  Commit author name (default: Brian Thompson)
#   GIT_AUTHOR_EMAIL Commit author email (default: brianrobt@pm.me)
#   DRY_RUN=1        Same as --dry-run

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="${ROOT}/packages"
URLS_FILE="${ROOT}/scripts/repo_urls.txt"
AUR_GIT_PREFIX="${AUR_GIT_PREFIX:-ssh://aur@aur.archlinux.org}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Brian Thompson}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-brianrobt@pm.me}"

DRY_RUN="${DRY_RUN:-0}"
case "$DRY_RUN" in
  1|true|TRUE|yes|YES) DRY_RUN=1 ;;
  *) DRY_RUN=0 ;;
esac
PACKAGES=()

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --all)
      while IFS= read -r dir; do
        PACKAGES+=("$(basename "$dir")")
      done < <(find "$PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
    *)
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "No packages specified. Use --all or pass package names." >&2
  usage 1
fi

aur_url_for() {
  local pkg="$1"
  if [[ -f "$URLS_FILE" ]]; then
    local mapped
    mapped="$(awk -F': ' -v p="$pkg" '$1 == p { print $2; exit }' "$URLS_FILE" || true)"
    if [[ -n "${mapped:-}" ]]; then
      printf '%s\n' "$mapped"
      return
    fi
  fi
  printf '%s/%s.git\n' "$AUR_GIT_PREFIX" "$pkg"
}

sync_package_files() {
  local src="$1"
  local dest="$2"

  # Monorepo is source of truth. Keep CI/local-only files out of AUR.
  rsync -a --delete \
    --exclude '.git/' \
    --exclude 'Dockerfile' \
    --exclude '.dockerignore' \
    --exclude '.nvchecker.toml' \
    --exclude '.gitignore' \
    --exclude 'src/' \
    --exclude 'pkg/' \
    --exclude '*.tar.gz' \
    --exclude '*.tar.zst' \
    --exclude '*.pkg.tar*' \
    --exclude '*.log' \
    "${src}/" "${dest}/"
}

push_one() {
  local pkg="$1"
  local pkg_dir="${PACKAGES_DIR}/${pkg}"
  local aur_url
  local workdir
  local pkgver pkgrel message

  if [[ ! -d "$pkg_dir" ]]; then
    echo "error: package directory not found: $pkg_dir" >&2
    return 1
  fi
  if [[ ! -f "${pkg_dir}/PKGBUILD" ]]; then
    echo "error: missing PKGBUILD in $pkg_dir" >&2
    return 1
  fi
  if [[ ! -f "${pkg_dir}/.SRCINFO" ]]; then
    echo "error: missing .SRCINFO in $pkg_dir (run: makepkg --printsrcinfo > .SRCINFO)" >&2
    return 1
  fi

  aur_url="$(aur_url_for "$pkg")"
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/aur-push-${pkg}.XXXXXX")"

  cleanup() { rm -rf "$workdir"; }
  trap cleanup EXIT

  echo "==> ${pkg}: cloning ${aur_url}"
  git clone --depth 1 "$aur_url" "$workdir"

  echo "==> ${pkg}: syncing files from packages/${pkg}"
  sync_package_files "$pkg_dir" "$workdir"

  (
    cd "$workdir"
    git config user.name "$GIT_AUTHOR_NAME"
    git config user.email "$GIT_AUTHOR_EMAIL"

    if [[ -z "$(git status --porcelain)" ]]; then
      echo "==> ${pkg}: AUR already up to date"
      exit 0
    fi

    git add -A

    pkgver="$(grep -E '^pkgver=' PKGBUILD | head -1 | cut -d= -f2- | tr -d "\"'")"
    pkgrel="$(grep -E '^pkgrel=' PKGBUILD | head -1 | cut -d= -f2- | tr -d "\"'")"
    message="update: ${pkg} ${pkgver}-${pkgrel}"

    echo "==> ${pkg}: changes"
    git --no-pager diff --cached --stat

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "==> ${pkg}: dry-run; would commit and push: ${message}"
      exit 0
    fi

    git commit -m "$message"
    # AUR uses master
    git push origin HEAD:master
    echo "==> ${pkg}: pushed to AUR"
  )

  trap - EXIT
  cleanup
}

echo "Packages: ${PACKAGES[*]}"
[[ "$DRY_RUN" -eq 1 ]] && echo "(dry-run mode)"

failed=0
for pkg in "${PACKAGES[@]}"; do
  if ! push_one "$pkg"; then
    echo "error: failed to push ${pkg}" >&2
    failed=1
  fi
done

exit "$failed"
