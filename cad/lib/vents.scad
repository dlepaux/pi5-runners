// ============================================================================
// VENTS — hexrack's triangle lattice
// ============================================================================
// roundedTriangle() and trianglePattern() are COPIED VERBATIM from
// hexrack-sbc/cad/lib/vent-patterns.scad, with the same constants -- cell 14, web
// 1.6, corner 1.2, stagger 0.5 -- so the two projects read as one family. It is a
// copy, not a share: a change to the lattice means changing both files.
//
// NO CLOSED-FORM AREA. The earlier version of this file computed the open area from
// the cell count and asserted it against the fan's throat. That stops being possible
// once exclusion zones are carved out of the cutter -- the formula would have to
// re-derive every zone -- and a formula that re-derives geometry is exactly the
// "two features doing their own arithmetic" failure. scripts/test-airflow.sh MEASURES
// the drawn cutter instead. One source of truth: the geometry.
// ============================================================================

include <../config.scad>

// An equilateral triangle of the given edge length, apex up, centred on its
// centroid and rounded at the corners. offset(r) grows a triangle's inradius by
// r, i.e. its edge by 2*r*sqrt(3), so the seed is shrunk by that much first and
// the result measures `edge` again.
module roundedTriangle(edge, radius) {
  seed = edge - 2 * radius * sqrt(3);
  assert(seed > 0,
         str("roundedTriangle: radius ", radius, " rounds away an edge of ", edge));

  offset(r = radius, $fn = 24)
    rotate(90)
      circle(d = 2 * seed / sqrt(3), $fn = 3);
}

// Rows of alternating up and down triangles. Row j spans y in [j*h, (j+1)*h]:
// up triangles sit on its floor at x = i*cell, down triangles hang from its
// ceiling half a cell along.
//
// Alternate rows are shifted by `stagger` of a cell. At 0 the rows line up into
// the strict triangular tiling, which stacks every up triangle directly on the
// apex of the one below and reads as vertical columns. At 0.5 each row lands on
// the gaps of the row beneath, so an apex points into the web above it instead
// of at another apex -- the same nesting a brick bond gives, on a lattice that
// otherwise looks striped.
module trianglePattern(width, height, cell, wall, radius, stagger) {
  h = cell * sqrt(3) / 2;
  hole = cell - wall * sqrt(3);   // shrinking the inradius by wall/2 costs wall*sqrt(3) of edge
  assert(hole > 0,
         str("trianglePattern: wall ", wall, " closes a cell of ", cell));

  cols = ceil(width / cell / 2) + 1;
  rows = ceil(height / h / 2) + 1;

  // Centred on the panel means mirror-symmetric about its midline, and for a
  // triangular lattice that is a placement question, not a translation you can
  // eyeball. Reflection has to send every up triangle onto a real down triangle:
  //
  //   vertically, an up at j*h + h/3 lands on a down at k*h + 2h/3 only if the
  //   origin sits on a ROW BOUNDARY (hence no y shift here) and k = -j-1;
  //   horizontally, j -> -j-1 also flips the row parity, so the target row is
  //   the staggered one -- and at stagger 0.5 its half-cell offset is exactly
  //   where the mirror image lands.
  //
  // So the row range must be closed under j -> -j-1, which [-rows-1, rows] is,
  // and the column range needs one spare on the low side to receive it. Put the
  // origin on a triangle centroid instead and none of it lines up: that is the
  // half-row drift this replaced.
  translate([-cell / 2, 0])
    for (j = [-rows - 1 : rows]) {
      // j % 2 is -1 on odd negative rows, so test against zero rather than one.
      shift = (j % 2 == 0) ? 0 : stagger * cell;

      for (i = [-cols - 1 : cols]) {
        translate([i * cell + cell / 2 + shift, j * h + h / 3])
          roundedTriangle(hole, radius);

        translate([i * cell + cell + shift, j * h + 2 * h / 3])
          rotate(180)
            roundedTriangle(hole, radius);
      }
    }
}

// ----------------------------------------------------------------------------
// A FIELD: the lattice clipped to a w x h rectangle, lattice centred on it.
// ----------------------------------------------------------------------------
// trianglePattern() is centred on the origin and deliberately overflows; hexrack
// clips it against the panel outline, and so does this. The triangles at the field's
// edge are therefore CUT, not dropped -- which is hexrack's behaviour, kept on
// purpose so the two faces match. The solid border around the field is vent_margin,
// applied by the caller; that border is what stops a clipped triangle meeting the
// wall's edge.
module ventField(w, h, cell = vent_tri_cell, wall = vent_wall,
                 radius = vent_tri_radius, stagger = vent_tri_stagger) {
  intersection() {
    square([w, h]);
    translate([w / 2, h / 2])
      trianglePattern(w, h, cell, wall, radius, stagger);
  }
}
