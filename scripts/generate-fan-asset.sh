#!/bin/bash
# ============================================================================
# Regenerate cad/assets/noctua/NF-A8.stl from Noctua's published STEP
# ============================================================================
# Networked, and needs OpenCASCADE — a ~500MB install that nothing else in this
# project requires. The OUTPUT IS COMMITTED, so you only run this when the vendor
# publishes a new model or the deflection needs changing. Building and testing the
# case needs neither the network nor OCP.
#
#   ./scripts/generate-fan-asset.sh
#
# The STEP archive lands in .vendor-cad/, which is gitignored: Noctua's licence
# covers redistribution and the archive is theirs. The derived preview mesh is
# committed under their integration/visualisation permission — see the readme beside
# it, and do not print it.
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

URL="https://cdn.noctua.at/media/NF-A8_Public-CAD.zip"
VENDOR=".vendor-cad"
OUT="cad/assets/noctua/NF-A8.stl"

# DEFLECTION is the max distance the tessellation may stray from the true surface, in
# mm. This mesh is a showcase prop, never a boolean, so it is tuned for file size
# rather than fidelity: 0.3 gives 113k triangles and 5.6MB, in line with hexrack's own
# noctua-92.stl. 0.05 gives 141k and 7MB for detail nothing looks at.
DEFLECTION="${DEFLECTION:-0.3}"

command -v uv >/dev/null 2>&1 || { echo "❌ uv not found — https://docs.astral.sh/uv/"; exit 1; }

mkdir -p "$VENDOR" cad/assets/noctua

echo "→ downloading $URL"
curl -fsSL --max-time 180 -o "$VENDOR/NF-A8.zip" "$URL" || {
    echo "❌ download failed. Noctua move these; check"
    echo "   https://www.noctua.at/en/support/downloads for the current link"
    exit 1
}

echo "→ unpacking"
unzip -oq "$VENDOR/NF-A8.zip" -d "$VENDOR/NF-A8"

STEP=$(find "$VENDOR/NF-A8" -iname '*.stp' -o -iname '*.step' | head -1)
[ -n "$STEP" ] || { echo "❌ no STEP file inside the archive"; exit 1; }

echo "→ tessellating at ${DEFLECTION}mm (OpenCASCADE via uv, first run downloads ~500MB)"
uv run --quiet --with cadquery-ocp \
    python scripts/lib/step-to-stl.py "$STEP" "$OUT" --deflection "$DEFLECTION"

echo "→ measuring the MESH, not the BRep"
# DO NOT take the extents from step-to-stl.py --list. OpenCASCADE's bounding box over
# an un-tessellated shape is a conservative over-estimate on curved faces: it reports
# this 80mm fan's frame as 88.38mm across. The mesh is the ground truth, and it is
# what config.scad's fan_asset_extent must agree with.
python3 scripts/lib/stl-stats.py "$OUT" --bboxes | head -1 \
    | awk '{printf "   fan_asset_extent = [%s, %s, %s];  // native X, Y, Z\n", $1, $2, $3}'

echo "✓ $OUT"
echo "  Update fan_asset_extent in cad/config.scad if the line above differs,"
echo "  then run ./scripts/test-assets.sh"
