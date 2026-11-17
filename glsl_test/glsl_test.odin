// curves.glsl against curves.odin: random outlined shapes under six pixel
// maps, each pixel's coverage_affine, winding, hairline and marker from the
// GLSL readers (curves.GLSL compiled by oksl and run on its CPU runner, the
// words in a read-only storage buffer behind curves_word) and from the Odin
// ones. Its own package because the curves package is core only; it needs
// oksl beside this checkout:
//
//     odin test glsl_test -collection:deps=.. -vet -strict-style
package glsl_test

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:testing"
import cv ".."
import "deps:oksl"

// A shape's pixels are N x N, and SHAPES shapes run under each map.
N :: 32
SHAPES :: 96
// The outline's width in pixels for hairline, and a ringed marker's ring.
HAIRLINE_WIDTH :: 1.5
MARKER_RING :: 1.25
// The marker's radius in pixels, whatever the map, so every map shows its
// edge.
MARKER_RADIUS :: 0.3 * N
// coverage_affine's crossing pieces are summed in another order (see
// curves.glsl), so its sums may round differently; the rest is the same
// arithmetic.
COVERAGE_TOLERANCE :: 1.0 / 4096
TOLERANCE :: 1.0 / 65536

SHADER :: `#version 300 es
precision highp float;
precision highp int;
layout(std430) readonly buffer Shape_Words { uint words[]; } shapeWords;
uint curves_word(uint i) { return shapeWords.words[i]; }
// rc = origin + x u + y v at the pixel's centre, in shape units.
uniform vec2 origin;
uniform vec2 u;
uniform vec2 v;
uniform int rule;
// The marker's centre and scale in shape units, its kind and its ring
// (0: filled).
uniform vec2 marker_center;
uniform float marker_scale;
uniform int circle;
uniform float ring;
out vec4 result;
void main() {
    vec2 rc = origin + gl_FragCoord.x * u + gl_FragCoord.y * v;
    vec2 mrc = (rc - marker_center) / marker_scale;
    result = vec4(
        curves_coverage_affine(0u, rc, u, v, rule),
        float(curves_winding(0u, rc)),
        curves_hairline(0u, rc, u, v, HAIRLINE_WIDTH),
        curves_marker(circle != 0, mrc, u / marker_scale, v / marker_scale, ring));
}
`

Map :: struct {
	name: string,
	// Source units a pixel step moves along x and along y, about the
	// shape's middle.
	u, v: [2]f32,
}

// Shapes span about 100 source units; an axis-aligned pixel is SPAN / N.
SPAN :: 120.0
MAPS := [?]Map {
	{"axis", {SPAN / N, 0}, {0, SPAN / N}},
	{"flipped", {-SPAN / N, 0}, {0, -SPAN / N}},
	{"rotated", {0.866 * SPAN / N, 0.5 * SPAN / N}, {-0.5 * SPAN / N, 0.866 * SPAN / N}},
	{"skewed", {SPAN / N, 0.3 * SPAN / N}, {0.45 * SPAN / N, SPAN / N}},
	{"zoomed in", {SPAN / N / 9, 0}, {0, SPAN / N / 9}},
	{"zoomed out", {9 * SPAN / N, 0}, {0, 9 * SPAN / N}},
}

@(private = "file")
point :: proc(r: rand.Generator) -> cv.Vec2 {
	return {10 + 80 * rand.float32(r), 10 + 80 * rand.float32(r)}
}

// One to three contours of three to eight lines, quadratics and cubics,
// each closed or left open.
@(private = "file")
random_shape :: proc(b: ^cv.Builder, r: rand.Generator) {
	cv.builder_reset(b)
	b.outline = true
	for _ in 0 ..< 1 + rand.int_max(3, r) {
		cv.move_to(b, point(r))
		for _ in 0 ..< 3 + rand.int_max(6, r) {
			switch rand.int_max(3, r) {
			case 0:
				cv.line_to(b, point(r))
			case 1:
				cv.quad_to(b, point(r), point(r))
			case:
				cv.cubic_to(b, point(r), point(r), point(r))
			}
		}
		if rand.int_max(2, r) == 0 {
			cv.close(b)
		} else {
			cv.end_open(b)
		}
	}
}

Worst :: struct {
	coverage, hairline, marker: f32,
	windings:                   int,
	// Pixels where each was non-zero, so a run that reads nothing fails.
	covered, wound, drawn, marked: int,
}

