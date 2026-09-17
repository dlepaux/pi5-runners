#!/bin/bash
# ============================================================================
# Mesh assets — the file on disk is what config.scad says it is
# ============================================================================
# hexrack's pattern: prepare the asset offline, declare what was generated, and
# assert the consumer against it. An asset whose declared extent has drifted from the
# file mis-places every feature derived from it, and nothing else in the suite can
# see that — the parts still render, still export, still count one body.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Mesh assets"

MESH="cad/assets/noctua/NF-A8.stl"

if [ ! -f "$MESH" ]; then
    fail "NF-A8 mesh missing — run ./scripts/generate-fan-asset.sh"
    report "asset checks"
fi
pass "NF-A8 mesh present"

# NOT a one-body check. A fan is legitimately many solids — frame, eight corner pads,
# impeller, hub — and demanding one body here would be asserting a wrong belief about
# the part rather than a property worth holding.
N=$(comps "$MESH")
if [ "$N" -ge 1 ] 2>/dev/null; then
    pass "NF-A8 mesh has geometry ($N bodies)"
else
    fail "NF-A8 mesh has no bodies"
fi

# Extents, measured off the MESH. step-to-stl.py --list cannot answer this: OpenCASCADE's
# bounding box over an un-tessellated shape over-estimates curved faces badly enough to
# call this 80mm fan 88.38mm across. A measurement tool that cannot see something must
# not be trusted to answer.
read -r EX EY EZ _ <<<"$(python3 scripts/lib/stl-stats.py "$MESH" --bboxes | head -1)"

DECL=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
        -D 'test_view="report-fan-asset"' cad/tests.scad 2>&1 \
      | sed -n 's/.*declared = \([0-9.]*\) \([0-9.]*\) \([0-9.]*\) tol \([0-9.]*\).*/\1 \2 \3 \4/p')
read -r DX DY DZ TOL <<<"$DECL"

if [ -z "$TOL" ]; then
    fail "could not read fan_asset_extent from cad/tests.scad"
else
    for pair in "X $EX $DX" "Y $EY $DY" "Z $EZ $DZ"; do
        read -r axis measured declared <<<"$pair"
        if awk -v m="$measured" -v d="$declared" -v t="$TOL" \
               'BEGIN { exit !((m - d < t) && (d - m < t)) }'; then
            pass "$(printf 'mesh %s = %s, declared %s' "$axis" "$measured" "$declared")"
        else
            fail "$(printf 'mesh %s = %s but config declares %s (tol %s)' \
                    "$axis" "$measured" "$declared" "$TOL")"
            note "regenerate with ./scripts/generate-fan-asset.sh, or fix fan_asset_extent"
        fi
    done
fi

# The mesh must actually render through OpenSCAD's importer, not merely exist. A file
# OpenSCAD cannot read fails here rather than silently contributing nothing to a showcase.
expect_geometry "fan mesh imports and renders" fan-mesh-raw

# And the visualization module must contribute NOTHING to an export: % is the
# background modifier. If someone swaps it for #, this is what notices — otherwise
# Noctua's geometry ships inside every STL the website publishes.
#
# Volume, not emptiness, and BOUNDED ON BOTH SIDES. The view renders a 10mm marker
# beside the fan, so the assertion reads "the marker and nothing else":
#   - a floor catches the marker going missing, which is what a broken view looks like
#   - a ceiling catches the fan mesh leaking into the export
# An emptiness check here would pass when the mesh is simply missing, which is how the
# first version of this reported a green % while the import was silently failing.
render fan-visualization-export "$WORK/viz.stl"
VIZ=$(vol "$WORK/viz.stl")
if awk -v v="$VIZ" 'BEGIN { exit !(v > 999 && v < 1001) }'; then
    pass "$(printf 'render is the %.0fmm3 marker alone — %% excludes the mesh' "$VIZ")"
else
    fail "$(printf 'render is %.0fmm3, expected the 1000mm3 marker alone' "$VIZ")"
    note "below 1000: the view is broken. above: fanVisualization80() uses # not %"
fi

report "asset checks"
