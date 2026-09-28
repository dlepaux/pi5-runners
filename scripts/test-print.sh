#!/bin/bash
# ============================================================================
# Printability — every part prints without support, as it comes out of case.scad
# ============================================================================
# The whole design is shaped by how it prints: modules floor-down, the lid plate-
# down, the filter panel face-down. This suite holds that true.
#
# A face pointing down more steeply than 45 degrees needs support. Each part has a
# BUDGET for them, and every budget is accounted for below. A new feature that adds
# a real overhang -- a ledge, a square-ended rail, a flat ceiling turned the wrong
# way -- blows its part's budget and fails here, with the box it lives in.
#
# Flat downward faces are bridges -- and LEDGES. The metric cannot tell a 10mm bridge
# over a port from a square-ended rail printed over air, so flat area has a budget too,
# a few percent over what the accounted-for bridges measure. A new ledge blows it; a
# deliberate new bridge means raising the budget on purpose, with its reason here.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Printability"

# budget <label> <part> <max steep mm2> <max flat mm2> [extra openscad args...]
budget() {
    local label="$1" part="$2" max="$3" maxflat="$4"; shift 4
    local out="$WORK/print-$label.stl"
    render print "$out" -D "part=\"$part\"" "$@"
    local report steep flat
    report=$(python3 scripts/lib/stl-stats.py "$out" --overhang)
    read -r steep flat <<<"$(echo "$report" | head -1)"
    if awk -v s="$steep" -v m="$max" 'BEGIN { exit !(s <= m) }'; then
        pass "$(printf '%s: %.0fmm2 steeper than 45 (budget %s)' "$label" "$steep" "$max")"
    else
        fail "$(printf '%s: %.0fmm2 steeper than 45, over its %s budget' "$label" "$steep" "$max")"
        echo "$report" | tail -n +2 | sed 's/^/       /'
    fi
    if awk -v f="$flat" -v m="$maxflat" 'BEGIN { exit !(f <= m) }'; then
        pass "$(printf '%s: %.0fmm2 of bridges (budget %s)' "$label" "$flat" "$maxflat")"
    else
        fail "$(printf '%s: %.0fmm2 printed flat over air, over its %s budget — a new ledge?' "$label" "$flat" "$maxflat")"
    fi
}

# LID and DUST FILTER: nothing at all. Upside down the lid's lap narrows as it rises;
# the filter is a flat ring with its ribs' 45-degree faces on its edges.
budget lid-10 lid    0 0 -D 'fan_model="NF-A4x10"'
budget lid-20 lid    0 0 -D 'fan_model="NF-A4x20"'
budget filter filter 0 0

# BASE: nothing at all. Rim on the bed, the skirt vertical, the socket's bevel and
# grooves facing inward and up as on a module's top.
budget base-10 base 0 0 -D 'fan_model="NF-A4x10"'
budget base-20 base 0 0 -D 'fan_model="NF-A4x20"'

# MODULE, measured by where it is (both fans measure the same):
#   steep ~152 -- the fan bore's crown in the 3mm web and the countersinks' upper
#                 halves (~114); what is left of the filter recess's arcs between its
#                 top flat and its sides (~22); the side port openings' rounded ends
#                 (~9), the exclusion zone's rounded corners (~7). The wall vents add
#                 nothing: every edge is 45.
#   flat ~536  -- the filter recess's TOP FLAT, a 32mm bridge 4mm deep off the web
#                 behind it (~130): the price of the fan, not the filter, setting the
#                 module's height, and the round crown it replaced was ~160 of steep.
#                 The tops of the port openings, rear (~130) and side (~59); the
#                 louvres' flat tops, 3mm bridges, six a side and ten at the rear
#                 (~140); the socket's clip grooves. NOTHING ON THE LAP: its chamfer runs to
#                 the outer face -- the first print's stopped 1.3mm short and left a
#                 roof (~371) that sagged.
budget module-10 module 170 560 -D 'fan_model="NF-A4x10"'
budget module-20 module 170 560 -D 'fan_model="NF-A4x20"'

report "printability checks"
