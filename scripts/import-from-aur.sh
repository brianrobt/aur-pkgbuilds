#!/usr/bin/env bash
# Import an AUR package into packages/ as plain files (no submodule, no .git).
#
# Usage:
#   ./scripts/import-from-aur.sh <pkg> [<pkg> ...]
#   ./scripts/import-from-aur.sh --force netclient
#
# By default clones via HTTPS (no AUR SSH key needed). Use --ssh for SSH.
# Adds packages/<pkg>/ and appends scripts/repo_urls.txt when missing.
#
# Env:
#   AUR_GIT_PREFIX   SSH URL prefix (default: ssh://aur@aur.archlinux.org)
#   AUR_HTTPS_PREFIX HTTPS prefix (default: https://aur.archlinux.org)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="${ROOT}/packages"
URLS_FILE="${ROOT}/scripts/repo_urls.txt"
AUR_GIT_PREFIX="${AUR_GIT_PREFIX:-ssh://aur@aur.archlinux.org}"
AUR_HTTPS_PREFIX="${AUR_HTTPS_PREFIX:-https://aur.archlinux.org}"

FORCE=0
USE_SSH=0
PACKAGES=()

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --force) FORCE=1; shift ;;
    --ssh) USE_SSH=1; shift ;;
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
  echo "No packages specified." >&2
  usage 1
fi

aur_url_for() {
  local pkg="$1"
  if [[ "$USE_SSH" -eq 1 ]]; then
    printf '%s/%s.git\n' "$AUR_GIT_PREFIX" "$pkg"
  else
    printf '%s/%s.git\n' "$AUR_HTTPS_PREFIX" "$pkg"
  fi
}

ensure_repo_urls_entry() {
  local pkg="$1"
  local ssh_url="${AUR_GIT_PREFIX}/${pkg}.git"
  mkdir -p "$(dirname "$URLS_FILE")"
  touch "$URLS_FILE"
  if grep -qE "^${pkg}:" "$URLS_FILE" 2>/dev/null; then
    return 0
  fi
  printf '%s: %s\n' "$pkg" "$ssh_url" >>"$URLS_FILE"
  echo "==> ${pkg}: appended ${URLS_FILE}"
}

import_one() {
  local pkg="$1"
  local dest="${PACKAGES_DIR}/${pkg}"
  local url
  local tmp

  url="$(aur_url_for "$pkg")"

  if [[ -e "$dest" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      echo "error: ${dest} already exists (pass --force to replace)" >&2
      return 1
    fi
    echo "==> ${pkg}: removing existing ${dest}"
    rm -rf "$dest"
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/aur-import-${pkg}.XXXXXX")"
  cleanup() { rm -rf "$tmp"; }
  trap cleanup EXIT

  echo "==> ${pkg}: cloning ${url}"
  git clone --depth 1 "$url" "$tmp/src"

  echo "==> ${pkg}: copying into packages/${pkg} (excluding .git)"
  mkdir -p "$dest"
  # -a preserves modes; trailing slashes copy contents
  rsync -a --exclude '.git/' "$tmp/src/" "$dest/"

  if [[ ! -f "${dest}/PKGBUILD" ]]; then
    echo "error: no PKGBUILD in imported tree for ${pkg}" >&2
    return 1
  fi

  ensure_repo_urls_entry "$pkg"

  trap - EXIT
  cleanup

  echo "==> ${pkg}: imported"
  echo "    Next: adopt/co-maintain on https://aur.archlinux.org/packages/${pkg}"
  echo "          review PKGBUILD, then: git add packages/${pkg} scripts/repo_urls.txt"
}

echo "Packages: ${PACKAGES[*]}"
[[ "$USE_SSH" -eq 1 ]] && echo "(using SSH)" || echo "(using HTTPS)"

failed=0
for pkg in "${PACKAGES[@]}"; do
  if ! import_one "$pkg"; then
    echo "error: failed to import ${pkg}" >&2
    failed=1
  fi
done

exit "$failed"
