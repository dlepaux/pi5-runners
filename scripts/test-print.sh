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

# MODULE, measured by where it is (NF-A4x10):
#   steep ~474 -- the 1.2mm corner radii at the tops of the side and rear lattice
#                 triangles and the port openings' rounded ends (~360); the fan bore's
#                 crown in the 3mm web and the countersinks' upper halves (~114)
#   flat ~1457 -- the land's 1.3mm underside on the three lapped sides (~375), the tops
#                 of the port openings and the down-pointing triangles (~1008), and the
#                 hexagonal recess's top flat, a 4mm-deep bridge (~74). The 20mm-fan
#                 module is longer, so its side fields are too: ~1480.
budget module-10 module 500 1520 -D 'fan_model="NF-A4x10"'
budget module-20 module 500 1520 -D 'fan_model="NF-A4x20"'

report "printability checks"
