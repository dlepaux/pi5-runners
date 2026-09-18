# shellcheck shell=bash
# ============================================================================
# Shared harness for scripts/test-*.sh
# ============================================================================
# hexrack-sbc repeats its OpenSCAD detection, its temp-dir handling and its
# empty-render verdict in all eleven of its test scripts. They have already drifted
# apart there. One copy here.
#
# Source it from a test script:
#
#     . "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"
#     expect_empty "board clears the shell" board-vs-shell
#     report
#
# NOT `set -e`. A test suite that stops at the first failure tells you one thing;
# these are cheap and independent, so every check runs and the report lists all of them.
# ============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

# ----------------------------------------------------------------------------
# OpenSCAD
# ----------------------------------------------------------------------------
OPENSCAD="${OPENSCAD:-}"
if [ -z "$OPENSCAD" ]; then
    for candidate in openscad-nightly openscad \
                     /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD \
                     /Applications/OpenSCAD-2021.01.app/Contents/MacOS/OpenSCAD; do
        if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
            OPENSCAD="$candidate"; break
        fi
    done
fi
if [ -z "$OPENSCAD" ]; then
    echo "❌ OpenSCAD not found. Set OPENSCAD=/path/to/openscad"
    exit 1
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend=Manifold"
fi

# FAN_MODEL=NF-A4x20 runs a suite against the other fan mode: it sets the module's
# length, so the geometry suites have to hold in both. Every render gets it; an
# explicit -D fan_model in a check still wins, because it comes later on the line.
# ${MODE[@]+...}: bash 3.2 calls an empty array unbound under `set -u`.
MODE=()
[ -n "${FAN_MODEL:-}" ] && MODE=(-D "fan_model=\"$FAN_MODEL\"")

# Scratch lives IN THE TREE, not in /tmp. A snap-confined OpenSCAD — which is what
# `apt install openscad-nightly` gives you on the CI runner — cannot see /tmp at all,
# and fails by writing nothing rather than by complaining.
WORK="$ROOT/.test-work.$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
note() { echo "     $1"; }

# ----------------------------------------------------------------------------
# render <view> <outfile> [extra openscad args...]
# ----------------------------------------------------------------------------
# Renders cad/tests.scad with test_view set. Writes the log beside the STL.
# Returns OpenSCAD's exit code; the CALLER decides what that means, because for an
# emptiness check a non-zero exit is the expected result.
render() {
    local view="$1" out="$2"; shift 2
    # binstl always. OpenSCAD's default ASCII export makes the binary triangle-count
    # header that stl-stats.py and tris() read parse as a number in the hundreds of
    # millions — a collision that reads as a pass, or the reverse.
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --export-format=binstl -o "$out" \
        -D "test_view=\"$view\"" ${MODE[@]+"${MODE[@]}"} "$@" cad/tests.scad >"$out.log" 2>&1
}

tris() {
    python3 - "$1" <<'PY'
import struct, sys
try:
    with open(sys.argv[1], "rb") as handle:
        handle.read(80)
        print(struct.unpack("<I", handle.read(4))[0])
except Exception:
    print(-1)
PY
}

vol()    { python3 scripts/lib/stl-stats.py "$1" --volume 2>/dev/null || echo "-1"; }
comps()  { python3 scripts/lib/stl-stats.py "$1" 2>/dev/null | awk '{print $2}'; }
genus()  { python3 scripts/lib/stl-stats.py "$1" --genus 2>/dev/null || echo "-1"; }

bounds() {
    python3 - "$1" <<'PY'
import struct, sys
lo = [float("inf")] * 3
hi = [float("-inf")] * 3
with open(sys.argv[1], "rb") as handle:
    handle.read(80)
    (count,) = struct.unpack("<I", handle.read(4))
    for _ in range(count):
        values = struct.unpack("<12f", handle.read(50)[:48])
        for corner in (3, 6, 9):
            for axis in range(3):
                value = values[corner + axis]
                lo[axis] = min(lo[axis], value)
                hi[axis] = max(hi[axis], value)
if lo[0] == float("inf"):
    print("empty")
else:
    print(" ".join("%.3f" % v for v in lo + hi))
PY
}

