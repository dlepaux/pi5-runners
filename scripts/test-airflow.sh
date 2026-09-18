#!/bin/bash
# ============================================================================
# Airflow and ports
# ============================================================================
# Two fans push filtered air into the plenum; each module draws from it through its
# open front and exhausts through its rear wall and the rear of both side walls. If
# the exhaust is smaller than the fans' throat, the case is choked and nothing about
# the geometry says so.
#
# Areas are MEASURED from the exact profiles the walls are cut with, never computed:
# the rear cutter has an exclusion zone carved out of it.
#
# Every check is paired with its opposite. A port cut that swallowed a wall passes
# "no port is blind"; a cut that landed nowhere passes "the wall still exists".
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

read -r THROAT MODULES <<<"$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
          -D 'test_view="report-areas"' cad/tests.scad 2>&1 \
        | sed -n 's/.*fan_throat_area = \([0-9.]*\) module_count = \([0-9]*\).*/\1 \2/p')"

pct() { awk -v a="$1" -v t="$THROAT" 'BEGIN { printf "%.0f", a / t * 100 }'; }

echo "Airflow"

render rear-vent-area  "$WORK/rear.stl"
render side-vent-area  "$WORK/side.stl"
render floor-vent-area "$WORK/floor.stl"
REAR=$(vol "$WORK/rear.stl"); SIDE=$(vol "$WORK/side.stl"); FLOOR=$(vol "$WORK/floor.stl")
TOTAL=$(awk -v n="$MODULES" -v r="$REAR" -v s="$SIDE" 'BEGIN { print n * (r + 2 * s) }')

note "$(printf 'per module: rear %.0f + 2 x side %.0f; floor %.0f between modules' "$REAR" "$SIDE" "$FLOOR")"
if awk -v a="$TOTAL" -v t="$THROAT" 'BEGIN { exit !(a >= t) }'; then
    pass "$(printf 'exhaust %.0fmm2 >= fans throat %.0fmm2 (%s%%)' "$TOTAL" "$THROAT" "$(pct "$TOTAL")")"
else
    fail "$(printf 'exhaust %.0fmm2 CHOKES the %.0fmm2 throat (%s%%)' "$TOTAL" "$THROAT" "$(pct "$TOTAL")")"
fi
# The floor lattice is what lets a module breathe into the one above. It must exist.
if awk -v f="$FLOOR" 'BEGIN { exit !(f > 1000) }'; then
    pass "$(printf 'every floor is vented (%.0fmm2)' "$FLOOR")"
else
    fail "$(printf 'the floor lattice is %.0fmm2' "$FLOOR")"
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
echo "Intake and filter"
expect_empty    "filter sits in its recess, touching nothing"      filter-vs-front
expect_empty    "both fan bores lie inside the filter's opening"   bores-outside-pill

# THE FANS NEED SOMETHING TO SCREW INTO.
render pilot-annuli   "$WORK/annuli.stl"
render pilot-material "$WORK/pilot.stl"
ANN=$(vol "$WORK/annuli.stl"); MAT=$(vol "$WORK/pilot.stl")
if awk -v m="$MAT" -v a="$ANN" 'BEGIN { exit !(a > 0 && m >= 0.9 * a) }'; then
    pass "$(printf 'fan screws bite solid plate (%.0f%% of the pilot rings)' \
            "$(awk -v m="$MAT" -v a="$ANN" 'BEGIN{print m/a*100}')")"
else
    fail "$(printf 'only %.1fmm3 of %.1f round the fan pilots is plate' "$MAT" "$ANN")"
fi

report "airflow and port checks"
