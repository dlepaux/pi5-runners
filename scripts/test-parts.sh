#!/bin/bash
# ============================================================================
# Parts — one body each, every one fits the bed, the showcase renders clean
# ============================================================================
# A cylinder tangent to a plane is NOT attached to it: the union renders, the
# preview looks right, and the part exports as a plate plus loose pucks. Counting
# bodies is what catches that, and nothing else in the suite can.
#
# The module and the lid are checked in BOTH fan modes: fan_model sets their length,
# and a mode nobody renders is a mode that quietly stops working.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Parts"

BED=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
      -D 'test_view="report-geometry"' cad/tests.scad 2>&1 \
    | sed -n 's/.*bed = \[\([0-9]*\), \([0-9]*\), \([0-9]*\)\].*/\1 \2 \3/p')
read -r BX BY BZ <<<"$BED"

# check_part <label> <part> [extra openscad args...] -- as it PRINTS
check_part() {
    local label="$1" part="$2"; shift 2
    local out="$WORK/print-$label.stl"
    render print "$out" -D "part=\"$part\"" "$@"
    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    local n; n=$(comps "$out")
    if [ "$n" = "1" ]; then pass "$label is one body"
    else fail "$label — $n bodies, expected 1"; return 1; fi

    read -r X0 Y0 Z0 X1 Y1 Z1 <<<"$(bounds "$out")"
    if awk -v x0="$X0" -v y0="$Y0" -v z0="$Z0" -v x1="$X1" -v y1="$Y1" -v z1="$Z1" \
           -v bx="$BX" -v by="$BY" -v bz="$BZ" \
           'BEGIN { exit !(x1-x0 <= bx && y1-y0 <= by && z1-z0 <= bz) }'; then
        pass "$(awk -v x0="$X0" -v y0="$Y0" -v z0="$Z0" -v x1="$X1" -v y1="$Y1" -v z1="$Z1" -v l="$label" \
                'BEGIN { printf "%s fits the bed (%.1f x %.1f x %.1f)", l, x1-x0, y1-y0, z1-z0 }')"
    else
        fail "$label does not fit a ${BX}x${BY}x${BZ} bed"
    fi
}

check_part module-10 module -D 'fan_model="NF-A4x10"'
check_part module-20 module -D 'fan_model="NF-A4x20"'
check_part lid-10    lid    -D 'fan_model="NF-A4x10"'
check_part lid-20    lid    -D 'fan_model="NF-A4x20"'
check_part filter    filter

# THE SHOWCASE MUST RENDER CLEAN. It is the only file that touches the framework's
# board model and the vendor fan meshes, so it is the only place their path
# assumptions can bite -- and both announce themselves as WARNING, not ERROR.
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

showcase "assembly renders clean"                  -D 'case_part="assembly"'
showcase "assembly renders closed"                 -D 'case_part="assembly"' -D 'assembly_space=0'
showcase "assembly renders with the 20mm fans"     -D 'case_part="assembly"' -D 'fan_model="NF-A4x20"'
showcase "assembly renders with nothing on"        -D 'case_part="assembly"' \
         -D 'show_boards=false' -D 'show_hats=false' -D 'show_standoffs=false' \
         -D 'show_fan=false' -D 'show_filter=false'

report "part checks"
