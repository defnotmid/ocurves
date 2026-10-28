// Bakes the demo's data and measures every number it shows, against the
// ocurves and ovg checkouts beside this one:
//
//     odin run demo/bake -collection:deps=.. -o:speed -- demo/media/bake.json
//
// from ocurves' root (deps: ocurves, ovg, oglyph, odecs side by side). It
// prints the facts (demo/facts.lua quotes them) and writes the scenes' data:
// a glyph's pieces and cells, a small glyph's pixels three ways (exact,
// 4x MSAA, a 128 x 128-sample reference), the booleans' segments with their
// sources, the divide's faces, and the same glyph drawn by ovg's software
// rasterizer (ocurves' coverage) and its SDL_GPU backend (curves.slang).
// The GPU half needs a GPU (SDL_GPU, headless).
package bake

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"
import cv "deps:ocurves"
import vg "deps:ovg"
import vgsdl "deps:ovg/sdlgpu"
import sdl "vendor:sdl3"

SERIF :: #load("../media/InstrumentSerif-Italic.ttf")

Piece :: [6]f32

// The shapes scene: a glyph's contours, its pieces and its grid, in video
// pixels from the glyph's origin.
Shape_Bake :: struct {
	outline:       string,
	pieces:        []Piece,
	nx, ny:        int,
	origin:        [2]f32,
	cell:          [2]f32,
	counts:        []int,
	backdrops:     []int,
	contours:      int,
	segments:      int,
	build_us:      f64,
}

// The coverage scene: a small glyph's pixels (row by row, 0..1).
Coverage_Bake :: struct {
	outline:                    string,
	w, h:                       int,
	exact, msaa, reference:     []f32,
	exact_max, exact_mean:      f64,
	msaa_max, msaa_mean:        f64,
	samples:                    int,
	coverage_ns:                f64,
}

Segment_Bake :: struct {
	d:      string,
	cubic:  bool,
	points: [8]f32, // start, controls, end
	source: int, // the operand it came from; -1 for a closing line
}

Bool_Bake :: struct {
	op:       string,
	fill:     string,
	segments: []Segment_Bake,
	cubics:   int,
	lines:    int,
	run_us:   f64,
}

Face_Bake :: struct {
	d:      string,
	inside: [2]bool,
}

Gpu_Bake :: struct {
	w, h:             int,
	cpu, gpu:         []u8,
	max_diff:         int,
	differing:        int,
	driver:           string,
}

Budget_Bake :: struct {
	font:        string,
	glyphs:      int,
	worst:       int,
}

Bake :: struct {
	operands: [2]string,
	operand_paths: [2]string,
	shape:    Shape_Bake,
	coverage: Coverage_Bake,
	bools:    []Bool_Bake,
	faces:    []Face_Bake,
	gpu:      Gpu_Bake,
	budgets:  []Budget_Bake,
	cpu:      string,
}

