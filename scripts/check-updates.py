#!/usr/bin/env python3
"""Compare packages/*/.nvchecker.toml upstream versions to PKGBUILD pkgver.

Runs nvchecker + nvcmp and prints an email-ready report.

Usage:
  ./scripts/check-updates.py
  ./scripts/check-updates.py --body-file /tmp/body.txt --github-output "$GITHUB_OUTPUT"

Env:
  GITHUB_TOKEN / GH_TOKEN  optional; used as nvchecker GitHub API key
  NVCHECKER_KEYFILE        optional path to an nvchecker keyfile
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SECTION_RE = re.compile(r"^\[([^\]]+)\]\s*$")
PKGVER_RE = re.compile(r"^pkgver=(.+)$", re.MULTILINE)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def require_commands(*names: str) -> None:
    missing = [name for name in names if shutil.which(name) is None]
    if missing:
        joined = ", ".join(missing)
        print(f"error: missing required command(s): {joined}", file=sys.stderr)
        sys.exit(1)


def find_configs(packages_dir: Path) -> list[Path]:
    return sorted(packages_dir.glob("*/*.nvchecker.toml"))


def parse_pkgver(pkgbuild: Path) -> str | None:
    match = PKGVER_RE.search(pkgbuild.read_text(encoding="utf-8"))
    if not match:
        return None
    return match.group(1).strip().strip("'\"")


def load_package_entries(
    config_paths: list[Path],
) -> tuple[dict[str, str], list[str], list[str]]:
    """Return (name -> pkgver, cleaned config bodies, setup errors)."""
    entries: dict[str, str] = {}
    bodies: list[str] = []
    errors: list[str] = []
    seen: set[str] = set()

    for cfg_path in config_paths:
        pkg_dir = cfg_path.parent
        pkgbuild = pkg_dir / "PKGBUILD"
        text = cfg_path.read_text(encoding="utf-8")

        names: list[str] = []
        cleaned_lines: list[str] = []
        skip = False
        for line in text.splitlines():
            match = SECTION_RE.match(line.strip())
            if match:
                name = match.group(1)
                skip = name == "__config__"
                if not skip:
                    names.append(name)
            if not skip:
                cleaned_lines.append(line)

        if not names:
            errors.append(f"{cfg_path}: no package entries found")
            continue

        if not pkgbuild.is_file():
            for name in names:
                errors.append(f"{name}: missing PKGBUILD at {pkgbuild}")
            continue

        pkgver = parse_pkgver(pkgbuild)
        if pkgver is None:
            for name in names:
                errors.append(f"{name}: could not find pkgver= in {pkgbuild}")
            continue

        if any(name in seen for name in names):
            for name in names:
                if name in seen:
                    errors.append(f"{name}: duplicate nvchecker entry")
            continue

        for name in names:
            seen.add(name)
            entries[name] = pkgver

        body = "\n".join(cleaned_lines).strip()
        if body:
            bodies.append(body)

    return entries, bodies, errors


def write_combined_config(
    path: Path,
    oldver_path: Path,
    newver_path: Path,
    bodies: list[str],
) -> None:
    parts = [
        "[__config__]",
        f'oldver = "{oldver_path}"',
        f'newver = "{newver_path}"',
        "",
        *bodies,
    ]
    path.write_text("\n".join(parts).rstrip() + "\n", encoding="utf-8")


def write_oldver(path: Path, entries: dict[str, str]) -> None:
    payload = {
        "version": 2,
        "data": {name: {"version": ver} for name, ver in sorted(entries.items())},
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def maybe_keyfile(path: Path) -> Path | None:
    keyfile_env = os.environ.get("NVCHECKER_KEYFILE")
    if keyfile_env and Path(keyfile_env).is_file():
        path.write_text(Path(keyfile_env).read_text(encoding="utf-8"), encoding="utf-8")
        return path

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        path.write_text(f'[keys]\ngithub = "{token}"\n', encoding="utf-8")
        return path

    return None


def run_nvchecker(config: Path, keyfile: Path | None, log_path: Path) -> int:
    cmd = [
        "nvchecker",
        "-c",
        str(config),
        "--logger",
        "json",
        "--json-log-fd",
        "1",
        "--failures",
    ]
    if keyfile is not None:
        cmd.extend(["-k", str(keyfile)])

    with log_path.open("w", encoding="utf-8") as log_fh:
        return subprocess.run(cmd, check=False, stdout=log_fh).returncode


def run_nvcmp(config: Path) -> list[dict]:
    proc = subprocess.run(
        ["nvcmp", "-c", str(config), "-j", "-n"],
        check=False,
        capture_output=True,
        text=True,
    )
    raw = proc.stdout.strip() or "[]"
    try:
        updates = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"error: nvcmp failed (exit {proc.returncode}): {exc}", file=sys.stderr)
        if proc.stderr:
            print(proc.stderr, file=sys.stderr)
        print(raw, file=sys.stderr)
        sys.exit(proc.returncode or 1)

    if not isinstance(updates, list):
        print("error: nvcmp JSON was not a list", file=sys.stderr)
        sys.exit(1)
    return updates


def collect_check_errors(log_path: Path) -> list[str]:
    if not log_path.is_file() or log_path.stat().st_size == 0:
        return []

    errors: list[str] = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("level") != "error":
            continue
        name = event.get("name") or "unknown"
        msg = event.get("error") or event.get("event") or "unknown error"
        msg = str(msg).split("\n", 1)[0]
        if len(msg) > 240:
            msg = msg[:237] + "..."
        errors.append(f"{name}: {msg}")
    return errors


def build_report(
    updates: list[dict],
    setup_errors: list[str],
    check_errors: list[str],
) -> tuple[str, dict]:
    seen: set[str] = set()
    errors: list[str] = []
    for item in setup_errors + check_errors:
        if item not in seen:
            seen.add(item)
            errors.append(item)

    update_lines = [
        f"- {item.get('name', 'unknown')}: "
        f"{item.get('oldver', '?')} -> {item.get('newver', '?')}"
        for item in updates
    ]

    has_updates = bool(update_lines)
    has_errors = bool(errors)

    if not has_updates and not has_errors:
        body = "No AUR packages need to be updated.\n"
        subject = "No AUR packages need updating"
    elif has_updates and not has_errors:
        body = (
            "AUR packages with updates available:\n\n"
            + "\n".join(update_lines)
            + "\n"
        )
        names = ", ".join(item.get("name", "?") for item in updates)
        subject = f"AUR updates available ({len(update_lines)}): {names}"
    elif has_errors and not has_updates:
        body = (
            "nvchecker reported errors:\n\n"
            + "\n".join(f"- {e}" for e in errors)
            + "\n"
        )
        subject = f"AUR nvchecker errors ({len(errors)})"
    else:
        body = (
            "AUR packages with updates available:\n\n"
            + "\n".join(update_lines)
            + "\n\nnvchecker reported errors:\n\n"
            + "\n".join(f"- {e}" for e in errors)
            + "\n"
        )
        subject = (
            f"AUR updates available ({len(update_lines)}) + errors ({len(errors)})"
        )

    if len(subject) > 90:
        subject = subject[:87] + "..."

    meta = {
        "has_updates": has_updates,
        "has_errors": has_errors,
        "subject": subject,
        "update_count": len(update_lines),
        "error_count": len(errors),
    }
    return body, meta


def write_github_output(path: Path, meta: dict) -> None:
    subject = meta["subject"]
    with path.open("a", encoding="utf-8") as fh:
        fh.write(f"has_updates={'true' if meta['has_updates'] else 'false'}\n")
        fh.write(f"has_errors={'true' if meta['has_errors'] else 'false'}\n")
        fh.write(f"update_count={meta['update_count']}\n")
        fh.write(f"error_count={meta['error_count']}\n")
        if "\n" in subject:
            fh.write(f"subject<<EOF\n{subject}\nEOF\n")
        else:
            fh.write(f"subject={subject}\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check AUR package upstream versions with nvchecker."
    )
    parser.add_argument("--body-file", type=Path, help="Write report body to this file")
    parser.add_argument(
        "--github-output",
        type=Path,
        help="Append GitHub Actions outputs to this file",
    )
    args = parser.parse_args()

    require_commands("nvchecker", "nvcmp")

    packages_dir = repo_root() / "packages"
    configs = find_configs(packages_dir)
    if not configs:
        print("error: no packages/*/.nvchecker.toml files found", file=sys.stderr)
        return 1

    entries, bodies, setup_errors = load_package_entries(configs)
    if not entries:
        print("error: no usable nvchecker entries found", file=sys.stderr)
        for err in setup_errors:
            print(f"  {err}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="aur-nvchecker.") as tmp:
        workdir = Path(tmp)
        combined = workdir / "nvchecker.toml"
        oldver = workdir / "old_ver.json"
        newver = workdir / "new_ver.json"
        log_json = workdir / "nvchecker.jsonl"
        keyfile_path = maybe_keyfile(workdir / "keyfile.toml")

        write_combined_config(combined, oldver, newver, bodies)
        write_oldver(oldver, entries)

        nv_exit = run_nvchecker(combined, keyfile_path, log_json)
        # 0 = ok, 3 = check failures (still report); anything else is fatal.
        if nv_exit not in (0, 3):
            print(f"error: nvchecker exited with status {nv_exit}", file=sys.stderr)
            if log_json.stat().st_size:
                sys.stderr.write(log_json.read_text(encoding="utf-8"))
            return nv_exit

        updates = run_nvcmp(combined)
        check_errors = collect_check_errors(log_json)
        body, meta = build_report(updates, setup_errors, check_errors)

    sys.stdout.write(body)
    if args.body_file is not None:
        args.body_file.write_text(body, encoding="utf-8")
    if args.github_output is not None:
        write_github_output(args.github_output, meta)
    return 0


if __name__ == "__main__":
    sys.exit(main())
