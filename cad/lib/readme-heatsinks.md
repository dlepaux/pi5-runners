# Why `cad/lib/heatsinks` is a symlink

`SBC_Model_Framework/lib/heatsink.scad` draws the Pi 5 Active Cooler's base plate with

    import("./lib/heatsinks/rpi5_oem.dxf")

and **`import()` resolves against the MAIN document, not against the file that wrote
it**. The DXF really lives at `SBC_Model_Framework/lib/heatsinks/rpi5_oem.dxf`, so any
consumer whose main document is elsewhere gets

    WARNING: Can't open DXF file '.../SBC_Model_Framework/lib/./lib/heatsinks/rpi5_oem.dxf'

The cooler still renders — the fin block and fan are cubes — but its base plate
silhouette is missing, and a `WARNING:` is exactly what this project's test harness
treats as a failure, because an undef constant announces itself the same way.

`cad/lib/heatsinks -> ../SBC_Model_Framework/lib/heatsinks` puts the DXF where
`import()` looks when the main document is in `cad/`, which covers `case.scad` and
`tests.scad`. Nothing under `cad/parts/` calls `sbc()`, so nothing needs it there.

A symlink rather than a copy: a copy of a submodule file drifts silently the first
time the submodule is updated.
