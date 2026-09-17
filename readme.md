# pi5-runners

A 3D-printable tower for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. Roughly **101 × 103 × 100 mm**, about **1 litre**, four printed parts, cooled
by a single 80 mm Noctua.

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

One filtered 80 mm intake on the GPIO-side wall — the one wall nothing plugs into
once the HATs are fitted, and the one opposite the USB-C inlets. Air crosses all three
boards and leaves through a vent field on the port wall and a second in the roof.

Positive pressure, so dust can only enter where the filter is. That is why there is
exactly one filter.

## Printing

Four parts, none needing support: `base`, `shell`, `roof`, `filter`. PETG. Everything
fits a 256 mm bed with room to spare.

```bash
./scripts/generate-stl.sh --local
```

## Development

```bash
git submodule update --init --recursive   # SBC_Model_Framework
./scripts/test.sh                         # every suite
```

Requires OpenSCAD nightly with the Manifold backend. Every dimension lives in
`cad/config.scad`.

## Licence

[CC BY-NC-SA 4.0](license.md). Vendor CAD under `cad/assets/` is **not** covered by it
— see the readme beside those files. Do not print the fan; buy it.
