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

# push_one exit codes:
#   0 = success (or already up to date / dry-run)
#   1 = package-specific failure (caller should continue with other packages)
#   2 = AUR unavailable / maintenance (caller should abort remaining packages)
is_aur_maintenance_error() {
  local log_file="$1"
  grep -qiE \
    'down due to maintenance|will be back soon|aur is down' \
    "$log_file"
}

push_one() {
  local pkg="$1"
  local pkg_dir="${PACKAGES_DIR}/${pkg}"
  local aur_url
  local workdir
  local pkgver pkgrel message
  local status
  local clone_log

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
  clone_log="$(mktemp "${TMPDIR:-/tmp}/aur-clone-${pkg}.XXXXXX.log")"

  cleanup() {
    rm -rf "$workdir"
    rm -f "$clone_log"
  }
  trap cleanup EXIT

  echo "==> ${pkg}: cloning ${aur_url}"
  # Note: callers may invoke this function under `if` / `||`, which disables
  # `set -e` inside the function. Check clone (and later git ops) explicitly.
  if ! git clone --depth 1 "$aur_url" "$workdir" >"$clone_log" 2>&1; then
    cat "$clone_log" >&2
    if is_aur_maintenance_error "$clone_log"; then
      echo "error: ${pkg}: AUR is down for maintenance" >&2
      trap - EXIT
      cleanup
      return 2
    fi
    echo "error: ${pkg}: failed to clone ${aur_url}" >&2
    echo "error: ${pkg}: check SSH key registration and that the AUR package exists" >&2
    trap - EXIT
    cleanup
    return 1
  fi
  # Clone can print banners to the log even on success; show them.
  if [[ -s "$clone_log" ]]; then
    cat "$clone_log" >&2
  fi
  if [[ ! -d "${workdir}/.git" ]]; then
    echo "error: ${pkg}: clone succeeded but ${workdir} is not a git repo" >&2
    trap - EXIT
    cleanup
    return 1
  fi

  echo "==> ${pkg}: syncing files from packages/${pkg}"
  sync_package_files "$pkg_dir" "$workdir"

  if ! (
    set -euo pipefail
    cd "$workdir"
    git config user.name "$GIT_AUTHOR_NAME"
    git config user.email "$GIT_AUTHOR_EMAIL"

    status="$(git status --porcelain)"
    if [[ -z "${status}" ]]; then
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
  ); then
    echo "error: ${pkg}: git update/push failed" >&2
    trap - EXIT
    cleanup
    return 1
  fi

  trap - EXIT
  cleanup
}

echo "Packages: ${PACKAGES[*]}"
[[ "$DRY_RUN" -eq 1 ]] && echo "(dry-run mode)"

failed=0
for pkg in "${PACKAGES[@]}"; do
  rc=0
  push_one "$pkg" || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    echo "error: AUR maintenance detected; aborting remaining packages" >&2
    exit 2
  fi
  if [[ "$rc" -ne 0 ]]; then
    echo "error: failed to push ${pkg} (continuing with remaining packages)" >&2
    failed=1
  fi
done

exit "$failed"
