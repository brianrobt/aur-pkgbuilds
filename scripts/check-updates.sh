#!/usr/bin/env bash
# Check packages/*/.nvchecker.toml against PKGBUILD pkgver.
#
# Usage:
#   ./scripts/check-updates.sh
#   ./scripts/check-updates.sh --body-file /tmp/body.txt --github-output "$GITHUB_OUTPUT"
#
# Env:
#   GITHUB_TOKEN / GH_TOKEN  optional; used as nvchecker GitHub API key
#   NVCHECKER_KEYFILE        optional path to an nvchecker keyfile

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="${ROOT}/packages"

BODY_FILE=""
GITHUB_OUTPUT_FILE=""

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --body-file)
      BODY_FILE="${2:?}"
      shift 2
      ;;
    --github-output)
      GITHUB_OUTPUT_FILE="${2:?}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage 1
      ;;
  esac
done

for cmd in nvchecker nvcmp python3; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: ${cmd} is not installed" >&2
    exit 1
  fi
done

CONFIGS=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && CONFIGS+=("${line}")
done < <(
  find "${PACKAGES_DIR}" -mindepth 2 -maxdepth 2 -type f -name '.nvchecker.toml' | sort
)

if [[ ${#CONFIGS[@]} -eq 0 ]]; then
  echo "error: no packages/*/.nvchecker.toml files found" >&2
  exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/aur-nvchecker.XXXXXX")"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

COMBINED="${WORKDIR}/nvchecker.toml"
OLDVER="${WORKDIR}/old_ver.json"
NEWVER="${WORKDIR}/new_ver.json"
LOG_JSON="${WORKDIR}/nvchecker.jsonl"
KEYFILE="${WORKDIR}/keyfile.toml"
UPDATES_JSON="${WORKDIR}/updates.json"
SETUP_ERRORS="${WORKDIR}/setup_errors.json"
REPORT_META="${WORKDIR}/report_meta.json"

python3 - "${COMBINED}" "${OLDVER}" "${NEWVER}" "${SETUP_ERRORS}" "${CONFIGS[@]}" <<'PY'
import json
import re
import sys
from pathlib import Path

combined_path = Path(sys.argv[1])
oldver_path = Path(sys.argv[2])
newver_path = Path(sys.argv[3])
setup_errors_path = Path(sys.argv[4])
config_paths = [Path(p) for p in sys.argv[5:]]

section_re = re.compile(r"^\[([^\]]+)\]\s*$")
pkgver_re = re.compile(r"^pkgver=(.+)$", re.MULTILINE)

entries: dict[str, str] = {}
bodies: list[str] = []
errors: list[str] = []
seen_names: set[str] = set()

for cfg_path in config_paths:
    pkg_dir = cfg_path.parent
    pkgbuild = pkg_dir / "PKGBUILD"
    text = cfg_path.read_text(encoding="utf-8")

    names: list[str] = []
    cleaned_lines: list[str] = []
    skip = False
    for line in text.splitlines():
        stripped = line.strip()
        m = section_re.match(stripped)
        if m:
            name = m.group(1)
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

    pkgbuild_text = pkgbuild.read_text(encoding="utf-8")
    m = pkgver_re.search(pkgbuild_text)
    if not m:
        for name in names:
            errors.append(f"{name}: could not find pkgver= in {pkgbuild}")
        continue

    pkgver = m.group(1).strip().strip("'\"")
    dup = False
    for name in names:
        if name in seen_names:
            errors.append(f"{name}: duplicate nvchecker entry")
            dup = True
        else:
            seen_names.add(name)
            entries[name] = pkgver
    if dup:
        continue

    body = "\n".join(cleaned_lines).strip()
    if body:
        bodies.append(body)

config_text = "\n".join(
    [
        "[__config__]",
        f'oldver = "{oldver_path}"',
        f'newver = "{newver_path}"',
        "",
        *bodies,
    ]
).rstrip() + "\n"
combined_path.write_text(config_text, encoding="utf-8")

oldver_path.write_text(
    json.dumps(
        {
            "version": 2,
            "data": {name: {"version": ver} for name, ver in sorted(entries.items())},
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
setup_errors_path.write_text(json.dumps(errors, indent=2) + "\n", encoding="utf-8")
PY

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [[ -n "${NVCHECKER_KEYFILE:-}" && -f "${NVCHECKER_KEYFILE}" ]]; then
  cp "${NVCHECKER_KEYFILE}" "${KEYFILE}"
elif [[ -n "${TOKEN}" ]]; then
  cat >"${KEYFILE}" <<EOF
[keys]
github = "${TOKEN}"
EOF
fi

NV_ARGS=(-c "${COMBINED}" --logger json --json-log-fd 3 --failures)
if [[ -f "${KEYFILE}" ]]; then
  NV_ARGS+=(-k "${KEYFILE}")
fi

set +e
nvchecker "${NV_ARGS[@]}" 3>"${LOG_JSON}"
NV_EXIT=$?
set -e

# 0 = ok, 3 = check failures (still produce a report); anything else is fatal.
if [[ "${NV_EXIT}" -ne 0 && "${NV_EXIT}" -ne 3 ]]; then
  echo "error: nvchecker exited with status ${NV_EXIT}" >&2
  [[ -s "${LOG_JSON}" ]] && cat "${LOG_JSON}" >&2
  exit "${NV_EXIT}"
fi

set +e
nvcmp -c "${COMBINED}" -j -n >"${UPDATES_JSON}"
NCMP_EXIT=$?
set -e

if [[ ! -s "${UPDATES_JSON}" ]]; then
  echo '[]' >"${UPDATES_JSON}"
fi
if [[ "${NCMP_EXIT}" -ne 0 ]]; then
  python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "${UPDATES_JSON}" 2>/dev/null || {
    echo "error: nvcmp failed (exit ${NCMP_EXIT})" >&2
    cat "${UPDATES_JSON}" >&2 || true
    exit "${NCMP_EXIT}"
  }
fi

BODY_TMP="${WORKDIR}/body.txt"
python3 - "${UPDATES_JSON}" "${LOG_JSON}" "${SETUP_ERRORS}" "${REPORT_META}" "${BODY_TMP}" <<'PY'
import json
import sys
from pathlib import Path

updates = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
log_path = Path(sys.argv[2])
setup_errors = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
meta_path = Path(sys.argv[4])
body_path = Path(sys.argv[5])

check_errors: list[str] = []
if log_path.is_file() and log_path.stat().st_size:
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
        check_errors.append(f"{name}: {msg}")

seen: set[str] = set()
errors: list[str] = []
for item in setup_errors + check_errors:
    if item not in seen:
        seen.add(item)
        errors.append(item)

update_lines = []
for item in updates:
    name = item.get("name", "unknown")
    old = item.get("oldver", "?")
    new = item.get("newver", "?")
    update_lines.append(f"- {name}: {old} -> {new}")

has_updates = bool(update_lines)
has_errors = bool(errors)

if not has_updates and not has_errors:
    body = "No AUR packages need to be updated.\n"
    subject = "No AUR packages need updating"
elif has_updates and not has_errors:
    body = "AUR packages with updates available:\n\n" + "\n".join(update_lines) + "\n"
    names = ", ".join(item.get("name", "?") for item in updates)
    subject = f"AUR updates available ({len(update_lines)}): {names}"
elif has_errors and not has_updates:
    body = "nvchecker reported errors:\n\n" + "\n".join(f"- {e}" for e in errors) + "\n"
    subject = f"AUR nvchecker errors ({len(errors)})"
else:
    body = (
        "AUR packages with updates available:\n\n"
        + "\n".join(update_lines)
        + "\n\nnvchecker reported errors:\n\n"
        + "\n".join(f"- {e}" for e in errors)
        + "\n"
    )
    subject = f"AUR updates available ({len(update_lines)}) + errors ({len(errors)})"

if len(subject) > 90:
    subject = subject[:87] + "..."

meta_path.write_text(
    json.dumps(
        {
            "has_updates": has_updates,
            "has_errors": has_errors,
            "subject": subject,
            "update_count": len(update_lines),
            "error_count": len(errors),
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
body_path.write_text(body, encoding="utf-8")
PY

cat "${BODY_TMP}"
if [[ -n "${BODY_FILE}" ]]; then
  cp "${BODY_TMP}" "${BODY_FILE}"
fi

if [[ -n "${GITHUB_OUTPUT_FILE}" ]]; then
  python3 - "${REPORT_META}" "${GITHUB_OUTPUT_FILE}" <<'PY'
import json
import sys
from pathlib import Path

meta = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
out = Path(sys.argv[2])
subject = meta["subject"]

with out.open("a", encoding="utf-8") as fh:
    fh.write(f"has_updates={'true' if meta['has_updates'] else 'false'}\n")
    fh.write(f"has_errors={'true' if meta['has_errors'] else 'false'}\n")
    fh.write(f"update_count={meta['update_count']}\n")
    fh.write(f"error_count={meta['error_count']}\n")
    if "\n" in subject:
        fh.write(f"subject<<EOF\n{subject}\nEOF\n")
    else:
        fh.write(f"subject={subject}\n")
PY
fi
