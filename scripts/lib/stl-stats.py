#!/usr/bin/env python3
"""Report structural facts about a binary STL.

Component count is the interesting default: a decorative feature unioned onto a
perforated panel is only actually attached if the result stays a single body. STL
carries no topology, so components are recovered by welding coincident vertices.

Genus counts the through-holes. It is what distinguishes a notch that opened into
an existing bore from one that closed on itself into a separate hole -- both look
identical by volume and triangle count.

Usage: stl-stats.py <file.stl>            ->  "<triangles> <components>"
       stl-stats.py <file.stl> --genus    ->  "<genus>"
       stl-stats.py <file.stl> --volume   ->  "<mm3>"
       stl-stats.py <file.stl> --bboxes   ->  one "<dx> <dy> <dz>" line per body
"""

import struct
import sys

# Vertex coordinates are rounded before welding: OpenSCAD emits float32, so two
# triangles meeting at one corner can disagree in the last bit.
PRECISION = 4


def read_triangles(path):
    """Raw float32 vertex triples, exactly as written."""
    with open(path, "rb") as handle:
        handle.read(80)
        (count,) = struct.unpack("<I", handle.read(4))
        triangles = []
        for _ in range(count):
            record = handle.read(50)
            if len(record) < 50:
                raise ValueError(f"{path}: truncated at triangle {len(triangles)}")
            values = struct.unpack("<12f", record[:48])
            triangles.append(tuple(values[i:i + 3] for i in (3, 6, 9)))
    return triangles


def welded(triangles):
    return [
        tuple(tuple(round(c, PRECISION) for c in vertex) for vertex in triangle)
        for triangle in triangles
    ]


def components(triangles):
    """Group triangles by connected body. Keys are arbitrary but stable."""
    parent = {}

    def find(vertex):
        while parent[vertex] != vertex:
            parent[vertex] = parent[parent[vertex]]
            vertex = parent[vertex]
        return vertex

    def union(a, b):
        root_a, root_b = find(a), find(b)
        if root_a != root_b:
            parent[root_a] = root_b

    for triangle in triangles:
        for vertex in triangle:
            parent.setdefault(vertex, vertex)
    for triangle in triangles:
        union(triangle[0], triangle[1])
        union(triangle[1], triangle[2])

    groups = {}
    for triangle in triangles:
        groups.setdefault(find(triangle[0]), []).append(triangle)
    return list(groups.values())


def count_components(triangles):
    return len(components(triangles))


def bboxes(triangles):
    """Per-body [dx, dy, dz] extents, largest body first."""
    sizes = []
    for group in components(triangles):
        axes = [[v[i] for t in group for v in t] for i in range(3)]
        sizes.append([max(a) - min(a) for a in axes])
    return sorted(sizes, key=lambda s: -s[0] * s[1] * s[2])


def total_genus(triangles):
    """Summed genus over every component, via Euler characteristic.

    chi = V - E + F, and for C closed surfaces chi = 2C - 2G, so G = (2C - chi)/2.
    """
    vertices, edges = set(), set()
    for triangle in triangles:
        vertices.update(triangle)
        for a, b in ((triangle[0], triangle[1]),
                     (triangle[1], triangle[2]),
                     (triangle[2], triangle[0])):
            edges.add((a, b) if a <= b else (b, a))
    chi = len(vertices) - len(edges) + len(triangles)
    return (2 * count_components(triangles) - chi) // 2


def volume(triangles):
    """Signed volume by the divergence theorem; needs unrounded coordinates."""
    total = 0.0
    for a, b, c in triangles:
        total += (a[0] * (b[1] * c[2] - b[2] * c[1])
                  - a[1] * (b[0] * c[2] - b[2] * c[0])
                  + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    return total


def main():
    args = sys.argv[1:]
    metrics = [a for a in args if a.startswith("--")]
    paths = [a for a in args if not a.startswith("--")]
    if len(paths) != 1 or len(metrics) > 1 or any(
            m not in ("--genus", "--volume", "--bboxes") for m in metrics):
        print("usage: stl-stats.py <file.stl> [--genus|--volume|--bboxes]",
              file=sys.stderr)
        return 2

    triangles = read_triangles(paths[0])
    if not triangles:
        print("0" if metrics else "0 0")
        return 0

    if metrics == ["--volume"]:
        print(f"{volume(triangles):.3f}")
    elif metrics == ["--genus"]:
        print(total_genus(welded(triangles)))
    elif metrics == ["--bboxes"]:
        for size in bboxes(welded(triangles)):
            print(" ".join(f"{d:.3f}" for d in size))
    else:
        print(f"{len(triangles)} {count_components(welded(triangles))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
