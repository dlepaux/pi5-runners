# pi5-runners

A 3D-printable tower for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. **131.6 × 66.5 × 99.95 mm**, **0.87 L**, four printed parts, cooled by two
stacked 40 mm Noctuas.

## What it holds

| Slot | Board | Storage | Cooling |
|------|-------|---------|---------|
| Bottom | Pi 5 | Raspberry Pi M.2 HAT+ (2242 NVMe) | Active Cooler |
| Middle | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230 NVMe) | Active Cooler, on custom standoffs |
| Top | Pi 5 | — | Active Cooler |

Plus two **Noctua NF-A4x20 5V PWM**, stacked into a 40 × 80 mm column on the front.

## Why two stacked 40 mm fans

CI runners hold 100% CPU for 30–50 minutes at a stretch, three boards at once — about
40 W of heat. Case air rise over room temperature is `ΔT = Q / (ρ · c_p · V̇)`:

| Fans | Case | Case air rise | Margin to the HAT's 50 °C, 25 °C room |
|------|------|---------------|---------------------------------------|
| 1 × NF-A8 (80 mm) | 1.25 L | ≈ 4.3 K | ≈ 21 K |
| **2 × NF-A4x20, stacked** | **0.87 L** | **≈ 12.7 K** | **≈ 12 K** |
| 2 × NF-A4x10 | ~0.85 L | ≈ 25 K | ≈ 0 — ruled out |

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
sides. Total exhaust is **268% of the fans' throat**.

Around each board's port cluster the vent pattern stops at a rounded **exclusion zone**,
the same idea as hexrack's back face, so every connector sits in clean solid material.

Positive pressure, so dust can only enter where the filter is. That is why there is
exactly one filter.

## Printing

Four parts, none needing support. PETG.

| Part | Size |
|------|------|
| `base` | 131.6 × 66.5 × 17.0 mm |
| `shell` | 131.6 × 66.5 × 90.0 mm |
| `roof` | 131.6 × 66.5 × 22.0 mm |
| `filter` | 48.0 × 88.0 × 5.5 mm |

```bash
./scripts/generate-stl.sh          # all four into stl/
./scripts/generate-stl.sh shell    # just one
```

The vents use **hexrack's triangle lattice**, unchanged, so the two projects read as one
family. A triangle cannot rack, so the field keeps a 3 mm wall stiff at an open-area
fraction that would leave round holes floppy. The intake is
a rounded square on the shell's own corner radius — the fan's throat is its impeller's
swept annulus whatever shape the hole is, so the square costs no airflow.

The filter is a **retainer for bought media**, not the filtration itself. Its grille is
80% of the fans' throat, so the media is the restriction rather than the plastic.

## Development

```bash
git submodule update --init --recursive   # SBC_Model_Framework
./scripts/test.sh                         # all five suites, 61 checks
```

| Suite | Holds |
|-------|-------|
| `test-board-assets.sh` | the declared Pi 5 geometry still matches the framework |
| `test-assets.sh` | the vendor fan mesh is what `config.scad` says it is |
| `test-fit.sh` | nothing collides, everything reaches |
| `test-parts.sh` | one body each, the parts tile the shell, everything fits the bed |
| `test-airflow.sh` | the exhaust does not choke the intake, no port is blind, no hole exists that should not |

Open `cad/case.scad` for the assembly. `case_part` picks one part, `assembly_space`
pulls the case apart along Z, and the `show_*` flags toggle the boards, HATs,
standoffs, fan and filter.

Requires OpenSCAD nightly with the Manifold backend. Every dimension lives in
`cad/config.scad`.

## Licence

[CC BY-NC-SA 4.0](license.md). Vendor CAD under `cad/assets/` is **not** covered by it
— see the readme beside those files. Do not print the fan; buy it.