main :: proc() {
	out_path := os.args[1] if len(os.args) > 1 else "demo/media/bake.json"
	font, err := vg.font_load(SERIF)
	assert(err == nil)
	bake: Bake
	bake.cpu = cpu_model()
	bake.shape = bake_shape(&font)
	bake.coverage = bake_coverage(&font)
	bake.operands = {"a circle", "the letter S"}
	bake.bools, bake.faces, bake.operand_paths = bake_bools(&font)
	bake.gpu = bake_gpu(&font)
	bake.budgets = bake_budgets()

	data, merr := json.marshal(bake, {pretty = false})
	assert(merr == nil)
	if werr := os.write_entire_file(out_path, data); werr != nil {
		fmt.eprintln("bake: can't write", out_path, werr)
		os.exit(1)
	}
	c := bake.coverage
	fmt.printfln("shape: '&' in Instrument Serif Italic at 620 px: %d contours, %d segments -> %d pieces in %d x %d cells, built in %.1f us (median of 201)",
		bake.shape.contours, bake.shape.segments, len(bake.shape.pieces), bake.shape.nx, bake.shape.ny, bake.shape.build_us)
	fmt.printfln("coverage: '&' at 22 px, %d x %d pixels against %d samples a pixel: exact max %.3f / 255, mean %.4f / 255; 4x MSAA max %.1f / 255, mean %.2f / 255; %.0f ns a pixel",
		c.w, c.h, c.samples, c.exact_max, c.exact_mean, c.msaa_max, c.msaa_mean, c.coverage_ns)
	for b in bake.bools {
		fmt.printfln("%s: %d segments, %d of them cubics (each a range of an operand's), %d lines; %.1f us (median of 51)", b.op, len(b.segments), b.cubics, b.lines, b.run_us)
	}
	fmt.printfln("divide: %d faces", len(bake.faces))
	g := bake.gpu
	fmt.printfln("gpu (%s) against cpu, '&' at 22 px on %d x %d: max difference %d / 255, %d pixels of %d differ", g.driver, g.w, g.h, g.max_diff, g.differing, g.w * g.h)
	for b in bake.budgets {
		fmt.printfln("budget: every %s glyph (%d) simplified within %d of %d", b.font, b.glyphs, b.worst, cv.DEFAULT_BUDGET)
	}
	fmt.println("cpu:", bake.cpu)
}

// The glyph `r`'s contours at `size` px (em), its origin at (x, y).
glyph_contours :: proc(font: ^vg.Font, r: rune, size, x, y: f32) -> (p: vg.Path) {
	vg.font_glyph_path(font, vg.font_glyph_index(font, r), x, y, vg.font_scale_for_em(font, size), &p)
	return
}

// An SVG path of contours.
path_d :: proc(c: ^cv.Contours, first := 0, count := -1) -> string {
	count := count if count >= 0 else len(c.contours) - first
	b := strings.builder_make()
	for i in first ..< first + count {
		it := cv.contour_segments(c, i)
		started := false
		for s in cv.segments_next(&it) {
			if !started {
				fmt.sbprintf(&b, "M%.2f %.2f", s.p[0].x, s.p[0].y)
				started = true
			}
			if s.kind == .Line {
				fmt.sbprintf(&b, "L%.2f %.2f", s.p[3].x, s.p[3].y)
			} else {
				fmt.sbprintf(&b, "C%.2f %.2f %.2f %.2f %.2f %.2f", s.p[1].x, s.p[1].y, s.p[2].x, s.p[2].y, s.p[3].x, s.p[3].y)
			}
		}
		if started {
			strings.write_string(&b, "Z")
		}
	}
	return strings.to_string(b)
}

bake_shape :: proc(font: ^vg.Font) -> (s: Shape_Bake) {
	p := glyph_contours(font, '&', 620, 0, 0)
	s.outline = path_d(&p)
	s.contours = len(p.contours)
	s.segments = len(p.kinds)
	b: cv.Builder
	defer cv.builder_destroy(&b)
	cv.builder_add_contours(&b, &p, 0, len(p.contours))
	words, origin, extent, ok := cv.build(&b)
	assert(ok)
	times: [201]f64
	for &t in times {
		cv.builder_reset(&b)
		cv.builder_add_contours(&b, &p, 0, len(p.contours))
		t0 := time.tick_now()
		w, _, _, _ := cv.build(&b)
		t = time.duration_microseconds(time.tick_since(t0))
		delete(w)
	}
	slice.sort(times[:])
	s.build_us = times[100]
	// The words (curves.odin's layout): the grid, each cell's list and
	// backdrop, then the pieces, in shape units.
	f :: proc(w: u32) -> f32 {return transmute(f32)w}
	s.nx, s.ny = int(words[0]), int(words[1])
	s.cell = {f(words[2]) * extent, f(words[3]) * extent}
	s.origin = origin
	cells := s.nx * s.ny
	s.counts = make([]int, cells)
	s.backdrops = make([]int, cells)
	for k in 0 ..< cells {
		s.counts[k] = int(words[cv.HEADER + 4 * k + 1])
		s.backdrops[k] = int(cast(i32)words[cv.HEADER + 4 * k + 2])
	}
	at := int(words[6])
	n := (len(words) - at) / 6
	if words[4] != 0 {
		n = (int(words[4]) - at) / 6
	}
	s.pieces = make([]Piece, n)
	for &q, k in s.pieces {
		for i in 0 ..< 3 {
			q[2 * i] = f(words[at + 6 * k + 2 * i]) * extent + origin.x
			q[2 * i + 1] = f(words[at + 6 * k + 2 * i + 1]) * extent + origin.y
		}
	}
	return
}

