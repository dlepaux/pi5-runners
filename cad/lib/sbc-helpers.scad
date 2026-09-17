// ============================================================================
// SBC HELPERS — the framework's own board data and IO masks
// ============================================================================
// Port cutouts are NOT a table of coordinates typed into this project. The framework
// carries every connector's position and can emit the mask itself; hexrack consumes
// it the same way. Retyping them would be a second source of truth for the one part
// of this case that is unforgiving about being wrong by a millimetre.
//
// include, not use: sbc_data is a VARIABLE and `use` does not import variables.
// ============================================================================

include <../config.scad>
include <../SBC_Model_Framework/sbc_models.scad>

// Every main mounting hole, from the framework rather than from pi5_hole_pattern.
// data[0] == "both" filters out the two heatsink holes, which are not mounting points.
function pi5MountingHoles() =
  let (s = search(["rpi5"], sbc_data), sindex = 2)
    [ for (i = [sindex : 11 : len(sbc_data[s[0]]) - 1])
        if (sbc_data[s[0]][i] == "pcbhole" && sbc_data[s[0]][i + 9][0] == "both")
          [sbc_data[s[0]][i + 3], sbc_data[s[0]][i + 4]] ];

// The board itself, for the showcase.
module pi5Board() { sbc(model = "rpi5", enablemask = false); }

// The IO mask: every connector swept outward, for subtracting from a wall.
module pi5IoMask() { sbc(model = "rpi5", enablemask = true); }
