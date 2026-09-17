#!/bin/bash
# ============================================================================
# Fit — nothing collides, everything reaches
# ============================================================================
# OpenSCAD has no notion of a collision. Two parts never render together, so every
# interference in a project like this is invisible until a boolean is rendered.
#
# Note the mix of expect_empty and expect_geometry. Emptiness checks alone cannot see
# a part that is missing, misplaced or renamed: every one of them passes on nothing
# at all. Each clearance check is paired with something that must be THERE.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Fit — HAT clearances"

expect_geometry "standard HAT+ outline renders"         hat-standard-outline
expect_geometry "Compact HAT+ outline renders"          hat-compact-outline
expect_geometry "standard HAT+ solid renders"           hat-standard-solid
expect_geometry "Compact HAT+ solid renders"            hat-compact-solid

expect_empty    "Active Cooler clears the standard HAT+" cooler-vs-hat-standard
expect_empty    "Active Cooler clears the Compact HAT+"  cooler-vs-hat-compact

report "fit checks"
