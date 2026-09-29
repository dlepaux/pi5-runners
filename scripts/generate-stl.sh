#!/bin/bash
# ============================================================================
# Render every printable part
# ============================================================================
#   ./scripts/generate-stl.sh            # everything into stl/
#   ./scripts/generate-stl.sh filter              # just one
#   ./scripts/generate-stl.sh module-NF-A4x20
#
# Each part is rendered from cad/case.scad with case_part set, which is the SAME
# entry point the assembly uses -- so a part cannot drift from how it is shown.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OPENSCAD="${OPENSCAD:-}"
if [ -z "$OPENSCAD" ]; then
    for c in openscad-nightly openscad /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD; do
        if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then OPENSCAD="$c"; break; fi
    done
fi
[ -n "$OPENSCAD" ] || { echo "❌ OpenSCAD not found. Set OPENSCAD=/path/to/openscad"; exit 1; }

BACKEND=""
"$OPENSCAD" --help 2>&1 | grep -q "\-\-backend" && BACKEND="--backend=Manifold"

# fan_model sets the module's and the lid's length, so they are written in
# both. The filter panel is one part whichever fans are fitted.
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(module-NF-A4x10 lid-NF-A4x10 module-NF-A4x20 lid-NF-A4x20 filter)

mkdir -p stl
FAILED=""
for target in "${TARGETS[@]}"; do
    part="${target%%-NF-*}"
    args=(-D "case_part=\"$part\"")
    [ "$part" != "$target" ] && args+=(-D "fan_model=\"${target#"$part"-}\"")
    out="stl/$target.stl"
    printf "  %-16s " "$target"
    # binstl ALWAYS. The ASCII default writes a header that every downstream reader
    # parses as a triangle count in the hundreds of millions.
    # shellcheck disable=SC2086
    if "$OPENSCAD" $BACKEND --export-format=binstl -o "$out" "${args[@]}" cad/case.scad \
           >"$out.log" 2>&1 \
       && ! grep -qE "ERROR:|WARNING:" "$out.log"; then
        printf "%s\n" "$(python3 scripts/lib/stl-stats.py "$out" --bboxes | head -1 \
                          | awk '{printf "%.1f x %.1f x %.1f mm", $1, $2, $3}')"
        rm -f "$out.log"
    else
        echo "FAILED"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        FAILED="$FAILED $target"
    fi
done

echo ""
[ -z "$FAILED" ] && { echo "✅ stl/ written"; exit 0; }
echo "❌ failed:$FAILED"; exit 1
