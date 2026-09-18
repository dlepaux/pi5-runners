# Vendor fan geometry

`NF-A4x10.stl` is derived from Noctua's official public CAD, downloaded from:

- <https://cdn.noctua.at/media/NF-A4x10_Public-CAD.zip>

listed on <https://www.noctua.at/en/support/downloads>. `scripts/generate-fan-asset.sh`
regenerates it; the STEP archive itself lands in `.vendor-cad/`, which is gitignored.

It is every solid in the STEP file — frame, corner pads, impeller, hub, label: 11
bodies, 29k triangles at 0.2 mm deflection — left in Noctua's **native orientation**,
axis along **Y**. `cad/lib/noctua-fan.scad` rotates it into this project's +X
convention at import, which keeps the file byte-identical to what they published. Two
copies are drawn, one per fan.

The whole mesh measures **40.0 × 12.0 × 40.0**, against a datasheet 10 mm depth: the
frame is 11.0 (anti-vibration pads 0.5 proud each side) and the hub label stands 1 mm
beyond that. `fan_depth` uses 12.0. Measure the UNION — the first line of
`stl-stats.py --bboxes` is only the largest body — and never take extents from
`step-to-stl.py --list`, whose un-tessellated box over-estimates curves.

## What it is for

Showing the real build. The bore, the bolt pattern and every boolean are **parametric**
in `cad/lib/noctua-fan.scad` — you cut an opening from `fan_size`, you do not subtract
a fan. `cad/config.scad` declares the mesh's extents in `fan_asset_extent` and
`scripts/test-assets.sh` holds the file and that declaration together.

`fanVisualization80()` marks its import with OpenSCAD's **`%` background modifier**:
drawn in preview, dropped from the final render. That is what keeps Noctua's geometry
out of every STL this project publishes. `#` is the *debug* modifier and is still
included in the export — it does not do this job.

## What it is not for

Noctua's own README, shipped inside the archive:

> These public 3D CAD models accurately represent mounting dimensions as well as the
> overall external dimensions of the product. To protect our intellectual property,
> certain features – such as fan impeller geometries – have been slightly modified
> while remaining visually very close to the actual product.
>
> Accordingly, these models are well suited for integrating our products into your own
> CAD designs, as well as for creating renderings, animations, and other visual
> outputs. However, please do not use these models for performance simulations and
> note that components, such as fan impellers and internal frame structures, are not
> fully representative of the actual product.

So: mounting dimensions and outer envelope are trustworthy, which is exactly what this
case needs from it. The impeller is not. **The airflow figures in this project come
from the NF-A4x10 datasheet, never from this mesh.**

## Licence

Noctua's terms, from the same README and <https://www.noctua.at/en/3d-cad-models>:

> The CAD models are provided solely for reference, visualisation, and integration
> purposes and may not be used, in whole or in part, for the manufacture,
> reproduction, or commercialisation of the products they represent or any
> substantially similar products.

Integrating a case around the fan is integration. This file is **not** covered by this
project's CC-BY-NC-SA licence, is not a printable part, and is never included in the
STLs the website publishes. Do not print it; buy the fan.
