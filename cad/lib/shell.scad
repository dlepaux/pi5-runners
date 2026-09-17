// ============================================================================
// SHELL — one solid, cut three ways
// ============================================================================
// The case is a single hollow box. base, shell and roof are that box intersected
// with three disjoint claims that together account for all of it. Cutting one solid
// rather than modelling three parts means the walls cannot disagree about where they
// are: there is one outer surface and one inner surface in the whole project.
//
// THE CLAIMS MUST BE DISJOINT AND COMPLETE. Overlapping claims print two parts that
// cannot both be in the case; claims that leave a gap print a case with a band
// missing. Both render, export and count one body. scripts/test-parts.sh checks each
// direction, because neither implies the other.
// ============================================================================

include <../config.scad>

// Seam heights. The base takes the floor plus a short skirt so its joint is off the
// floor line, and the roof takes the ceiling plus a matching skirt.
base_h = wall + 6;
roof_h = wall + 6;

assert(base_h + roof_h < outer[2],
       "base and roof skirts have eaten the whole case — nothing left for the walls");

// ----------------------------------------------------------------------------
// THE SOLID
// ----------------------------------------------------------------------------

module shellSolid() {
  difference() {
    cube(outer);
    translate([wall, wall, wall]) cube([interior_x, interior_y, interior_h]);
  }
}

// ----------------------------------------------------------------------------
// CLAIMS
// ----------------------------------------------------------------------------
// Each is [origin, size] in the case's frame, spanning the full footprint and
// differing only in z. Returned as data rather than drawn so tests.scad can reason
// about them without re-deriving the numbers.
function claim(which) =
    which == "base"  ? [[0, 0, 0],                  [outer[0], outer[1], base_h]]
  : which == "roof"  ? [[0, 0, outer[2] - roof_h],  [outer[0], outer[1], roof_h]]
  :                    [[0, 0, base_h],             [outer[0], outer[1],
                                                     outer[2] - base_h - roof_h]];

module claimVolume(which, grow = 0) {
  c = claim(which);
  translate(c[0] - [grow, grow, grow])
    cube(c[1] + [2 * grow, 2 * grow, 2 * grow]);
}

// ----------------------------------------------------------------------------
// PANELS
// ----------------------------------------------------------------------------

// render() is NOT optional. Preview does not evaluate booleans -- it flattens the
// model into a sum of products, which is exponential in nested differences. A panel
// that is the shell intersected with its claim and then cut by ports and vents passes
// OpenSCAD's normalisation limit, at which point it aborts and shows a BLANK WINDOW
// while exporting perfectly the whole time.
//
// The claim is NOT grown here. A claim grown in z would overlap its neighbour, and
// these three tile the case exactly; growth belongs on bosses and tenons, which ask
// for slightly more than they occupy so a neighbour's subtraction cannot leave a
// zero-volume skin.
module shellPanel(which) {
  render()
    intersection() {
      shellSolid();
      claimVolume(which);
    }
}
