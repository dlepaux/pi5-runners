#!/bin/bash
# ============================================================================
# Regenerate cad/assets/noctua/NF-A4x20.stl from Noctua's published STEP
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

URL="https://cdn.noctua.at/media/NF-A4x20_Public-CAD.zip"
VENDOR=".vendor-cad"
OUT="cad/assets/noctua/NF-A4x20.stl"

# DEFLECTION is the max distance the tessellation may stray from the true surface, in
# mm. This mesh is a showcase prop, never a boolean, so it is tuned for file size
# rather than fidelity. 0.2 gives the 40mm fan ~58k triangles and 2.9MB.
DEFLECTION="${DEFLECTION:-0.2}"

command -v uv >/dev/null 2>&1 || { echo "❌ uv not found — https://docs.astral.sh/uv/"; exit 1; }

mkdir -p "$VENDOR" cad/assets/noctua

echo "→ downloading $URL"
curl -fsSL --max-time 180 -o "$VENDOR/NF-A4x20.zip" "$URL" || {
    echo "❌ download failed. Noctua move these; check"
    echo "   https://www.noctua.at/en/support/downloads for the current link"
    exit 1
}

echo "→ unpacking"
unzip -oq "$VENDOR/NF-A4x20.zip" -d "$VENDOR/NF-A4x20"

STEP=$(find "$VENDOR/NF-A4x20" -iname '*.stp' -o -iname '*.step' | head -1)
[ -n "$STEP" ] || { echo "❌ no STEP file inside the archive"; exit 1; }

echo "→ tessellating at ${DEFLECTION}mm (OpenCASCADE via uv, first run downloads ~500MB)"
uv run --quiet --with cadquery-ocp \
    python scripts/lib/step-to-stl.py "$STEP" "$OUT" --deflection "$DEFLECTION"

echo "→ measuring the MESH, not the BRep"
# DO NOT take the extents from step-to-stl.py --list. OpenCASCADE's bounding box over
# an un-tessellated shape is a conservative over-estimate on curved faces: it reports
# the NF-A8's frame as 88.38mm across. The mesh is the ground truth.
#
# And the WHOLE mesh, not --bboxes' first line, which is only the largest body: for
# this fan that is the frame at 20.1 deep, while the hub label takes the mesh to 21.1.
python3 - "$OUT" <<'PY'
import struct, sys
lo = [1e9] * 3; hi = [-1e9] * 3
with open(sys.argv[1], "rb") as f:
    f.read(80); (n,) = struct.unpack("<I", f.read(4))
    for _ in range(n):
        v = struct.unpack("<12f", f.read(50)[:48])
        for c in (3, 6, 9):
            for a in range(3):
                lo[a] = min(lo[a], v[c + a]); hi[a] = max(hi[a], v[c + a])
print("   fan_asset_extent = [%.1f, %.1f, %.1f];  // native X, Y, Z"
      % tuple(hi[a] - lo[a] for a in range(3)))
PY

echo "✓ $OUT"
echo "  Update fan_asset_extent in cad/config.scad if the line above differs,"
echo "  then run ./scripts/test-assets.sh"
