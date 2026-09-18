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
expect_geometry "fan column renders"                     fans-alone
expect_empty    "fan column clears every slot"           fans-vs-stack
expect_empty    "fan column clears every printed part"   fans-vs-case

echo ""
echo "Fit — the base rails and their inserts"

expect_geometry "base rails render"                      canoes-alone
expect_empty    "rails do not pierce the bottom board"   canoes-vs-board
# An insert pocket must be void in the finished base AND sit inside a rail: a pocket
# beside the rail in open air is "void in the base" too.
expect_empty    "insert pockets are open in the base"    pockets-vs-base
expect_geometry "insert pockets sit inside the rails"    pockets-in-rails
expect_empty    "insert pockets lie wholly in the rails" pockets-outside-rails

# ...and the rails must actually REACH the board. Both clearance checks above are
# satisfied by a rail 5mm too short: it renders, and it certainly pierces nothing.
render canoes-alone "$WORK/canoes.stl"
RAIL_TOP=$(bounds "$WORK/canoes.stl" | awk '{print $6}')
BOARD_UNDER=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
    -D 'test_view="report-geometry"' cad/tests.scad 2>&1 \
  | sed -n 's/.*board0_underside = \([0-9.]*\).*/\1/p')
if awk -v a="$RAIL_TOP" -v b="$BOARD_UNDER" 'BEGIN { exit !(a - b < 0.01 && b - a < 0.01) }'; then
    pass "rail tops meet board 0's underside at z=$RAIL_TOP"
else
    fail "rail tops at z=$RAIL_TOP but board 0 sits at z=$BOARD_UNDER"
fi

report "fit checks"
