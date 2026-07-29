#!/usr/bin/env bash
# Bump and/or refresh a package under packages/:
#   - optionally set pkgver / pkgrel
#   - regenerate checksums (makepkg -g / updpkgsums)
#   - regenerate .SRCINFO
#
# Usage:
#   ./scripts/update-pkgbuild.sh <pkg>
#   ./scripts/update-pkgbuild.sh <pkg> --version 7.5.5
#   ./scripts/update-pkgbuild.sh <pkg> --version 7.5.5 --pkgrel 1
#   ./scripts/update-pkgbuild.sh <pkg> --docker   # force Arch container
#
# Prefers local makepkg when available (works on macOS Homebrew pacman).
# Docker uses --platform linux/amd64 (official archlinux image is amd64-only).
#
# Env:
#   ARCH_IMAGE   Docker image (default: archlinux:latest)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="${ROOT}/packages"
ARCH_IMAGE="${ARCH_IMAGE:-archlinux:latest}"

PKG=""
VERSION=""
PKGREL=""
FORCE_DOCKER=0

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --version)
      VERSION="${2:?}"
      shift 2
      ;;
    --pkgrel)
      PKGREL="${2:?}"
      shift 2
      ;;
    --docker)
      FORCE_DOCKER=1
      shift
      ;;
    --no-docker)
      # backwards-compatible alias: prefer local
      FORCE_DOCKER=0
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
    *)
      if [[ -n "$PKG" ]]; then
        echo "Only one package name allowed" >&2
        usage 1
      fi
      PKG="$1"
      shift
      ;;
  esac
done

if [[ -z "$PKG" ]]; then
  echo "error: package name required" >&2
  usage 1
fi

PKG_DIR="${PACKAGES_DIR}/${PKG}"
PKGBUILD="${PKG_DIR}/PKGBUILD"

if [[ ! -f "$PKGBUILD" ]]; then
  echo "error: missing ${PKGBUILD}" >&2
  exit 1
fi

set_pkgbuild_field() {
  local field="$1"
  local value="$2"
  python3 - "$PKGBUILD" "$field" "$value" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
field, value = sys.argv[2], sys.argv[3]
text = path.read_text()
pattern = re.compile(rf"^{re.escape(field)}=.*$", re.M)
if not pattern.search(text):
    raise SystemExit(f"error: {field}= not found in {path}")
path.write_text(pattern.sub(f"{field}={value}", text, count=1))
print(f"set {field}={value}")
PY
}

is_vcs_pkgbuild() {
  grep -qE '^pkgver\(\)' "$PKGBUILD" || return 1
  grep -qE 'source=.*git\+' "$PKGBUILD" || return 1
  return 0
}

apply_makepkg_checksums() {
  # Replace integrity arrays in PKGBUILD with `makepkg -g` output.
  local generated
  generated="$(makepkg -g)"
  GENERATED="$generated" python3 - "$PKGBUILD" <<'PY'
import os, pathlib, re, sys
path = pathlib.Path(sys.argv[1])
generated = os.environ["GENERATED"].strip() + "\n"
text = path.read_text()
text = re.sub(
    r"^(md5sums|sha1sums|sha224sums|sha256sums|sha384sums|sha512sums|b2sums)=(\((?:[^)]*)\)|\([\s\S]*?\))\n?",
    "",
    text,
    flags=re.M,
)
text = re.sub(r"\n{3,}", "\n\n", text).rstrip() + "\n"

# Prefer placing checksums immediately after the source=(...) array.
source_match = re.search(r"^source=(\((?:[^)]*)\)|\([\s\S]*?\))\n", text, flags=re.M)
if source_match:
    insert_at = source_match.end()
    text = text[:insert_at] + generated + text[insert_at:]
    if not text.endswith("\n"):
        text += "\n"
else:
    text = text.rstrip() + "\n\n" + generated

path.write_text(text)
print("updated integrity checksums from makepkg -g")
PY
}

echo "==> package: ${PKG}"

if [[ -n "$VERSION" ]]; then
  if is_vcs_pkgbuild; then
    echo "warning: ${PKG} looks like a VCS package (pkgver() + git source)." >&2
    echo "warning: setting pkgver=${VERSION} may be overwritten on the next VCS refresh." >&2
  fi
  set_pkgbuild_field pkgver "$VERSION"
  if [[ -z "$PKGREL" ]]; then
    PKGREL=1
  fi
fi

if [[ -n "$PKGREL" ]]; then
  set_pkgbuild_field pkgrel "$PKGREL"
fi

if is_vcs_pkgbuild; then
  MODE=vcs
else
  MODE=release
fi
echo "==> refresh mode: ${MODE}"

USE_DOCKER="$FORCE_DOCKER"
if [[ "$USE_DOCKER" -eq 0 ]] && ! command -v makepkg >/dev/null 2>&1; then
  echo "==> local makepkg not found; falling back to Docker"
  USE_DOCKER=1
fi

refresh_local() {
  (
    cd "$PKG_DIR"
    if [[ "$MODE" == "vcs" ]]; then
      echo "==> VCS refresh: makepkg -o (updates pkgver from VCS)"
      makepkg -o --noprepare --noconfirm
    else
      echo "==> release refresh: makepkg -g"
      apply_makepkg_checksums
    fi
    echo "==> regenerating .SRCINFO"
    makepkg --printsrcinfo > .SRCINFO
  )
}

refresh_docker() {
  docker run --rm --platform linux/amd64 \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -e MODE="$MODE" \
    -v "$PKG_DIR":/pkg \
    -w /pkg \
    "$ARCH_IMAGE" \
    bash -lc '
      set -euo pipefail
      pacman-key --init
      pacman-key --populate archlinux
      pacman -Syu --noconfirm --needed base-devel git pacman-contrib

      if ! id builder &>/dev/null; then
        useradd -m -G wheel builder
      fi
      echo "builder ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/builder
      chmod 440 /etc/sudoers.d/builder
      chown -R builder:builder /pkg

      if [[ "$MODE" == "vcs" ]]; then
        echo "==> VCS refresh: makepkg -o"
        sudo -u builder makepkg -o --noprepare --noconfirm
      else
        echo "==> release refresh: updpkgsums"
        sudo -u builder updpkgsums
      fi

      echo "==> regenerating .SRCINFO"
      sudo -u builder bash -lc "makepkg --printsrcinfo > .SRCINFO"
      chown -R "$HOST_UID:$HOST_GID" /pkg
    '
}

if [[ "$USE_DOCKER" -eq 1 ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker not found and local makepkg unavailable" >&2
    exit 1
  fi
  refresh_docker
else
  refresh_local
fi

echo "==> done: ${PKG_DIR}"
grep -E '^(pkgver|pkgrel|sha256sums)=' "$PKGBUILD" || true
echo "    Review git diff, then open a PR / make push PKG=${PKG}"
