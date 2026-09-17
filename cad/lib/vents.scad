// ============================================================================
// VENTS — the exhaust budget
// ============================================================================
// ONE CELL LIST, TWO CONSUMERS. ventField() draws the holes and ventOpenArea()
// measures them, and both read the same cell list. Computing the area in closed form
// beside a module that draws something slightly different is how you end up asserting
// an airflow budget that does not exist -- the parts still render, still export,
// still pass every other check, and the case chokes.
//
// scripts/test-airflow.sh measures the DRAWN area and compares it to the computed
// one, so the two cannot drift even if someone edits the packing.
//
// roundedTriangle() is COPIED from hexrack-sbc/cad/lib/vent-patterns.scad, not
// shared. It is a genuine fork: hexrack's pattern is centred on a panel and carries
// mirror-symmetry placement this project does not need, because these fields are
// corner-anchored rectangles. A change to the rounding maths means changing both.
// ============================================================================

include <../config.scad>

// ----------------------------------------------------------------------------
// TRIANGLES — the default
// ----------------------------------------------------------------------------

// An equilateral triangle of the given edge length, apex up, centred on its centroid
// and rounded at the corners. offset(r) grows a triangle's inradius by r, i.e. its
// edge by 2*r*sqrt(3), so the seed is shrunk by that much first and the result
// measures `edge` again.
module roundedTriangle(edge, radius) {
  seed = edge - 2 * radius * sqrt(3);
  assert(seed > 0,
         str("roundedTriangle: radius ", radius, " rounds away an edge of ", edge));
  offset(r = radius, $fn = 24)
    rotate(90)
      circle(d = 2 * seed / sqrt(3), $fn = 3);
}

// Area of that shape, exactly. offset(r) on a convex polygon adds perimeter*r plus a
// full circle of radius r -- the corner arcs sum to 360 degrees. Seed edge s:
//   sqrt(3)/4 * s^2  +  3*s*r  +  PI*r^2
function triCellArea(cell = undef, web = undef) =
  let (c = is_undef(cell) ? vent_tri_cell : cell,
       w = is_undef(web) ? vent_wall : web,
       edge = c - w * sqrt(3),
       r    = vent_tri_radius,
       s    = edge - 2 * r * sqrt(3))
    sqrt(3) / 4 * pow(s, 2) + 3 * s * r + PI * pow(r, 2);

function triRowH(cell = undef) =
  (is_undef(cell) ? vent_tri_cell : cell) * sqrt(3) / 2;

// Rows of alternating up and down triangles. Row j spans y in [j*h, (j+1)*h]: up
// triangles sit on its floor, down triangles hang from its ceiling half a cell along.
// Returns [x, y, up] per cell.
function triCells(w, h, cell_ = undef) =
  let (cell = is_undef(cell_) ? vent_tri_cell : cell_, rh = triRowH(cell),
       rows = floor(h / rh), cols = floor(w / cell))
  rows <= 0 || cols <= 0 ? [] :
  [ for (j = [0 : rows - 1], i = [0 : cols - 1], up = [0, 1])
      let (x = i * cell + (up ? 0.5 : 1.0) * cell,
           y = j * rh + (up ? rh / 3 : 2 * rh / 3))
        if (x - cell / 2 >= 0 && x + cell / 2 <= w) [x, y, up] ];

// ----------------------------------------------------------------------------
// HEXAGONS — kept because the roof field may want a different look
// ----------------------------------------------------------------------------

function hexR()  = vent_hex_cell / 2;
function hexDx() = 1.5 * hexR() + vent_wall;
function hexDy() = sqrt(3) * hexR() + vent_wall;
function hexCellArea() = 3 * sqrt(3) / 2 * pow(hexR(), 2);

function hexCells(w, h) =
  let (dx = hexDx(), dy = hexDy(), r = hexR(),
       nx = floor((w - 2 * r) / dx) + 1,
       ny = floor((h - 2 * r) / dy) + 1)
  nx <= 0 || ny <= 0 ? [] :
  [ for (i = [0 : nx - 1], j = [0 : ny - 1])
      let (y = r + j * dy + (i % 2) * dy / 2)
        if (y + r <= h) [r + i * dx, y] ];

// ----------------------------------------------------------------------------
// DISPATCH
// ----------------------------------------------------------------------------

function ventCellArea(cell = undef, web = undef) =
  vent_pattern == "hex" ? hexCellArea() : triCellArea(cell, web);

// cell/web default to the wall fields' values. The FILTER passes its own: a wall
// field is sized for panel stiffness over a big panel, a filter grille for maximum
// open area over a small square, and the measured difference between the two settings
// is 47% of the fan's throat against 71%. Different problems, different numbers.
function ventOpenArea(w, h, cell = undef, web = undef) =
  (vent_pattern == "hex" ? len(hexCells(w, h)) : len(triCells(w, h, cell)))
    * ventCellArea(cell, web);

module ventField(w, h, cell = undef, web = undef) {
  c_ = is_undef(cell) ? vent_tri_cell : cell;
  w_ = is_undef(web)  ? vent_wall     : web;
  if (vent_pattern == "hex") {
    for (c = hexCells(w, h))
      translate(c) rotate(30) circle(r = hexR(), $fn = 6);
  } else {
    for (c = triCells(w, h, c_))
      translate([c[0], c[1]])
        rotate(c[2] ? 0 : 180)
          roundedTriangle(c_ - w_ * sqrt(3), vent_tri_radius);
  }
}
