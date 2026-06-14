#!/usr/bin/bash
# Apply Socreate OS branding to extracted Anaconda source tree.
set -euo pipefail

SRCDIR="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$SCRIPT_DIR/anaconda-profile-socreate.conf"

if [[ -z "$SRCDIR" || ! -d "$SRCDIR" ]]; then
    echo "Usage: $0 /path/to/BUILD/anaconda-VERSION" >&2
    exit 1
fi

MARKER="$SRCDIR/.socreate-branding-applied"
if [[ -f "$MARKER" ]] && cmp -s "$CONF" "$SRCDIR/data/profile.d/socreate.conf" 2>/dev/null \
    && grep -q 'Socreate OS Installer' "$SRCDIR/pyanaconda/core/constants.py" 2>/dev/null; then
    exit 0
fi
rm -f "$MARKER"

install -m 0644 "$CONF" "$SRCDIR/data/profile.d/socreate.conf"

python3 - "$SRCDIR" <<'PY'
import sys
from pathlib import Path
srcdir = sys.argv[1]
makefile = Path(srcdir) / "data/profile.d/Makefile.am"
lines = makefile.read_text().splitlines()
if not any(line.strip() == "socreate.conf" for line in lines):
    out = []
    for line in lines:
        if line == "\tvirtuozzo-linux.conf":
            out.append("\tvirtuozzo-linux.conf \\")
            out.append("\tsocreate.conf")
        else:
            out.append(line)
    makefile.write_text("\n".join(out) + "\n")
PY

sed -i 's/WINDOW_TITLE_TEXT = N_("Anaconda Installer")/WINDOW_TITLE_TEXT = N_("Socreate OS Installer")/' \
    "$SRCDIR/pyanaconda/core/constants.py"

date -Is > "$MARKER"
