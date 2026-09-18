#!/bin/bash
# ============================================================================
# Clips — every rib sits in its groove, and every rib is actually engaged
# ============================================================================
# Every clipped joint is one row of allJoints() in cad/tests.scad, built from the same
# tables the parts use: spigotJoints() for module-to-module and lid-to-module,
# filterJoints() for the filter. hexrack's own dust clip taught why this needs
# measuring: its groove was once anchored to a different datum than its rib, 9mm
# off, and both parts still exported clean. The joint had simply stopped existing.
#
# Two checks per joint, because each alone passes on a broken joint:
#   rib-vs-mate  EMPTY  -- at rest the rib touches nothing of the part it clips into.
#                A missing or misplaced groove shows up as the rib buried in wall.
#   rib-reach    VOLUME -- the rib reaches into the mating part's territory. A rib that
#                stops short of its groove is also "not touching anything".
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Clips"

# Not mapfile: macOS ships bash 3.2 as /bin/bash, and mapfile arrived in bash 4.
JOINTS=()
while IFS= read -r line; do JOINTS+=("$line"); done < <(
    "$OPENSCAD" $BACKEND --export-format=binstl -o /dev/null \
        -D 'test_view="report-clips"' cad/tests.scad 2>&1 \
      | sed -n 's/.*"CLIP \([0-9]*\) \([^ ]*\) \([^ ]*\) \([^"]*\)".*/\1 \2 \3 \4/p')

if [ "${#JOINTS[@]}" -eq 0 ]; then
    fail "could not read the joint table from cad/tests.scad"
    report "clip checks"
fi
note "${#JOINTS[@]} joints"

for row in "${JOINTS[@]}"; do
    read -r k name owner mate <<<"$row"

    expect_empty "$name: rib clears the $mate at rest" clip-rib-vs-mate -D "clip_k=$k"

    render clip-rib       "$WORK/rib-$k.stl"   -D "clip_k=$k"
    render clip-rib-reach "$WORK/reach-$k.stl" -D "clip_k=$k"
    RIB=$(vol "$WORK/rib-$k.stl")
    REACH=$(vol "$WORK/reach-$k.stl")
    # A rib centred on its joint plane puts half its volume past it; a quarter is a
    # generous floor that still fails a rib that misses its mate altogether.
    if awk -v r="$REACH" -v t="$RIB" 'BEGIN { exit !(t > 0 && r >= 0.25 * t) }'; then
        pass "$(printf '%s: rib engages the %s (%.0f%% of it)' "$name" "$mate" \
                "$(awk -v r="$REACH" -v t="$RIB" 'BEGIN{print r/t*100}')")"
    else
        fail "$(printf '%s: rib does not reach the %s (%.1fmm3 of %.1f)' "$name" "$mate" "$REACH" "$RIB")"
    fi
done

report "clip checks"
