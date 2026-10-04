#!/bin/bash
# ============================================================================
# Airflow and ports
# ============================================================================
# Each module's own fan draws through its dust filter and pushes along the board,
# out through the module's rear wall and the rear of both its side walls. If a
# module's exhaust is smaller than its fan's throat, that module is choked and nothing
# about the geometry says so.
#
# Areas are MEASURED from the exact profiles the walls are cut with, never computed:
# the rear cutter has an exclusion zone carved out of it.
#
# Every check is paired with its opposite. A port cut that swallowed a wall passes
# "no port is blind"; a cut that landed nowhere passes "the wall still exists".
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

read -r THROAT MODULES <<<"$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
          -D 'test_view="report-areas"' ${MODE[@]+"${MODE[@]}"} cad/tests.scad 2>&1 \
        | sed -n 's/.*fan_throat_area = \([0-9.]*\) module_count = \([0-9]*\).*/\1 \2/p')"

pct() { awk -v a="$1" -v t="$THROAT" 'BEGIN { printf "%.0f", a / t * 100 }'; }

echo "Airflow"

render rear-vent-area  "$WORK/rear.stl"
render side-vent-area  "$WORK/side.stl"
render side-vent-throat "$WORK/side-throat.stl"
render floor-vent-area "$WORK/floor.stl"
REAR=$(vol "$WORK/rear.stl"); SIDE=$(vol "$WORK/side.stl"); FLOOR=$(vol "$WORK/floor.stl")
# The louvres' throat, not their face: that is what the air passes.
SIDE_THROAT=$(vol "$WORK/side-throat.stl")

PER=$(awk -v r="$REAR" -v s="$SIDE_THROAT" 'BEGIN { print r + 2 * s }')
note "$(printf 'per module: rear %.0f + 2 x side louvres %.0f (face %.0f); floor %.0f between modules' "$REAR" "$SIDE_THROAT" "$SIDE" "$FLOOR")"
if awk -v a="$PER" -v t="$THROAT" 'BEGIN { exit !(a >= t) }'; then
    pass "$(printf 'each module exhausts %.0fmm2 >= its fan throat %.0fmm2 (%s%%)' "$PER" "$THROAT" "$(pct "$PER")")"
else
    fail "$(printf 'each module exhausts %.0fmm2 and CHOKES its %.0fmm2 fan (%s%%)' "$PER" "$THROAT" "$(pct "$PER")")"
fi
# The floor lattice is an option (floor_vents), off by default: off, the floor is solid
# and the cutter renders nothing; on, it must be a real lattice. The forced-on render
# keeps the option from rotting while it is off.
render floor-vent-area "$WORK/floor-on.stl" -D floor_vents=true
FLOOR_ON=$(vol "$WORK/floor-on.stl")
if awk -v f="$FLOOR" 'BEGIN { exit !(f <= 0 || f > 1000) }'; then
    pass "$(printf 'the floor is solid or properly vented (%.0fmm2)' "$FLOOR")"
else
    fail "$(printf 'the floor lattice is only %.0fmm2' "$FLOOR")"
fi
if awk -v f="$FLOOR_ON" 'BEGIN { exit !(f > 1000) }'; then
    pass "$(printf 'floor_vents=true still cuts a lattice (%.0fmm2)' "$FLOOR_ON")"
else
    fail "$(printf 'floor_vents=true cuts only %.0fmm2' "$FLOOR_ON")"
fi

expect_geometry "the side field cuts the -Y wall" side-y-neg-rear-removed

# NO HOLES THAT SHOULD NOT EXIST. Every port check asks whether a port is blocked;
# none would notice an extra hole -- which is how three notches once sat in a side
# wall through a whole redesign. Behind the -Y connectors both side walls carry the
# same field and grooves, mirrored, and nothing else: they must lose the same material,
# and the +Y one at least its field times the wall.
render side-y-pos-rear-removed "$WORK/ypos.stl"
render side-y-neg-rear-removed "$WORK/yneg.stl"
YPOS=$(vol "$WORK/ypos.stl"); YNEG=$(vol "$WORK/yneg.stl")
FIELD=$(awk -v s="$SIDE" 'BEGIN { print s * 3 }')
if awk -v a="$YPOS" -v e="$FIELD" 'BEGIN { exit !(a >= e * 0.99) }'; then
    pass "$(printf '+Y side field cuts clean through (%.0fmm3 >= %.0f)' "$YPOS" "$FIELD")"
else
    fail "$(printf '+Y side lost %.0fmm3, less than its field x wall %.0f' "$YPOS" "$FIELD")"
fi
if awk -v a="$YNEG" -v e="$YPOS" 'BEGIN { exit !(a > e * 0.99 && a < e * 1.01) }'; then
    pass "$(printf 'no spurious holes: -Y loses %.0fmm3, same as +Y' "$YNEG")"
else
    fail "$(printf -- '-Y loses %.0fmm3 but +Y loses %.0f — extra holes in the -Y wall' "$YNEG" "$YPOS")"
fi

expect_empty "the exclusion zone keeps triangles off the ports" exclusion-holds

echo ""
echo "Ports"
# The probe is the mask's silhouette extruded from the board edge past the case, so
# its length owes nothing to the sweep that cut the wall.
expect_empty    "no port is blind"         ports-blind
expect_geometry "the -Y wall still exists" wall-y-remains
expect_geometry "the +X wall still exists" wall-x-remains

echo ""
echo "Intake"
expect_empty "every fan's air path is open, filter to fan"  bores-open

echo ""
echo "Fan screws"
# In from outside, hexrack's way: countersunk into the recess floor, under the ring.
expect_empty "every screw head lies under the filter ring"   screw-heads-outside-ring
expect_empty "every screw's thread passes its hole freely"   screw-paths
# Noctua's self-tapping fan screws, not the M3 the first prints were drawn for: every
# one cut its own thread through a 3.4mm hole, wedged its head into a cone too small
# for it, and cracked the web toward the bore.
expect_empty    "every screw head sinks under the recess floor" screw-heads-sunk
expect_geometry "and has a cone to bear on"                     screw-heads-bear
# A MILLIMETRE OF WALL ROUND EVERY COUNTERSINK. The corner holes sit 3.6mm outside the
# bore, so this is what notices a countersink breaking into it -- or the web round it
# thinning to a sliver that cracks.
render screw-seat-annuli "$WORK/seat-rings.stl"
render screw-seats       "$WORK/seats.stl"
RING=$(vol "$WORK/seat-rings.stl"); SEAT=$(vol "$WORK/seats.stl")
if awk -v m="$SEAT" -v a="$RING" 'BEGIN { exit !(a > 0 && m >= 0.97 * a) }'; then
    pass "$(printf 'every countersink has a millimetre of wall round it (%.0f%% solid)' \
            "$(awk -v m="$SEAT" -v a="$RING" 'BEGIN{print m/a*100}')")"
else
    fail "$(printf 'only %.1fmm3 of %.1f round the countersinks is wall — one breaks into the bore?' "$SEAT" "$RING")"
fi

report "airflow and port checks"
