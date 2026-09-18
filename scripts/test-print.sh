#!/bin/bash
# ============================================================================
# Printability — every part prints without support, as it comes out of case.scad
# ============================================================================
# The whole design is shaped by how it prints: modules floor-down, the lid plate-
# down, the front face standing, the filter face-down. This suite holds that true.
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

# LID and FILTER: nothing at all. Upside down the lid's lap narrows as it rises; the
# filter is a flat ring with its ribs' 45-degree faces on its edges.
budget lid    lid    0 0
budget filter filter 0 0

# MODULE: steep -- only the 1.2mm corner radii at the tops of the lattice triangles
# and the rounded ends of the -Y connector openings, each under 2mm across (~194).
# Flat -- the tops of the port openings and of the down-pointing triangles, and the
# land's 1.2mm underside where the wall steps out over the spigot's lap (~890).
budget module module 250 930

# FRONT FACE: the arched tops of the two 38mm fan bores through the 3mm plate, and
# of the pill recess, 4mm deep. Arches in a vertical face: they print as bridges that
# shorten toward the crown. The bores are behind the filter; the recess crown is the
# one arch over a mating face, and it has filter_clear to sag into. ~350mm2.
# Flat -- only the fan pilot holes' crowns and the dovetail channels' tops (~32).
budget front-10 front 400 45 -D 'fan_model="NF-A4x10"'
budget front-20 front 400 45 -D 'fan_model="NF-A4x20"'

report "printability checks"
