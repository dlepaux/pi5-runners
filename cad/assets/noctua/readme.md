# Vendor fan geometry

`NF-A4x10.stl` and `NF-A4x20.stl` are derived from Noctua's official public CAD:

- <https://cdn.noctua.at/media/NF-A4x10_Public-CAD.zip>
- <https://cdn.noctua.at/media/NF-A4x20_Public-CAD.zip>

listed on <https://www.noctua.at/en/support/downloads>. `scripts/generate-fan-asset.sh
[model]` regenerates either; the STEP archives land in `.vendor-cad/`, which is
gitignored. `fan_model` in `cad/config.scad` picks which one the case is built for.

Each is every solid in its STEP file — frame, corner pads, impeller, hub, label — at
0.2 mm deflection, left in Noctua's **native orientation**, axis along **Y**.
`cad/lib/noctua-fan.scad` rotates it into this project's +X convention at import,
which keeps the files byte-identical to what was generated. One copy is drawn per
module.

| Mesh | Bodies | Measures | Datasheet depth | Why deeper |
|------|--------|----------|-----------------|------------|
| NF-A4x10 | 11 | 40.0 × 12.0 × 40.0 | 10 | frame 11.0 (pads 0.5 proud each side), hub label 1 mm beyond |
| NF-A4x20 | 12 | 40.0 × 21.1 × 40.0 | 20 | frame 20.1, hub label 1 mm beyond |

`fan_depth` uses the measured depth. Measure the UNION — the first line of
`stl-stats.py --bboxes` is only the largest body — and never take extents from
`step-to-stl.py --list`, whose un-tessellated box over-estimates curves.

## What it is for

Showing the real build. The bore, the bolt pattern and every boolean are **parametric**
in `cad/lib/noctua-fan.scad` — you cut an opening from `fan_size`, you do not subtract
a fan. `cad/config.scad` declares the mesh's extents in `fan_asset_extent` and
`scripts/test-assets.sh` holds each file and its declaration together.

`fanVisualization()` marks its import with OpenSCAD's **`%` background modifier**:
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
from Noctua's datasheets, never from these meshes.**

## Licence

Noctua's terms, from the same README and <https://www.noctua.at/en/3d-cad-models>:

> The CAD models are provided solely for reference, visualisation, and integration
> purposes and may not be used, in whole or in part, for the manufacture,
> reproduction, or commercialisation of the products they represent or any
> substantially similar products.

Integrating a case around the fans is integration. These files are **not** covered by
this project's CC-BY-NC-SA licence, are not printable parts, and are never included in
the STLs this project publishes. Do not print them; buy the fans.
