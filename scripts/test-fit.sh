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

echo ""
echo "Fit — the stack"

expect_geometry "slot 0 occupies its slab"              slot0-solid
expect_geometry "slot 1 occupies its slab"              slot1-solid
expect_geometry "slot 2 occupies its slab"              slot2-solid

expect_empty    "slot 0 clears slot 1's board"          slot0-vs-slot1
expect_empty    "slot 1 clears slot 2's board"          slot1-vs-slot2
expect_empty    "slot 2 clears the roof"                slot2-vs-roof
expect_empty    "the whole stack sits inside the shell"  stack-vs-shell

report "fit checks"
