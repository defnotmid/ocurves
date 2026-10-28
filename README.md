# ocurves

Native Odin curve geometry for vector renderers: shapes built as curves
whose coverage of a pixel is computed exactly, on the CPU and (with
`curves.slang`) on the GPU, and booleans of filled contours that keep their
curves. One package, `curves`, core only (no C library, no other
dependency). MIT licensed ([LICENSE](LICENSE)).

[ovg](https://github.com/defnotmid/ovg) fills its paths, glyphs, strokes and
markers with it, and [o3d](https://github.com/defnotmid/o3d) its curved
shapes and text in 3D.

## What's in it

- **Shapes** (`curves.odin`): a `Builder` takes contours (`move_to`,
  `line_to`, `quad_to`, `cubic_to`, `close`, `end_open`, `orient`) and
  `build` / `build_append` write the shape as one block of 32-bit words:
  quadratic pieces, each monotone in x and y, cut into the columns of a grid
  of cells, each cell listing its pieces and its backdrop (the winding
  number right of it), in time linear in the pieces. Reading the words:
  `coverage` of a box footprint, `coverage_affine` of any parallelogram,
  `coverage_jacobian` from a 3D footprint's Jacobian, `winding` at a point,
  `mean_coverage` and `fade` for a shape smaller than a pixel, `bounds` and
  `hairline` (the contours as thin lines); `marker` covers a pixel by a
  square or circle marker without any words. A pixel's coverage
  is the area of its footprint inside the shape, in closed form (Green's
  theorem) over the pieces in the cells it covers plus the backdrop over
  its rows: exact under any affine footprint, and a pixel costs the pieces
  near it, not the shape's size. The layout is documented at the top of
  curves.odin.
- **The GPU twin** (`curves.slang`): the same reads in Slang, for a shader
  to include (`slangc -I <this checkout>`, `#include "curves.slang"`); it
  binds nothing, and reads any number of shapes from one
  `StructuredBuffer<uint>`.
- **Contours** (`contours.odin`): lines and cubics in one flat table (every
  contour's points, each segment's kind, a row per contour; neighbours
  share their end point by index) and `contours_winding` at a point.
- **Booleans** (`bool.odin`, `bool_kernel.odin`): `bool_run` gives the
  union, difference, intersection or xor of any number of operands (ranges
  of a `Contours` table, each with its fill rule; one operand simplifies),
  and `bool_divide` every face they make, each with the operands it lies
  inside. The result keeps the operands' own curves: each output segment
  is a range of an input line or cubic, cut where the operands meet, and
  the scratch records where each came from. Output contours are
  Solid-wound with holes reversed and never cross. One arrangement of every
  operand's pieces in f64: pieces are cut wherever two come within eps = 8
  f32 ulps of the largest coordinate (a near-set search that drops a pair
  only once it has proved them farther apart), cut points within eps merge
  into vertices, edges along the same curve between the same vertices
  merge with their windings summed, faces are walked and each face's
  winding per operand propagated. Every table is the caller's
  `Bool_Scratch`: no allocation once it is warm.
- **Cubics** (`cubic.odin`): a cubic's point at t, sub-range, extrema,
  bounds, signed area and its split into quadratics within a tolerance, for
  f32 and f64 points alike.

## The format

`FORMAT` numbers the layout of the words `build` writes and `curves.slang`
reads, and is bumped whenever a reader of one layout would misread the
other's words (`test_format` pins one shape's words). A renderer that
commits shaders compiled from `curves.slang` records the `FORMAT` it
compiled them against and `#assert`s it equals `curves.FORMAT`, so it
refuses to build against an ocurves its shaders would misread.

## Use

```sh
git clone https://github.com/defnotmid/ocurves
```

```odin
import cv "deps:ocurves"   // -collection:deps=.. (the directory holding ocurves)

b: cv.Builder
defer cv.builder_destroy(&b)
cv.move_to(&b, {0, 0})
cv.line_to(&b, {0, 10})
cv.quad_to(&b, {10, 10}, {10, 0})
cv.close(&b)
words, origin, extent, ok := cv.build(&b)
defer delete(words)
// The coverage of a pixel at p (source units) with sides of 1 unit: shape
// units are the source's divided by extent, starting at origin.
p := [2]f32{4.5, 4.5}
cov := cv.coverage(words, (p - origin) / extent, {1, 1} / extent, false)
```

## Test

```sh
odin test . -vet -strict-style
```

The package's history before v0.0.1 is ovg's: it was ovg's `curves/`
package and `shaders/curves.slang`, moved as of ovg 9cb03834 (v0.0.42).
ovg's `tools/bool_suite` fuzzes the booleans through its path API.
