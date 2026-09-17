#!/bin/bash
# ============================================================================
# Board constants vs SBC_Model_Framework
# ============================================================================
# Ties config.scad's declared Pi 5 constants back to the framework's own rpi5
# entry. Without this the submodule can be updated under us and every fit test in
# the suite stays green while describing a board that no longer exists.
# ============================================================================
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Board constants vs SBC_Model_Framework"

CFG="cad/SBC_Model_Framework/sbc_models.cfg"

if [ ! -f "$CFG" ]; then
    echo "❌ $CFG missing — run: git submodule update --init --recursive"
    exit 1
fi

# The rpi5 block runs from its own entry to the start of the next manufacturer's.
# Grepping the whole file would happily match another board's identical constant.
RPI5=$(awk '/^ *\["rpi5",\[/{f=1} f{print} f&&/"heatsink","rpi5_oem"/{exit}' "$CFG")

check() {
    local label="$1" pattern="$2"
    if printf '%s' "$RPI5" | grep -qE "$pattern"; then pass "$label"
    else fail "$label — no match for: $pattern"; fi
}

check "rpi5 PCB is 85 x 56 x 1.65"        '"pcb","rectangle".*\[85,56,1\.65\]'
check "mounting hole left_rear  @ 3.5, 3.5"    '0,3\.5,3\.5,0,.*left_rear'
check "mounting hole left_front @ 3.5, 52.5"   '0,3\.5,52\.5,0,.*left_front'
check "mounting hole right_rear @ 61.5, 3.5"   '0,61\.5,3\.5,0,.*right_rear'
check "mounting hole right_front @ 61.5, 52.5" '0,61\.5,52\.5,0,.*right_front'
check "rpi5_oem Active Cooler present"         '"heatsink","rpi5_oem"'

# 58 x 49 is the hole PATTERN this project derives every stacked board from. It is
# not written in the cfg as a pair -- it is the span between the hole positions
# above -- so assert the arithmetic rather than trusting the four checks to imply it.
if [ "$(python3 -c 'print(61.5-3.5, 52.5-3.5)')" = "58.0 49.0" ]; then
    pass "hole pattern spans 58 x 49"
else
    fail "hole pattern does not span 58 x 49"
fi

# The envelope view must render, and at the declared size. Emptiness checks alone
# cannot see a view that is missing: every one of them passes on nothing at all.
expect_volume "pi5 envelope renders" pi5-envelope 7800 "85 x 56 x 1.65 = 7854mm3"

# A VOLUME FLOOR IS NOT A SIZE CHECK. It only catches an error large enough to move
# the volume past the floor, and it cannot see a board that is wrong in two axes at
# once — 85x56 and 95x50 differ by 4% of volume and by 10mm of case. Assert the
# actual extents, which is what the case is built around.
render pi5-envelope "$WORK/pi5-bbox.stl"
BB=$(bounds "$WORK/pi5-bbox.stl")
if [ "$BB" = "0.000 0.000 0.000 85.000 56.000 1.650" ]; then
    pass "pi5 envelope measures 85 x 56 x 1.65"
else
    fail "pi5 envelope bbox is [$BB], expected [0.000 0.000 0.000 85.000 56.000 1.650]"
    note "config.scad's pi5_pcb disagrees with the framework's rpi5 entry"
fi

report "board asset checks"
