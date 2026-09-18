#!/bin/bash
# ============================================================================
# Parts — one body each, and the set tiles the shell
# ============================================================================
# A cylinder tangent to a plane is NOT attached to it: a boss centred exactly half a
# boss off the panel it stands on meets it along a LINE, zero contact area. The union
# renders, the preview looks right, and the part exports as a plate plus loose pucks.
# Counting bodies is what catches that, and nothing else in the suite can.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Parts"

PARTS=(base front rear left right roof filter)
SHELL_PARTS=(base front rear left right roof)

one_body() {
    local name="$1"
    local out="$WORK/part-$name.stl"
    render part "$out" -D "part=\"$name\""
    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$name — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    local n; n=$(comps "$out")
    if [ "$n" = "1" ]; then pass "$name is one body"
    else fail "$name — $n bodies, expected 1"
         python3 scripts/lib/stl-stats.py "$out" --bboxes 2>/dev/null \
            | head -4 | sed 's/^/       body (dx dy dz): /'
    fi
}

for p in "${PARTS[@]}"; do one_body "$p"; done

# THE SIX SHELL PANELS MUST TILE THE CUT SHELL -- both directions, because neither
# implies the other.
#
# COMPLETE: nothing of the cut shell is left unclaimed. A gap between two claims prints
# a case with a slot missing and passes every other check here.
expect_empty "the six panels cover the whole shell" shell-minus-parts

# DISJOINT: fifteen pairs, one comparison. Overlapping panels always sum to MORE than
# the shell they were cut from, so the panels' volumes must add up to the shell's.
render shell-cut "$WORK/shell-cut.stl"
SHELL_V=$(vol "$WORK/shell-cut.stl")
SUM=0
for p in "${SHELL_PARTS[@]}"; do
    render panel "$WORK/panel-$p.stl" -D "part=\"$p\""
    SUM=$(awk -v a="$SUM" -v b="$(vol "$WORK/panel-$p.stl")" 'BEGIN { print a + b }')
done
if awk -v a="$SUM" -v s="$SHELL_V" 'BEGIN { exit !(s > 0 && a - s < 1 && s - a < 1) }'; then
    pass "$(printf 'the six panels do not overlap (sum %.0f = shell %.0f mm3)' "$SUM" "$SHELL_V")"
else
    fail "$(printf 'panels sum to %.0fmm3 but the shell is %.0f — claims overlap' "$SUM" "$SHELL_V")"
fi

# NOTHING PRINTED TOUCHES THE BOARD TOWER. Rims, flanges, rails and ribs all stand
# inside the case, which is where the boards are.
expect_empty "no part reaches into the board stack" parts-vs-stack

# EVERY PART MUST FIT THE BED. Cheap to check and expensive to discover: a part that
# is 4mm too tall is found at slicing time, after the design has settled around it.
BED=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
      -D 'test_view="report-geometry"' cad/tests.scad 2>&1 \
    | sed -n 's/.*bed = \[\([0-9]*\), \([0-9]*\), \([0-9]*\)\].*/\1 \2 \3/p')
read -r BX BY BZ <<<"$BED"
for p in "${PARTS[@]}"; do
    out="$WORK/part-$p.stl"
    [ -f "$out" ] || render part "$out" -D "part=\"$p\""
    read -r DX DY DZ _ <<<"$(python3 scripts/lib/stl-stats.py "$out" --bboxes | head -1)"
    if awk -v dx="$DX" -v dy="$DY" -v dz="$DZ" -v bx="$BX" -v by="$BY" -v bz="$BZ" \
           'BEGIN { exit !(dx <= bx && dy <= by && dz <= bz) }'; then
        pass "$(printf '%s fits the bed (%.1f x %.1f x %.1f)' "$p" "$DX" "$DY" "$DZ")"
    else
        fail "$(printf '%s is %.1f x %.1f x %.1f, bed is %s x %s x %s' \
                "$p" "$DX" "$DY" "$DZ" "$BX" "$BY" "$BZ")"
    fi
done

# THE SHOWCASE MUST RENDER CLEAN. It is the only file that touches the framework's
# board model and the vendor fan mesh, so it is the only place their path assumptions
# can bite -- and both announce themselves as WARNING rather than ERROR, which is
# silent unless something looks. The framework asks for its heatsink DXF as
# "./lib/heatsinks/..." and import() resolves that against the MAIN document; see
# cad/lib/readme-heatsinks.md.
showcase() {
    local label="$1"; shift
    local out="$WORK/showcase.stl"
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --export-format=binstl -o "$out" "$@" cad/case.scad \
        >"$out.log" 2>&1
    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    local n; n=$(tris "$out")
    if [ "$n" -gt 0 ] 2>/dev/null; then pass "$label ($n triangles)"
    else fail "$label — no geometry"; fi
}

showcase "assembly renders clean"            -D 'case_part="assembly"'
showcase "assembly explodes clean"           -D 'case_part="assembly"' -D 'assembly_space=30'
showcase "assembly renders with nothing on"  -D 'case_part="assembly"' \
         -D 'show_boards=false' -D 'show_hats=false' -D 'show_standoffs=false' \
         -D 'show_fan=false' -D 'show_filter=false'

report "part checks"