@(test)
test_glsl_matches_odin :: proc(t: ^testing.T) {
	m, errors, ok := oksl.compile_glsl(
		SHADER,
		{prelude = fmt.tprintf("#define HAIRLINE_WIDTH %v\n%s", HAIRLINE_WIDTH, cv.GLSL), no_spirv = true, no_msl = true},
	)
	defer oksl.destroy(m)
	if !testing.expectf(t, ok, "curves.glsl doesn't compile:\n%s", oksl.format_errors(errors, context.temp_allocator)) {
		return
	}
	testing.expect_value(t, len(m.storage_buffers), 1)
	block := make([]u8, m.block_size)
	defer delete(block)
	scratch: oksl.Scratch
	defer oksl.scratch_destroy(&scratch)
	out := make([][4]f32, N * N)
	defer delete(out)
	targets := [][][4]f32{out}

	b: cv.Builder
	defer cv.builder_destroy(&b)
	state := rand.create(0x0c0ffee)
	r := rand.default_random_generator(&state)
	worst: [len(MAPS)]Worst
	for k in 0 ..< SHAPES {
		random_shape(&b, r)
		words, shape_origin, extent, built := cv.build(&b)
		defer delete(words)
		if !testing.expectf(t, built, "shape %v doesn't build", k) {
			continue
		}
		rule := cv.Fill_Rule(k % 2)
		circle := k % 3 != 0
		ring: f32 = MARKER_RING if k % 4 >= 2 else 0
		for mp, n in MAPS {
			// In shape units: pixel (x, y)'s centre is origin + x u + y v
			// (gl_FragCoord's x and y, pixel centres at halves), the
			// shape's middle at the grid's.
			u := mp.u / extent
			v := mp.v / extent
			middle := (cv.Vec2{50, 50} - shape_origin) / extent
			origin := middle - 0.5 * N * u - 0.5 * N * v
			marker_center := middle
			marker_scale := MARKER_RADIUS * math.sqrt(abs(u.x * v.y - u.y * v.x))
			oksl.set_uniform(m, block, "origin", origin[:])
			oksl.set_uniform(m, block, "u", u[:])
			oksl.set_uniform(m, block, "v", v[:])
			oksl.set_uniform(m, block, "rule", {f32(rule)})
			oksl.set_uniform(m, block, "marker_center", marker_center[:])
			oksl.set_uniform(m, block, "marker_scale", {marker_scale})
			oksl.set_uniform(m, block, "circle", {1 if circle else 0})
			oksl.set_uniform(m, block, "ring", {ring})
			oksl.run_targets(&m.program, block, N, N, targets, &scratch, {buffers = {words}})
			w := &worst[n]
			for y in 0 ..< N {
				for x in 0 ..< N {
					g := out[y * N + x]
					rc := origin + (f32(x) + 0.5) * u + (f32(y) + 0.5) * v
					mrc := (rc - marker_center) / marker_scale
					coverage := cv.coverage_affine(words, rc, u, v, rule)
					winding := cv.winding(words, rc)
					hairline := cv.hairline(words, rc, u, v, HAIRLINE_WIDTH)
					marker := cv.marker(circle, mrc, u / marker_scale, v / marker_scale, ring)
					w.coverage = max(w.coverage, abs(g[0] - coverage))
					w.hairline = max(w.hairline, abs(g[2] - hairline))
					w.marker = max(w.marker, abs(g[3] - marker))
					if g[1] != f32(winding) {
						w.windings += 1
					}
					if math.is_nan(g[0]) || math.is_nan(g[2]) || math.is_nan(g[3]) {
						w.coverage = math.INF_F32
					}
					w.covered += int(coverage > 0)
					w.wound += int(winding != 0)
					w.drawn += int(hairline > 0)
					w.marked += int(marker > 0)
				}
			}
		}
	}
	for w, n in worst {
		name := MAPS[n].name
		log.infof("%-10s worst coverage %.3g, hairline %.3g, marker %.3g; windings differ %v (covered %v, wound %v, drawn %v, marked %v of %v)", name, w.coverage, w.hairline, w.marker, w.windings, w.covered, w.wound, w.drawn, w.marked, SHAPES * N * N)
		testing.expectf(t, w.coverage <= COVERAGE_TOLERANCE, "%s: coverage_affine differs by %v", name, w.coverage)
		testing.expectf(t, w.hairline <= TOLERANCE, "%s: hairline differs by %v", name, w.hairline)
		testing.expectf(t, w.marker <= TOLERANCE, "%s: marker differs by %v", name, w.marker)
		testing.expectf(t, w.windings == 0, "%s: %v windings differ", name, w.windings)
		testing.expectf(t, w.covered > 0 && w.wound > 0 && w.drawn > 0 && w.marked > 0, "%s: a reader found nothing to compare", name)
	}
}