# ----------------------------------------------------------------------------
# expect_empty <label> <view> [extra openscad args...]
# ----------------------------------------------------------------------------
# The central assertion: this view must render to nothing.
#
# Three ways nothing can happen and only two of them are a pass:
#   - the CSG genuinely cancelled            -> PASS
#   - OpenSCAD printed "top level object is empty" and exited non-zero -> PASS
#   - the render hit an ERROR and died before producing geometry       -> FAIL
# Checking the exit code alone conflates the last with the first two, which is how a
# broken test file reads as a green suite.
# The mirror of expect_empty: a view that MUST render something, and at least this much
# of it. Emptiness checks alone cannot see a part that is missing, misplaced or detached --
# every one of them passes on nothing at all.
expect_volume() {
    local label="$1" view="$2" floor="$3" hint="${4:-}"
    local out="$WORK/$view.stl"

    render "$view" "$out"

    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi

    local v; v=$(vol "$out")
    if awk -v v="$v" -v f="$floor" 'BEGIN { exit !(v >= f) }'; then
        pass "$(printf '%s (%.0fmm3)' "$label" "$v")"
        return 0
    fi
    fail "$(printf '%s — %.0fmm3, floor %s' "$label" "$v" "$floor")"
    [ -n "$hint" ] && printf '       %s\n' "$hint"
    return 1
}

expect_empty() {
    local label="$1" view="$2"; shift 2
    local out="$WORK/$view.stl"

    render "$view" "$out" "$@"

    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    if grep -q "top level object is empty" "$out.log"; then
        pass "$label"
        return 0
    fi

    local count; count=$(tris "$out")
    if [ "$count" = "0" ]; then
        pass "$label"
        return 0
    fi
    if [ "$count" = "-1" ]; then
        fail "$label — could not read $out"
        tail -3 "$out.log" | sed 's/^/       /'
        return 1
    fi

    # TRIANGLES ARE NOT THE VERDICT. VOLUME IS.
    #
    # Two solids that TOUCH -- the fan's mounting face flat on the tray, the tray's plate
    # against the shell's wall ring, a fan bolted to its panel pad -- intersect in a
    # coplanar sheet. That sheet is a real set of triangles enclosing no space at all, and
    # whether OpenSCAD hands it back or collapses it to nothing is a property of the
    # BUILD, not of the geometry: 2026.01.25 returns empty, 2026.04.26 returns the sheet.
    #
    # This suite ran green on a laptop for weeks and went red the first time CI ever ran,
    # on four checks whose volumes were 0.000 and -0.000mm³ -- one of them named "fan
    # touches only the tray it bolts to", which says out loud that touching is the point.
    #
    # So: zero volume is contact, and contact passes. Anything that encloses space is an
    # interference and still fails. The threshold is far below anything physical -- a
    # 1mm² face overlapping by a single micron is 0.001mm³ -- and far above the 1e-9 that
    # a degenerate sheet accumulates in float. It is also exactly stl-stats.py's own %.3f
    # print resolution, so the rule reads the same way the output does: prints as 0.000,
    # passes. And vol() answers -1 when it cannot read the file, which fails, as it should.
    local volume; volume=$(vol "$out")
    if python3 -c "import sys; sys.exit(0 if abs(float(sys.argv[1])) < 1e-3 else 1)" \
            "$volume" 2>/dev/null; then
        pass "$label (touching, ${count} coplanar triangles, no enclosed volume)"
        return 0
    fi

    fail "$label — $count triangles remain, volume ${volume}mm³"
    python3 scripts/lib/stl-stats.py "$out" --bboxes 2>/dev/null \
        | head -6 | sed 's/^/       offending body (dx dy dz): /'
    return 1
}

# ----------------------------------------------------------------------------
# expect_geometry <label> <view> [extra openscad args...]
# ----------------------------------------------------------------------------
# The other direction, and it matters as much. A hole that happens to coincide with an
# opening in a vent pattern passes a present-check on its own; only checking that
# material REMAINS where it should remain proves the cut landed where it was aimed.
expect_geometry() {
    local label="$1" view="$2"; shift 2
    local out="$WORK/$view.stl"

    render "$view" "$out" "$@"

    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    if grep -q "top level object is empty" "$out.log"; then
        fail "$label — rendered EMPTY, expected geometry"
        return 1
    fi

    local count; count=$(tris "$out")
    if [ "$count" -gt 0 ] 2>/dev/null; then
        pass "$label"
    else
        fail "$label — no geometry produced"
    fi
}

report() {
    echo ""
    if [ "$FAIL" -eq 0 ]; then
        echo "✅ ${1:-checks} passed ($PASS/$PASS)"
        exit 0
    fi
    echo "❌ ${1:-checks} FAILED ($FAIL failed, $PASS passed)"
    exit 1
}
