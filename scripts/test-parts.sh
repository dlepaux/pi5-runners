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

one_body() {
    local label="$1" view="$2"
    local out="$WORK/$view.stl"
    render "$view" "$out"
    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    local n; n=$(comps "$out")
    if [ "$n" = "1" ]; then pass "$label (1 body)"
    else fail "$label — $n bodies, expected 1"
         python3 scripts/lib/stl-stats.py "$out" --bboxes 2>/dev/null \
            | head -4 | sed 's/^/       body (dx dy dz): /'
    fi
}

one_body "base is one body"  part-base
one_body "shell is one body" part-shell
one_body "roof is one body"  part-roof

# THE PARTS MUST NOT OVERLAP EACH OTHER. Three panels cut from one solid by three
# claims is only correct if the claims are disjoint; overlapping claims render fine,
# export fine, count one body each, and print two parts that cannot both be in the
# case at once.
expect_empty "base does not overlap the shell" part-base-vs-shell
expect_empty "roof does not overlap the shell" part-roof-vs-shell
expect_empty "base does not overlap the roof"  part-base-vs-roof

# ...and together they must ACCOUNT FOR the whole shell. Disjoint claims that leave a
# gap also pass every check above. This is the other direction, and it is the one that
# catches a band of the case that no part owns.
expect_empty "the three parts tile the whole shell" shell-minus-parts

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
         -D 'show_fan=false'

report "part checks"
