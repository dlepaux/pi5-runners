# pi5-runners

A 3D-printable tower for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. **135.9 × 92 × 99.95 mm**, **1.25 L**, four printed parts, cooled by a single
80 mm Noctua.

## What it holds

| Slot | Board | Storage | Cooling |
|------|-------|---------|---------|
| Bottom | Pi 5 | Raspberry Pi M.2 HAT+ (2242 NVMe) | Active Cooler |
| Middle | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230 NVMe) | Active Cooler, on custom standoffs |
| Top | Pi 5 | — | Active Cooler |

Plus one **Noctua NF-A8 5V PWM**, which powers from a USB port inside the case.

## Why one 80 mm fan and not two 40s

CI runners hold 100% CPU for 30–50 minutes at a stretch, three boards at once. That
is about 40 W of heat. Case air rise over room temperature is
`ΔT = Q / (ρ · c_p · V̇)`:

| Fans | Airflow realised | Case air rise |
|------|------------------|---------------|
| 2 × NF-A4x10 5V | ~5.5 m³/h | **≈ 22 K** |
| 1 × NF-A8 5V PWM | ~27.75 m³/h | **≈ 4.3 K** |

The M.2 HAT+ is rated for **0–50 °C ambient**. Two 40 mm fans put a 28 °C room at
exactly 50 °C — the rated ceiling, with no margin left. The NF-A8 puts a 25 °C room
at about 29 °C, and it is quieter doing it.

It also deletes a subsystem. At 80 mm the fan spans the whole board stack, so it
presents a fresh-air front to all three slots at once — no plenum, no internal
ducting, and about 40 mm of case width that never had to exist.

## Airflow

Front to back, along the boards' full length. One filtered 80 mm intake on the front —
the short edge opposite the USB and Ethernet ports — pushes air over the SoCs and the
NVMe drives, and it leaves at the rear where the ports are and where the Ethernet PHY
runs hottest.

The exhaust is the rear wall plus the rear portion of both side walls. Never the top:
a vented lid drops dust straight onto the boards. The rear alone was tried and measured
— once the port clusters are kept clear it reaches only 57% of the fan's throat, and
even venting the entire rear wall reaches 99.7% — so the pattern wraps round onto the
sides. Total exhaust is **147% of the fan's throat**.

Around each board's port cluster the vent pattern stops at a rounded **exclusion zone**,
the same idea as hexrack's back face, so every connector sits in clean solid material.

Positive pressure, so dust can only enter where the filter is. That is why there is
exactly one filter.

## Printing

Four parts, none needing support. PETG.

| Part | Size |
|------|------|
| `base` | 135.9 × 92.0 × 17.0 mm |
| `shell` | 135.9 × 92.0 × 90.0 mm |
| `roof` | 135.9 × 92.0 × 22.0 mm |
| `filter` | 88.0 × 88.0 × 5.5 mm |

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
76% of the fan's throat, so the media is the restriction rather than the plastic.

## Development

```bash
git submodule update --init --recursive   # SBC_Model_Framework
./scripts/test.sh                         # all five suites, 59 checks
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
