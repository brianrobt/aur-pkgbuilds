#!/usr/bin/env python3
"""Bump and/or refresh a package under packages/.

- optionally set pkgver / pkgrel
- regenerate checksums (makepkg -g / updpkgsums)
- regenerate .SRCINFO

Prefers local makepkg when available (works on macOS Homebrew pacman).
Docker uses --platform linux/amd64 (official archlinux image is amd64-only).

Usage:
  ./scripts/update-pkgbuild.py <pkg>
  ./scripts/update-pkgbuild.py <pkg> --version 7.5.5
  ./scripts/update-pkgbuild.py <pkg> --version 7.5.5 --pkgrel 1
  ./scripts/update-pkgbuild.py <pkg> --docker

Env:
  ARCH_IMAGE   Docker image (default: archlinux:latest)
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

CHECKSUM_RE = re.compile(
    r"^(md5sums|sha1sums|sha224sums|sha256sums|sha384sums|sha512sums|b2sums)="
    r"(\((?:[^)]*)\)|\([\s\S]*?\))\n?",
    re.M,
)
SOURCE_RE = re.compile(r"^source=(\((?:[^)]*)\)|\([\s\S]*?\))\n", re.M)
PKGVER_FUNC_RE = re.compile(r"^pkgver\(\)", re.M)
GIT_SOURCE_RE = re.compile(r"git\+")


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def set_pkgbuild_field(pkgbuild: Path, field: str, value: str) -> None:
    text = pkgbuild.read_text(encoding="utf-8")
    pattern = re.compile(rf"^{re.escape(field)}=.*$", re.M)
    if not pattern.search(text):
        raise SystemExit(f"error: {field}= not found in {pkgbuild}")
    pkgbuild.write_text(pattern.sub(f"{field}={value}", text, count=1), encoding="utf-8")
    print(f"set {field}={value}")


def is_vcs_pkgbuild(pkgbuild: Path) -> bool:
    text = pkgbuild.read_text(encoding="utf-8")
    return bool(PKGVER_FUNC_RE.search(text) and GIT_SOURCE_RE.search(text))


def apply_makepkg_checksums(pkg_dir: Path, pkgbuild: Path) -> None:
    """Replace integrity arrays in PKGBUILD with `makepkg -g` output."""
    generated = subprocess.check_output(
        ["makepkg", "-g"],
        cwd=pkg_dir,
        text=True,
    ).strip()
    if not generated:
        raise SystemExit("error: makepkg -g produced no checksum output")

    text = pkgbuild.read_text(encoding="utf-8")
    text = CHECKSUM_RE.sub("", text)
    text = re.sub(r"\n{3,}", "\n\n", text).rstrip() + "\n"
    generated = generated + "\n"

    source_match = SOURCE_RE.search(text)
    if source_match:
        insert_at = source_match.end()
        text = text[:insert_at] + generated + text[insert_at:]
        if not text.endswith("\n"):
            text += "\n"
    else:
        text = text.rstrip() + "\n\n" + generated

    pkgbuild.write_text(text, encoding="utf-8")
    print("updated integrity checksums from makepkg -g")


def refresh_local(pkg_dir: Path, pkgbuild: Path, mode: str) -> None:
    if mode == "vcs":
        print("==> VCS refresh: makepkg -o (updates pkgver from VCS)")
        subprocess.run(
            ["makepkg", "-o", "--noprepare", "--noconfirm"],
            cwd=pkg_dir,
            check=True,
        )
    else:
        print("==> release refresh: makepkg -g")
        apply_makepkg_checksums(pkg_dir, pkgbuild)

    print("==> regenerating .SRCINFO")
    srcinfo = subprocess.check_output(
        ["makepkg", "--printsrcinfo"],
        cwd=pkg_dir,
        text=True,
    )
    (pkg_dir / ".SRCINFO").write_text(srcinfo, encoding="utf-8")


def refresh_docker(pkg_dir: Path, mode: str, arch_image: str) -> None:
    if shutil.which("docker") is None:
        raise SystemExit("error: docker not found and local makepkg unavailable")

    script = r"""
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
"""

    subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "--platform",
            "linux/amd64",
            "-e",
            f"HOST_UID={os.getuid()}",
            "-e",
            f"HOST_GID={os.getgid()}",
            "-e",
            f"MODE={mode}",
            "-v",
            f"{pkg_dir}:/pkg",
            "-w",
            "/pkg",
            arch_image,
            "bash",
            "-lc",
            script,
        ],
        check=True,
    )


def summarize(pkgbuild: Path) -> None:
    for line in pkgbuild.read_text(encoding="utf-8").splitlines():
        if re.match(r"^(pkgver|pkgrel|sha256sums)=", line):
            print(line)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Bump and/or refresh a package under packages/."
    )
    parser.add_argument("pkg", help="Package directory name under packages/")
    parser.add_argument("--version", help="Set pkgver to this value")
    parser.add_argument("--pkgrel", help="Set pkgrel to this value")
    parser.add_argument(
        "--docker",
        action="store_true",
        help="Force Arch Linux Docker refresh",
    )
    parser.add_argument(
        "--no-docker",
        action="store_true",
        help="Prefer local makepkg (default)",
    )
    args = parser.parse_args()

    if args.docker and args.no_docker:
        print("error: --docker and --no-docker are mutually exclusive", file=sys.stderr)
        return 1

    pkg_dir = repo_root() / "packages" / args.pkg
    pkgbuild = pkg_dir / "PKGBUILD"
    if not pkgbuild.is_file():
        print(f"error: missing {pkgbuild}", file=sys.stderr)
        return 1

    version = args.version
    pkgrel = args.pkgrel
    force_docker = bool(args.docker)
    arch_image = os.environ.get("ARCH_IMAGE", "archlinux:latest")

    print(f"==> package: {args.pkg}")

    vcs = is_vcs_pkgbuild(pkgbuild)
    if version:
        if vcs:
            print(
                f"warning: {args.pkg} looks like a VCS package (pkgver() + git source).",
                file=sys.stderr,
            )
            print(
                f"warning: setting pkgver={version} may be overwritten on the next VCS refresh.",
                file=sys.stderr,
            )
        set_pkgbuild_field(pkgbuild, "pkgver", version)
        if pkgrel is None:
            pkgrel = "1"

    if pkgrel is not None:
        set_pkgbuild_field(pkgbuild, "pkgrel", pkgrel)

    # Re-read after edits in case the file changed.
    mode = "vcs" if is_vcs_pkgbuild(pkgbuild) else "release"
    print(f"==> refresh mode: {mode}")

    use_docker = force_docker
    if not use_docker and shutil.which("makepkg") is None:
        print("==> local makepkg not found; falling back to Docker")
        use_docker = True

    if use_docker:
        refresh_docker(pkg_dir, mode, arch_image)
    else:
        refresh_local(pkg_dir, pkgbuild, mode)

    print(f"==> done: {pkg_dir}")
    summarize(pkgbuild)
    print(f"    Review git diff, then open a PR / make push PKG={args.pkg}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
