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
use <ports.scad>
use <vents.scad>
use <noctua-fan.scad>

// Seam heights. The base is the floor plus a 2mm skirt, the roof the ceiling plus the
// same, so the joints sit just off the floor and ceiling lines.
//
// THEY WERE 6mm SKIRTS, AND THAT SEVERED THE FRONT WALL. The 80mm intake spans
// z 9.98..89.98; with the seams at 9 and 90.95 the SHELL part kept under 1mm of wall
// above and below it -- two side posts joined by strips too thin to print well. The
// assembled case looked fine, because the base and roof skirts fill that band, which
// is exactly why nothing in the suite saw it. It took a render.
//
// Pulling the seams to 5 and 94.95 fixes that AND lifts the roof seam clear of the top
// board's port cluster (z 77.95..94.2), which used to be split across two parts.
base_h = wall + 2;
roof_h = wall + 2;

// The front wall of the SHELL part must survive the intake. min_strip is the thinnest
// band of wall left above and below the opening, in the part as printed.
intake_min_strip = 4;
intake_z0 = wall + fan_z0;
intake_z1 = wall + fan_z0 + fan_col_h;
assert(intake_z0 - base_h >= intake_min_strip,
       str("intake leaves ", intake_z0 - base_h, "mm of shell wall below it"));
assert((outer[2] - roof_h) - intake_z1 >= intake_min_strip,
       str("intake leaves ", (outer[2] - roof_h) - intake_z1, "mm of shell wall above it"));

// Every board's port cluster must sit wholly inside the shell part, not split across
// a seam into two printed parts.
for (i = [0 : 2])
  assert(wall + board_z[i] + exclusion_cluster_z[0] > base_h
      && wall + board_z[i] + exclusion_cluster_z[1] < outer[2] - roof_h,
         str("board ", i, "'s port cluster straddles a seam"));

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
// The case as it is actually built: the box, less every opening. CUT ONCE, THEN
// CLAIM. Cutting each panel separately would let two panels disagree about where an
// opening is; more subtly, it breaks the tiling check, which has to compare the parts
// against the thing they are supposed to add up to -- and that is this, not the
// uncut box.
module shellCut() {
  difference() {
    shellSolid();
    allPortCuts();
    ventCuts();
    fanCut();
  }
}

module shellPanel(which) {
  render()
    intersection() {
      shellCut();
      claimVolume(which);
    }
}

// ----------------------------------------------------------------------------
// WALL FRAMES
// ----------------------------------------------------------------------------
// Both the intake and the exhaust live on X-facing walls, so both are drawn as 2D
// profiles in (Y, Z) and swept along X.
//
// rotate([90,0,90]) is Rz(90) . Rx(90): Rx(90) sends the profile's y to Z and the
// extrusion to -Y; Rz(90) then sends X to Y and -Y to +X. Net: profile x -> world Y,
// profile y -> world Z, extrusion -> +X. Derived rather than guessed, because a
// rotate() with the wrong sign lands the cut behind the wall, renders nothing, and
// passes every emptiness check in the suite.
module onXWall(x0) {
  translate([x0, 0, 0]) rotate([90, 0, 90]) children();
}

// ----------------------------------------------------------------------------
// INTAKE — the -X front wall
// ----------------------------------------------------------------------------
// One rounded-rectangle opening for the whole column plus each fan's own four
// screws, centred on the wall.
// Positioned from fan_z0, which config.scad has asserted spans the whole board stack.
function fanCentreYZ() = [wall + interior_y / 2, wall + fan_col_zc];

module fanCut() {
  c = fanCentreYZ();
  onXWall(-EPS)
    linear_extrude(wall + 4 * EPS)
      translate(c) {
        fanOpeningProfile();
        fanBoltProfile(fan_screw_d);
      }
}

// ----------------------------------------------------------------------------
// EXHAUST — the +X rear wall, and only there
// ----------------------------------------------------------------------------
// hexrack's back face: a triangle field over the whole wall, with an EXCLUSION ZONE
// per board carved out of the cutter around its port cluster. The ports then sit in
// clean solid material with the pattern running round them, instead of in a wall that
// is half-triangles where a connector happens to land.
//
// The zone is subtracted from the CUTTER, not added to the wall. Adding material back
// would work visually and fail structurally: the port cutouts are subtracted after,
// and a zone built as solid would be a separate body sitting in the vent holes.
// Centred on the MEASURED cluster, not on the board: the cluster is not symmetric
// about the board's centreline, and a zone centred on the board would be generous on
// one side and tight on the other.
function exclusionCentre(i) =
  [wall + board_y + (exclusion_cluster_y[0] + exclusion_cluster_y[1]) / 2,
   wall + board_z[i] + (exclusion_cluster_z[0] + exclusion_cluster_z[1]) / 2];

module exclusionZone(i) {
  translate(exclusionCentre(i))
    offset(r = exclusion_r, $fn = 30)
      square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r], center = true);
}

// EVERY VENT FIELD LIVES INSIDE THE SHELL PANEL'S BAND, clear of both seams. A field
// that crosses the base/shell or shell/roof seam cuts triangles in half across two
// printed parts: each half prints as a notch in a thin seam lip, and the two halves
// only line up again once the case is assembled. The earlier rear field did exactly
// that at both ends.
function ventBandZ0() = base_h + vent_margin;
function ventBandZ1() = outer[2] - roof_h - vent_margin;
function ventBandH()  = ventBandZ1() - ventBandZ0();

// The rear cutter in (Y, Z) wall coordinates: the field, less the three zones.
// Exposed as its own module so test-airflow.sh measures EXACTLY what is cut.
module rearVentProfile() {
  difference() {
    translate([wall + vent_margin, ventBandZ0()])
      ventField(vent_rear_w, ventBandH());
    for (i = [0 : 2]) exclusionZone(i);
  }
}

// A side field in (X, Z) wall coordinates, at the rear of the wall. Both side walls
// use the same one. No exclusion zones: side_field_x0 is asserted behind the -Y ports
// in config.scad, and the +Y wall has nothing on it.
module sideVentProfile() {
  translate([wall + side_field_x0, ventBandZ0()])
    ventField(vent_side_depth, ventBandH());
}

// Y-facing walls stand in XZ, swept along Y.
//
// rotate([90,0,0]) is Rx(90): profile x -> X, profile y -> +Z, extrusion -> -Y. So the
// sweep has to START at the wall's HIGH-Y face and run toward -Y. Start it at the low
// face and it runs out of the case into open air, cuts nothing, and passes.
module onYWall(y_high) {
  translate([0, y_high, 0]) rotate([90, 0, 0]) children();
}

module ventCuts() {
  onXWall(outer[0] - wall - EPS)
    linear_extrude(wall + 4 * EPS)
      rearVentProfile();

  // -Y side wall, slab y 0..wall
  onYWall(wall + EPS)
    linear_extrude(wall + 4 * EPS)
      sideVentProfile();

  // +Y side wall, slab y outer[1]-wall..outer[1]
  onYWall(outer[1] + EPS)
    linear_extrude(wall + 4 * EPS)
      sideVentProfile();
}