bake_coverage :: proc(font: ^vg.Font) -> (c: Coverage_Bake) {
	// The glyph at 22 px, its origin a fraction off the pixel grid.
	p := glyph_contours(font, '&', 22, 2.3, 18.6)
	c.outline = path_d(&p)
	b: cv.Builder
	defer cv.builder_destroy(&b)
	cv.builder_add_contours(&b, &p, 0, len(p.contours))
	words, origin, extent, ok := cv.build(&b)
	assert(ok)
	defer delete(words)
	c.w, c.h = 22, 22
	n := c.w * c.h
	c.exact = make([]f32, n)
	c.msaa = make([]f32, n)
	c.reference = make([]f32, n)
	N :: 128
	c.samples = N * N
	// D3D's standard 4x pattern, in 16ths of a pixel from its center.
	MSAA4 :: [4][2]f32{{-2, -6}, {6, -2}, {-6, 2}, {2, 6}}
	shape :: proc(q, origin: [2]f32, extent: f32) -> [2]f32 {return (q - origin) / extent}
	t0 := time.tick_now()
	for y in 0 ..< c.h {
		for x in 0 ..< c.w {
			center := [2]f32{f32(x) + 0.5, f32(y) + 0.5}
			c.exact[y * c.w + x] = cv.coverage(words, shape(center, origin, extent), {1, 1} / extent, .Non_Zero)
		}
	}
	c.coverage_ns = f64(time.duration_nanoseconds(time.tick_since(t0))) / f64(n)
	worst_e, sum_e, worst_m, sum_m: f64
	for y in 0 ..< c.h {
		for x in 0 ..< c.w {
			center := [2]f32{f32(x) + 0.5, f32(y) + 0.5}
			inside := 0
			for j in 0 ..< N {
				for i in 0 ..< N {
					q := [2]f32{f32(x) + (f32(i) + 0.5) / N, f32(y) + (f32(j) + 0.5) / N}
					inside += 1 if cv.fill_inside(cv.winding(words, shape(q, origin, extent)), .Non_Zero) else 0
				}
			}
			m := 0
			for o in MSAA4 {
				m += 1 if cv.fill_inside(cv.winding(words, shape(center + o / 16, origin, extent)), .Non_Zero) else 0
			}
			k := y * c.w + x
			c.reference[k] = f32(inside) / f32(N * N)
			c.msaa[k] = f32(m) / 4
			e := abs(f64(c.exact[k]) - f64(c.reference[k])) * 255
			d := abs(f64(c.msaa[k]) - f64(c.reference[k])) * 255
			worst_e, sum_e = max(worst_e, e), sum_e + e
			worst_m, sum_m = max(worst_m, d), sum_m + d
		}
	}
	c.exact_max, c.exact_mean = worst_e, sum_e / f64(n)
	c.msaa_max, c.msaa_mean = worst_m, sum_m / f64(n)
	return
}

