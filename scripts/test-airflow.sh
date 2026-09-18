#!/bin/bash
# ============================================================================
# Airflow and ports
# ============================================================================
# Front-to-back through-flow: one filtered intake for the two stacked 40mm fans on the -X front wall, out
# through the rear wall and the rear portion of both side walls. If that total open
# area is smaller than the fan's throat, the case is choked and nothing about the
# geometry says so.
#
# The rear alone CANNOT carry this fan. Measured: with the three port clusters' zones
# carved out it reaches 57% of the throat, and even venting the whole rear wall with
# no zones at all reaches 99.7%. That measurement is why the exhaust wraps the sides.
#
# Areas are MEASURED from the exact profiles the walls are cut with, never computed.
# The rear cutter has exclusion zones carved out of it, and a closed-form area would
# have to re-derive every one of them.
#
# Every check is paired with its opposite. A port cut that swallowed a whole wall
# passes "no port is blind" perfectly; a cut that landed nowhere passes "the wall
# still exists" perfectly. Neither implies the other.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

THROAT=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
          -D 'test_view="report-areas"' cad/tests.scad 2>&1 \
        | sed -n 's/.*fan_throat_area = \([0-9.]*\).*/\1/p')

pct() { awk -v a="$1" -v t="$THROAT" 'BEGIN { printf "%.0f", a / t * 100 }'; }

echo "Airflow"

render rear-vent-area "$WORK/rear.stl"
render side-vent-area "$WORK/side.stl"
REAR=$(vol "$WORK/rear.stl")
SIDE=$(vol "$WORK/side.stl")
TOTAL=$(awk -v r="$REAR" -v s="$SIDE" 'BEGIN { print r + 2 * s }')

note "$(printf 'rear %.0f + 2 x side %.0f = %.0fmm2' "$REAR" "$SIDE" "$TOTAL")"
if awk -v a="$TOTAL" -v t="$THROAT" 'BEGIN { exit !(a >= t) }'; then
    pass "$(printf 'exhaust %.0fmm2 >= fan throat %.0fmm2 (%s%%)' "$TOTAL" "$THROAT" "$(pct "$TOTAL")")"
else
    fail "$(printf 'exhaust %.0fmm2 CHOKES the %.0fmm2 throat (%s%%)' "$TOTAL" "$THROAT" "$(pct "$TOTAL")")"
    note "raise vent_side_depth -- config.scad asserts how far it can go before the ports"
fi

# The side fields must actually CUT both walls. Measured as material removed, not as a
# field that renders: a sweep started at the wrong face runs into open air, removes
# nothing, and passes every emptiness check in this suite.
expect_geometry "-Y side field cuts the wall" side-y-neg-removed

# THE OTHER QUESTION: are there holes that should NOT exist? Every port check asks
# whether a port is blocked. None of them would notice an extra hole -- which is how
# three notches sat in the -Y wall's rear corner through a whole redesign until a
# render showed them. In the rear region both side walls carry the same field and the
# same clip grooves, mirrored, and nothing else, so they must lose identical material.
# The +Y side must also lose at least its field's area through the wall: that is the
# witness that the comparison is not two empty regions agreeing.
render side-y-pos-rear-removed "$WORK/yposrear.stl"
render side-y-neg-rear-removed "$WORK/ynegrear.stl"
YPOS=$(vol "$WORK/yposrear.stl")
YNEG=$(vol "$WORK/ynegrear.stl")
FIELD=$(awk -v s="$SIDE" 'BEGIN { print s * 3 }')
if awk -v a="$YPOS" -v e="$FIELD" 'BEGIN { exit !(a >= e * 0.99) }'; then
    pass "$(printf '+Y side field cuts clean through (%.0fmm3 >= field x wall %.0f)' "$YPOS" "$FIELD")"
else
    fail "$(printf '+Y rear lost %.0fmm3, less than its field x wall %.0f' "$YPOS" "$FIELD")"
fi
if awk -v a="$YNEG" -v e="$YPOS" 'BEGIN { exit !(a > e * 0.99 && a < e * 1.01) }'; then
    pass "$(printf 'no spurious holes: -Y rear loses %.0fmm3, same as +Y' "$YNEG")"
else
    fail "$(printf '-Y rear loses %.0fmm3 but +Y loses %.0f — extra holes in the -Y wall' "$YNEG" "$YPOS")"
    note "a port mask is being dragged into a wall it does not belong to"
fi

# The exclusion zones must keep the pattern OFF the port clusters. A zone that missed
# its cluster leaves a triangle clipped beside a connector -- exactly the untidiness
# the zones exist to remove.
expect_empty "exclusion zones keep triangles off the ports" exclusion-holds

echo ""
echo "Ports"

# No connector may be walled in. The probe is the mask's silhouette extruded from the
# board edge past the case, so its length owes nothing to the sweep that cut the wall.
expect_empty    "no port is blind"                 ports-blind
expect_geometry "the -Y wall still exists"         wall-y-remains
expect_geometry "the +X wall still exists"         wall-x-remains

echo ""
echo "Intake and filter"

expect_geometry "filter renders"                        part -D 'part="filter"'
expect_empty    "filter sits in its recess, touching nothing" filter-vs-front
# The ring is not allowed in the airstream: only its fabric is. Each round bore must
# lie inside the ring's opening.
expect_empty    "both fan bores lie inside the filter's opening" bores-outside-ring

# THE FANS NEED SOMETHING TO SCREW INTO. A ring of wall round each pilot hole must be
# solid -- the check that was missing while every screw hole sat over empty air.
render pilot-annuli   "$WORK/annuli.stl"
render pilot-material "$WORK/pilot.stl"
ANN=$(vol "$WORK/annuli.stl")
MAT=$(vol "$WORK/pilot.stl")
if awk -v m="$MAT" -v a="$ANN" 'BEGIN { exit !(a > 0 && m >= 0.9 * a) }'; then
    pass "$(printf 'fan screws bite solid wall (%.0f%% of the pilot rings)' \
            "$(awk -v m="$MAT" -v a="$ANN" 'BEGIN{print m/a*100}')")"
else
    fail "$(printf 'only %.1fmm3 of %.1f round the fan pilots is wall' "$MAT" "$ANN")"
fi

report "airflow and port checks"
