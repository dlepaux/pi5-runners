#!/bin/bash
# ============================================================================
# Airflow and ports
# ============================================================================
# Positive pressure: one filtered 80mm intake, and the only way out is the two
# exhaust fields. If their open area is smaller than the fan's throat, the case is
# choked and nothing about the geometry says so.
#
# Every check here is paired with its opposite. A port cut that swallowed an entire
# wall passes "no port is blind" perfectly; a cut that landed nowhere passes "the wall
# still exists" perfectly. Neither implies the other.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Airflow"

areas=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
        -D 'test_view="report-areas"' cad/tests.scad 2>&1)
num() { printf '%s' "$areas" | sed -n "s/.*$1 = \([0-9.]*\).*/\1/p" | head -1; }

THROAT=$(num fan_throat_area)
COMPUTED=$(num exhaust_open_area)

# The DRAWN area, not the computed one. ventOpenArea() is the analytic ideal; what the
# wall actually gets is offset(r, $fn=24), whose corner arcs are 24-gons and enclose
# very slightly less. The budget is held against the geometry that exists.
render vent-field-area "$WORK/vy.stl"
render vent-roof-area  "$WORK/vr.stl"
DRAWN=$(python3 -c "print(float('$(vol "$WORK/vy.stl")') + float('$(vol "$WORK/vr.stl")'))")

# ...and the two must agree, or ventOpenArea() has stopped describing ventField() and
# every assert built on it is measuring a pattern nobody draws.
if awk -v c="$COMPUTED" -v d="$DRAWN" \
       'BEGIN { exit !(c > 0 && (c - d) / d < 0.005 && (d - c) / d < 0.005) }'; then
    pass "$(printf 'computed area %.0f matches drawn %.0f (within 0.5%%)' "$COMPUTED" "$DRAWN")"
else
    fail "$(printf 'computed area %.0f but drawn %.0f' "$COMPUTED" "$DRAWN")"
    note "ventOpenArea() no longer describes what ventField() draws"
fi

if awk -v a="$DRAWN" -v t="$THROAT" 'BEGIN { exit !(a >= t) }'; then
    pass "$(printf 'exhaust %.0fmm2 >= fan throat %.0fmm2 (x%.2f)' \
            "$DRAWN" "$THROAT" "$(awk -v a="$DRAWN" -v t="$THROAT" 'BEGIN{print a/t}')")"
else
    fail "$(printf 'exhaust %.0fmm2 CHOKES the %.0fmm2 throat' "$DRAWN" "$THROAT")"
    note "widen vent_y_* or vent_roof_*; both feed the same budget"
fi

# THE FILTER MUST NOT BE THE RESTRICTION. It sits in series with the intake, so a
# grille tighter than the fan's throat moves the bottleneck from something measured to
# something nobody looks at. The printed part is a RETAINER for bought media -- the
# media is the real pressure drop -- so the floor is "not dominant", not "as open as
# the fan", which no printable web reaches.
FILT=$(num filter_open_area)
render filter-grille-area "$WORK/fg.stl"
FDRAWN=$(vol "$WORK/fg.stl")

if awk -v c="$FILT" -v d="$FDRAWN" \
       'BEGIN { exit !(c > 0 && (c - d) / d < 0.005 && (d - c) / d < 0.005) }'; then
    pass "$(printf 'filter computed %.0f matches drawn %.0f' "$FILT" "$FDRAWN")"
else
    fail "$(printf 'filter computed %.0f but drawn %.0f' "$FILT" "$FDRAWN")"
    note "filterOpenArea() and the grille disagree — check the cell/web passed to ventField()"
fi

FLOOR=$(awk -v t="$THROAT" 'BEGIN{print t*0.6}')
if awk -v a="$FDRAWN" -v f="$FLOOR" 'BEGIN { exit !(a >= f) }'; then
    pass "$(printf 'filter %.0fmm2 is %.0f%% of throat (floor 60%%)' \
            "$FDRAWN" "$(awk -v a="$FDRAWN" -v t="$THROAT" 'BEGIN{print a/t*100}')")"
else
    fail "$(printf 'filter %.0fmm2 is only %.0f%% of throat' \
            "$FDRAWN" "$(awk -v a="$FDRAWN" -v t="$THROAT" 'BEGIN{print a/t*100}')")"
    note "raise filter_cell or lower filter_web/filter_frame"
fi

echo ""
echo "Ports"

# No connector may be walled in. This is the check the framework mask's own reach
# fails: as published it is swept ~7-10mm and this wall's outer face is 11mm out, so
# subtracting it unmodified leaves 2mm of solid PETG over every USB-C and HDMI.
expect_empty    "no port is blind"                 ports-blind

# Both walls must still be walls.
expect_geometry "the -Y wall still exists"         wall-y-remains
expect_geometry "the +X wall still exists"         wall-x-remains

echo ""
echo "Filter"
expect_geometry "filter renders"                   part-filter
expect_empty    "filter lip enters the opening"    filter-vs-shell

report "airflow and port checks"
