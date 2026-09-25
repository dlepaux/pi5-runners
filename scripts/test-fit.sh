#!/bin/bash
# ============================================================================
# Fit — nothing collides, everything reaches
# ============================================================================
# OpenSCAD has no notion of a collision. Two parts never render together, so every
# interference is invisible until a boolean is rendered.
#
# Emptiness checks alone cannot see a part that is missing, misplaced or renamed:
# every one of them passes on nothing at all. Each clearance check is paired with
# something that must be THERE.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Fit — HAT clearances"

expect_geometry "standard HAT+ outline renders"          hat-standard-outline
expect_geometry "Compact HAT+ outline renders"           hat-compact-outline
expect_geometry "standard HAT+ solid renders"            hat-standard-solid
expect_geometry "Compact HAT+ solid renders"             hat-compact-solid
expect_empty    "Active Cooler clears the standard HAT+" cooler-vs-hat-standard
expect_empty    "Active Cooler clears the Compact HAT+"  cooler-vs-hat-compact

echo ""
echo "Fit — each board in the module"

# Every module is the same part, so every kind of board must fit it -- and must clear
# the floor of the module, or the lid, that stacks on top of it.
for k in standard compact bare; do
    expect_geometry "$k board's envelope renders"                 slot-solid     -D "kind=\"$k\""
    expect_empty    "$k board clears its module"                  slot-vs-module -D "kind=\"$k\""
    expect_empty    "$k board clears the module or lid above it"  slot-vs-above  -D "kind=\"$k\""
done

echo ""
echo "Fit — rails and inserts"

expect_geometry "rails render"                              canoes-alone
expect_empty    "rails do not pierce the board"             canoes-vs-board
expect_empty    "insert pockets are open in the module"     pockets-vs-module
expect_geometry "insert pockets sit in the rails"           pockets-in-rails
expect_empty    "insert pockets lie wholly in rail and floor" pockets-outside-rails

# ...and the rails must REACH the standoffs, which reach the board. Both clearance
# checks above pass on a rail 5mm too short.
render canoes-alone "$WORK/canoes.stl"
RAIL_TOP=$(bounds "$WORK/canoes.stl" | awk '{print $6}')
WANT_TOP=$("$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
    -D 'test_view="report-geometry"' cad/tests.scad 2>&1 \
  | sed -n 's/.*rail_top = \([0-9.]*\).*/\1/p')
if awk -v a="$RAIL_TOP" -v b="$WANT_TOP" 'BEGIN { exit !(a - b < 0.01 && b - a < 0.01) }'; then
    pass "rail tops meet the standoffs at z=$RAIL_TOP"
else
    fail "rail tops at z=$RAIL_TOP but the standoffs start at z=$WANT_TOP"
fi
expect_empty    "board standoffs clear the module"          standoffs-vs-module
expect_geometry "board standoffs stand on the rails"        standoffs-seated

echo ""
echo "Fit — the stack"

expect_empty    "a module clears the module above it"  module-vs-above
expect_empty    "the top module clears the lid"        module-vs-lid
# Both pass on a module floating 5mm up. Lowered 0.2mm, it must bite.
expect_geometry "a module sits on the one below"       module-seated
expect_geometry "the lid sits on the top module"       lid-seated
# Both pass on the front butt joint alone. Behind it, the lap must bear too.
expect_geometry "a module's lap bears on the one below" module-seated-on-lap
expect_geometry "the lid's lap bears on the top module" lid-seated-on-lap
expect_empty    "the bottom module and its filter clear the base" module-vs-base
expect_geometry "the bottom module sits on the base"     base-seated
expect_geometry "its lap bears on the base's socket"     base-seated-on-lap

echo ""
echo "Fit — the dust filters"

expect_empty    "a filter sits in its recess, touching nothing"  filter-vs-module
expect_geometry "a filter sits on its recess floor"             filter-seated

echo ""
echo "Fit — fans"

expect_geometry "fans render"                             fans-alone
expect_empty    "every fan clears every printed part"     fans-vs-case
expect_empty    "the fan clears every kind of board"      fan-vs-boards
expect_geometry "the fan sits on its front wall"          fans-seated

report "fit checks"