// A circle of four cubics.
circle :: proc(c: ^cv.Contours, center: [2]f32, r: f32) {
	K :: 0.5522847498
	k := r * K
	cx, cy := center.x, center.y
	cv.contours_begin(c, {cx + r, cy})
	cv.contours_cubic(c, {cx + r, cy + k}, {cx + k, cy + r}, {cx, cy + r})
	cv.contours_cubic(c, {cx - k, cy + r}, {cx - r, cy + k}, {cx - r, cy})
	cv.contours_cubic(c, {cx - r, cy - k}, {cx - k, cy - r}, {cx, cy - r})
	cv.contours_cubic(c, {cx + k, cy - r}, {cx + r, cy - k}, {cx + r, cy})
	cv.contours_end(c, true, false)
}

bake_bools :: proc(font: ^vg.Font) -> (bools: []Bool_Bake, faces: []Face_Bake, operands: [2]string) {
	// The operands, in the scene's pixels: a circle and an S across it.
	c: cv.Contours
	circle(&c, {300, 260}, 190)
	na := len(c.contours)
	sa := len(c.kinds)
	s := glyph_contours(font, 'S', 560, 300, 420)
	cv.contours_append(&c, &s, 0, len(s.contours))
	operands = {path_d(&c, 0, na), path_d(&c, na)}
	inputs := [2]cv.Bool_Input{{0, u32(na), .Non_Zero}, {u32(na), u32(len(c.contours) - na), .Non_Zero}}
	scratch: cv.Bool_Scratch
	defer cv.bool_scratch_destroy(&scratch)
	OPS :: [4]cv.Bool_Op{.Union, .Difference, .Intersection, .Xor}
	names := [4]string{"union", "difference", "intersection", "xor"}
	bools = make([]Bool_Bake, 4)
	for op, k in OPS {
		times: [51]f64
		for &t in times {
			budget := cv.DEFAULT_BUDGET
			t0 := time.tick_now()
			e := cv.bool_run(&scratch, &c, inputs[:], op, &budget)
			t = time.duration_microseconds(time.tick_since(t0))
			assert(e == .None)
		}
		slice.sort(times[:])
		r := &bools[k]
		r.op, r.run_us = names[k], times[25]
		r.fill = path_d(&scratch.out)
		segs := make([dynamic]Segment_Bake)
		for i in 0 ..< len(scratch.out.contours) {
			it := cv.contour_segments(&scratch.out, i)
			for sg in cv.segments_next(&it) {
				row := scratch.out_row[sg.index]
				src := -1 if row == max(u32) else (0 if int(row) < sa else 1)
				cubic := sg.kind == .Cubic
				d: string
				if cubic {
					d = fmt.aprintf("M%.2f %.2fC%.2f %.2f %.2f %.2f %.2f %.2f", sg.p[0].x, sg.p[0].y, sg.p[1].x, sg.p[1].y, sg.p[2].x, sg.p[2].y, sg.p[3].x, sg.p[3].y)
					r.cubics += 1
				} else {
					d = fmt.aprintf("M%.2f %.2fL%.2f %.2f", sg.p[0].x, sg.p[0].y, sg.p[3].x, sg.p[3].y)
					r.lines += 1
				}
				append(&segs, Segment_Bake{d, cubic, {sg.p[0].x, sg.p[0].y, sg.p[1].x, sg.p[1].y, sg.p[2].x, sg.p[2].y, sg.p[3].x, sg.p[3].y}, src})
			}
		}
		r.segments = segs[:]
	}
	budget := cv.DEFAULT_BUDGET
	assert(cv.bool_divide(&scratch, &c, inputs[:], &budget) == .None)
	faces = make([]Face_Bake, len(scratch.faces))
	for f, k in scratch.faces {
		faces[k] = {path_d(&scratch.out, int(f.x), int(f.y)), {scratch.faces_in[2 * k], scratch.faces_in[2 * k + 1]}}
	}
	return
}

