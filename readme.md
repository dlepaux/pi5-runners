# pi5-runners

A 3D-printable tower for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. **127.5 × 68.5 × 99.95 mm**, **0.87 L**, seven printed parts that clip together
without a single screw, cooled by two stacked 40 mm Noctuas.

## What it holds

| Slot | Board | Storage | Cooling |
|------|-------|---------|---------|
| Bottom | Pi 5 | Raspberry Pi M.2 HAT+ (2242 NVMe) | Active Cooler |
| Middle | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230 NVMe) | Active Cooler, on custom standoffs |
| Top | Pi 5 | — | Active Cooler |

Plus two **Noctua NF-A4x10 5V**, stacked into a 40 × 80 mm column on the front and
powered from a Pi's GPIO 5 V header. The three boards stack on M2.5 male-female
standoffs into one tower, screwed into heat-set inserts in the base.

## Why two stacked 40 mm fans

CI runners hold 100% CPU for 30–50 minutes at a stretch, three boards at once — about
40 W of heat. Case air rise over room temperature is `ΔT = Q / (ρ · c_p · V̇)`:

| Fans | Case | Case air rise | Margin to the HAT's 50 °C, 25 °C room |
|------|------|---------------|---------------------------------------|
| 1 × NF-A8 (80 mm) | 1.25 L | ≈ 4.3 K | ≈ 21 K |
| 2 × NF-A4x20, stacked | 0.87 L | ≈ 12.7 K | ≈ 12 K |
| **2 × NF-A4x10, stacked** | **0.87 L** | **≈ 14.6 K** | **≈ 10 K** |

The fans sit on the front wall, so that wall must be as wide as the fan. An 80 mm fan
made the case 92 mm wide around a 56 mm board. A 40 × 80 column is just as tall — it
still faces all three boards — but narrow enough that the boards set the width again.
The trade is cooling margin for a third less volume, chosen with the numbers above.

## Airflow

Front to back, along the boards' full length. One filtered intake on the front — two 40 mm fans in a column, on
the short edge opposite the USB and Ethernet ports — pushes air over the SoCs and the
NVMe drives, and it leaves at the rear where the ports are and where the Ethernet PHY
runs hottest.

The exhaust is the rear wall plus the rear portion of both side walls. Never the top:
a vented lid drops dust straight onto the boards. The rear alone was tried and measured
— once the port clusters are kept clear it reaches only 57% of the fan's throat, and
even venting the entire rear wall reaches 99.7% — so the pattern wraps round onto the
sides. Total exhaust is **206% of the fans' throat**.

Around each board's port cluster the vent pattern stops at a rounded **exclusion zone**,
the same idea as hexrack's back face, so every connector sits in clean solid material.

Positive pressure, so dust can only enter where the filter is. That is why there is
exactly one filter.

## Printing

Seven parts, no supports. PETG.

| Part | Size | Printed |
|------|------|---------|
| `base` | 127.5 × 68.5 × 13.0 mm | flat, underside down |
| `front` | 17.0 × 68.5 × 94.0 mm | on its outer face |
| `rear` | 13.0 × 68.5 × 94.0 mm | on its outer face |
| `left` | 117.5 × 3.0 × 94.0 mm | flat |
| `right` | 117.5 × 3.0 × 94.0 mm | flat |
| `roof` | 127.5 × 68.5 × 9.0 mm | upside down |
| `filter` | 52.0 × 90.0 × 4.0 mm | flat, glue pocket up |

```bash
./scripts/generate-stl.sh          # all seven into stl/
./scripts/generate-stl.sh front    # just one
```

**One bridge to know about.** Printed on its outer face, the front wall's filter recess
is open to the bed, so the recess floor 4 mm up bridges the web between the two fan
bores — about 52 mm at its longest. Turn bridging on. Any sag lands under the filter
ring, not on a visible face.

The base has **no printed feet** — feet below the floor would leave the whole floor
printing over air. Stick four rubber bumpons on its flat underside.

**Assembly.** Screw the tower to the base's inserts. Drop the front and rear walls onto
the base's rim; slide the two side walls down between their corner flanges; press the
roof on. Every joint is hexrack's 45° clip — a diamond rib into a matching groove — so
nothing is screwed and nothing is glued except the filter media. Glue a piece of filter
fabric into the pocket on the back of the filter ring and push the ring into the front
recess until it clicks.

The vents use **hexrack's triangle lattice**, unchanged, so the two projects read as one
family. A triangle cannot rack, so the field keeps a 3 mm wall stiff at an open-area
fraction that would leave round holes floppy.

The filter is **hexrack's too**: a flush ring holding bought media. Behind it each fan
has its own round bore, entirely inside the ring's opening, so only the fabric is in
the airstream — and the wall between the bores keeps solid plastic round every fan
screw.

## Development

```bash
git submodule update --init --recursive   # SBC_Model_Framework
./scripts/test.sh                         # all six suites, 115 checks
```

| Suite | Holds |
|-------|-------|
| `test-board-assets.sh` | the declared Pi 5 geometry still matches the framework |
| `test-assets.sh` | the vendor fan mesh is what `config.scad` says it is |
| `test-fit.sh` | nothing collides, the rails reach the bottom board, every insert pocket sits wholly in a rail |
| `test-parts.sh` | one body each, the six panels tile the shell without overlap, nothing touches the boards, everything fits the bed |
| `test-clips.sh` | every clip rib sits in its groove at rest and reaches into the part it holds |
| `test-airflow.sh` | the exhaust does not choke the intake, no port is blind, no hole exists that should not, the filter ring clears both bores, the fan screws bite wall |

Open `cad/case.scad` for the assembly. `case_part` picks one part, `assembly_space`
pulls each part straight out from its face (the board tower stays put), and the `show_*` flags toggle the boards, HATs,
standoffs, fan and filter.

Requires OpenSCAD nightly with the Manifold backend. Every dimension lives in
`cad/config.scad`.

## Licence

[CC BY-NC-SA 4.0](license.md). Vendor CAD under `cad/assets/` is **not** covered by it
— see the readme beside those files. Do not print the fan; buy it.
