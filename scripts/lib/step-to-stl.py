#!/usr/bin/env python3
"""Tessellate a STEP file into a binary STL that OpenSCAD can import.

OpenSCAD reads STL, OFF, 3MF, AMF and DXF, and nothing else — feed it a .stp and it
answers `ERROR: Unsupported file format`. Vendors ship STEP. This bridges the two.

Needs OpenCASCADE's Python bindings, which are not a project dependency and are not
needed to build or test anything:

    python3 -m venv .venv && .venv/bin/pip install cadquery-ocp
    .venv/bin/python scripts/lib/step-to-stl.py in.stp out.stl

DEFLECTION is the number that matters. It is the maximum distance the tessellation is
allowed to stray from the true surface, in mm. 0.05 keeps a 140mm fan frame's flat faces
flat to well under a print layer while keeping the mesh small enough that OpenSCAD's CSG
stays interactive. Coarser than ~0.2 and the bolt holes visibly polygonalise; finer than
~0.02 and the triangle count stops paying for itself.

Usage: step-to-stl.py <in.stp> <out.stl> [--keep N] [--deflection MM]
       step-to-stl.py <in.stp> --list
"""

import sys

from OCP.BRep import BRep_Builder
from OCP.BRepBndLib import BRepBndLib
from OCP.BRepGProp import BRepGProp
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.Bnd import Bnd_Box
from OCP.GProp import GProp_GProps
from OCP.IFSelect import IFSelect_RetDone
from OCP.STEPControl import STEPControl_Reader
from OCP.StlAPI import StlAPI_Writer
from OCP.TopAbs import TopAbs_SOLID
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS_Compound


def solids(shape):
    """Every closed solid in the file, largest by volume first."""
    found = []
    explorer = TopExp_Explorer(shape, TopAbs_SOLID)
    while explorer.More():
        solid = explorer.Current()
        props = GProp_GProps()
        BRepGProp.VolumeProperties_s(solid, props)
        found.append((props.Mass(), solid))
        explorer.Next()
    return [s for _, s in sorted(found, key=lambda t: -t[0])]


def read(src):
    reader = STEPControl_Reader()
    if reader.ReadFile(src) != IFSelect_RetDone:
        raise SystemExit(f"{src}: STEP read failed")
    # A vendor STEP is many roots — a fan is a frame, an impeller, eight rubber pads and
    # a hub cap. TransferRoots pulls all of them; TransferRoot gives you only the first.
    reader.TransferRoots()
    shape = reader.OneShape()
    if shape.IsNull():
        raise SystemExit(f"{src}: STEP contained no shape")
    return shape


def convert(src, dst, deflection=0.05, angular=0.3, keep=None):
    """Tessellate src to dst.

    keep = None  -> everything, which is what you want for a picture and NOT what you
                    want for CSG. Noctua's fans carry a face that fails to triangulate,
                    so the combined mesh comes out unclosed and OpenSCAD's manifold
                    backend answers `Input mesh is not closed!` and empties the whole
                    object it was part of. That is trap #4 in CLAUDE.md, live.
    keep = n     -> the n largest solids by volume. For both Noctua fans the largest is
                    the frame, which is the only part a case has to keep clear of, and
                    on its own it meshes closed.
    """
    shape = read(src)

    if keep:
        chosen = solids(shape)[:keep]
        if not chosen:
            raise SystemExit(f"{src}: no solids found")
        builder = BRep_Builder()
        compound = TopoDS_Compound()
        builder.MakeCompound(compound)
        for solid in chosen:
            builder.Add(compound, solid)
        shape = compound

    # relative=False: deflection is absolute millimetres, not a fraction of each face's
    # own size. Relative mode tessellates a 4mm bolt hole far more coarsely than a 140mm
    # face, which is exactly backwards for checking whether a screw fits.
    BRepMesh_IncrementalMesh(shape, deflection, False, angular, True)

    writer = StlAPI_Writer()
    writer.ASCIIMode = False        # binary; see the export-format note in CLAUDE.md
    if not writer.Write(shape, dst):
        raise SystemExit(f"{dst}: STL write failed")

    box = Bnd_Box()
    BRepBndLib.Add_s(shape, box)
    return dst


def report(src):
    shape = read(src)
    print(f"{src}")
    for i, solid in enumerate(solids(shape)):
        props = GProp_GProps()
        BRepGProp.VolumeProperties_s(solid, props)
        box = Bnd_Box()
        BRepBndLib.Add_s(solid, box)
        # NOT box.Get(). Current cadquery-ocp returns a Bnd_Box::Limits that the
        # bindings never register, so the call raises "Unable to convert function
        # return value to a Python type" rather than returning the six floats the
        # older bindings gave. CornerMin/CornerMax are gp_Pnt and are stable.
        lo, hi = box.CornerMin(), box.CornerMax()
        xm, ym, zm = lo.X(), lo.Y(), lo.Z()
        xM, yM, zM = hi.X(), hi.Y(), hi.Z()
        print("  [%2d] %10.1f mm3   X %8.2f..%8.2f  Y %8.2f..%8.2f  Z %8.2f..%8.2f"
              % (i, props.Mass(), xm, xM, ym, yM, zm, zM))


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("src")
    parser.add_argument("dst", nargs="?")
    parser.add_argument("--list", action="store_true",
                        help="print the file's solids, largest first, and exit")
    parser.add_argument("--keep", type=int, default=None,
                        help="mesh only the N largest solids (1 = the frame)")
    parser.add_argument("--deflection", type=float, default=0.05)
    parser.add_argument("--angular", type=float, default=0.3)
    cli = parser.parse_args()

    if cli.list:
        report(cli.src)
    else:
        if not cli.dst:
            parser.error("dst is required unless --list is given")
        print("wrote " + convert(cli.src, cli.dst, cli.deflection, cli.angular, cli.keep))