// The coverage scene's glyph drawn by ovg on its software rasterizer (the
// CPU reads) and on SDL_GPU (curves.slang), black on white.
bake_gpu :: proc(font: ^vg.Font) -> (g: Gpu_Bake) {
	g.w, g.h = 22, 22
	draw :: proc(c: ^vg.Canvas, font: ^vg.Font, w, h: int) -> []u8 {
		vg.set_size(c, u32(w), u32(h))
		vg.clear_rect(c, 0, 0, u32(w), u32(h), vg.WHITE)
		p := glyph_contours(font, '&', 22, 2.3, 18.6)
		defer vg.path_destroy(&p)
		vg.fill_path(c, &p, vg.paint_color(vg.BLACK))
		vg.flush(c)
		shot, err := vg.screenshot(c)
		assert(err == nil)
		gray := make([]u8, w * h)
		for &v, i in gray {
			v = shot.pixels[4 * i]
		}
		return gray
	}
	sw: vg.Software_Backend
	vg.software_backend_init(&sw)
	defer vg.software_backend_destroy(&sw)
	sc: vg.Canvas
	vg.canvas_init(&sc, vg.software_backend(&sw))
	defer vg.canvas_destroy(&sc)
	g.cpu = draw(&sc, font, g.w, g.h)
	gpu: vgsdl.SDL_Backend
	if err := vgsdl.init(&gpu); err != nil {
		fmt.eprintln("bake: no GPU:", err)
		os.exit(1)
	}
	defer vgsdl.destroy(&gpu)
	g.driver = gpu_driver(&gpu)
	gc: vg.Canvas
	vg.canvas_init(&gc, vgsdl.backend(&gpu))
	defer vg.canvas_destroy(&gc)
	g.gpu = draw(&gc, font, g.w, g.h)
	for v, i in g.cpu {
		d := abs(int(v) - int(g.gpu[i]))
		g.max_diff = max(g.max_diff, d)
		g.differing += 1 if d > 0 else 0
	}
	return
}

// Every glyph of a font simplified (bool_run, one non-zero operand): the
// most budget any took.
bake_budgets :: proc() -> []Budget_Bake {
	fonts := make([dynamic]Budget_Bake)
	sources := [2]struct {
		name: string,
		data: []u8,
	}{{"Bitstream Vera Sans", vg.DEFAULT_FONT_DATA}, {"Adwaita Sans", nil}}
	if data, err := os.read_entire_file_from_path("demo/media/AdwaitaSans-Regular.ttf", context.allocator); err == nil {
		sources[1].data = data
	}
	s: cv.Bool_Scratch
	defer cv.bool_scratch_destroy(&s)
	for src in sources {
		if src.data == nil {
			fmt.eprintln("bake: no", src.name, "(demo/fetch.sh fetches it)")
			continue
		}
		font, err := vg.font_load(src.data)
		assert(err == nil)
		defer vg.font_destroy(&font)
		b := Budget_Bake{font = src.name}
		p: vg.Path
		defer vg.path_destroy(&p)
		for gi in 0 ..< font.face.glyph_count {
			vg.path_reset(&p)
			vg.font_glyph_path(&font, vg.Glyph_Index(gi), 0, 0, 1.0 / 2048, &p)
			if len(p.contours) == 0 {
				continue
			}
			input := [1]cv.Bool_Input{{0, u32(len(p.contours)), .Non_Zero}}
			budget := cv.DEFAULT_BUDGET
			e := cv.bool_run(&s, &p, input[:], .Union, &budget)
			assert(e == .None)
			b.worst = max(b.worst, cv.DEFAULT_BUDGET - budget)
			b.glyphs += 1
		}
		append(&fonts, b)
	}
	return fonts[:]
}

gpu_driver :: proc(gpu: ^vgsdl.SDL_Backend) -> string {
	return string(sdl.GetGPUDeviceDriver(gpu.device))
}

cpu_model :: proc() -> string {
	data, err := os.read_entire_file_from_path("/proc/cpuinfo", context.allocator)
	if err != nil {
		return "unknown"
	}
	for line in strings.split_lines(string(data)) {
		if strings.has_prefix(line, "model name") {
			if i := strings.index(line, ":"); i >= 0 {
				return strings.trim_space(line[i + 1:])
			}
		}
	}
	return "unknown"
}

_ :: math
