package curves

import "core:slice"

// Contours of lines and cubics in one flat table: every contour's points in
// `pts` (its start point, then each segment's: a line its end, a cubic its
// two controls and its end), each segment's kind in `kinds`, a row per
// contour. Neighbours share their end point by index, so continuity is
// exact. A contour's segments are read in order (`contour_segments`), each
// as the cubic it is: a line's controls are its thirds, so readers that
// treat every segment as a cubic stay right, and readers that care about
// kinds use only its ends.

Seg_Kind :: enum u8 {
	Line,
	Cubic,
}

Contour :: struct {
	start:  u32, // index of its start point in pts
	seg:    u32, // index of its first segment in kinds
	segs:   u32,
	closed: bool,
}

Contours :: struct {
	pts:      [dynamic]Vec2,
	kinds:    [dynamic]Seg_Kind,
	contours: [dynamic]Contour,
}

// A segment of a contour: its points as the cubic it is (a line's controls
// its thirds), its kind, and its index in `kinds`.
Segment :: struct {
	p:     [4]Vec2,
	kind:  Seg_Kind,
	index: int,
}

// Reads a contour's segments in order (`segments_next`).
Segments :: struct {
	c:        ^Contours,
	at:       int, // the next segment's first point after its start
	seg, end: int, // the next segment's index, and one past the last
}

contours_init :: proc(c: ^Contours, allocator := context.allocator) {
	c^ = {}
	c.pts.allocator, c.kinds.allocator, c.contours.allocator = allocator, allocator, allocator
}

contours_destroy :: proc(c: ^Contours) {
	delete(c.pts)
	delete(c.kinds)
	delete(c.contours)
	c^ = {}
}

contours_clear :: proc(c: ^Contours) {
	clear(&c.pts)
	clear(&c.kinds)
	clear(&c.contours)
}

// Contour i's segments, in order.
contour_segments :: #force_inline proc "contextless" (c: ^Contours, i: int) -> Segments {
	ct := c.contours[i]
	return {c, int(ct.start) + 1, int(ct.seg), int(ct.seg + ct.segs)}
}

segments_next :: #force_inline proc "contextless" (it: ^Segments) -> (s: Segment, ok: bool) {
	if it.seg >= it.end {
		return
	}
	pts := it.c.pts[:]
	a := pts[it.at - 1]
	s.kind, s.index = it.c.kinds[it.seg], it.seg
	if s.kind == .Line {
		b := pts[it.at]
		s.p = {a, a + (b - a) / 3, a + (b - a) * (2.0 / 3), b}
		it.at += 1
	} else {
		s.p = {a, pts[it.at], pts[it.at + 1], pts[it.at + 2]}
		it.at += 3
	}
	it.seg += 1
	return s, true
}

// How many points contour i holds: its start and its segments'.
contour_points :: proc "contextless" (c: ^Contours, i: int) -> int {
	ct := c.contours[i]
	n := 1
	for kind in c.kinds[ct.seg:][:ct.segs] {
		n += 1 if kind == .Line else 3
	}
	return n
}

// Appends contours [first, first + count) of `src` to `dst`, each its
// points and kinds (rows may lie in any order, as bool_run's do); `src` may
// be `dst`.
contours_append :: proc(dst, src: ^Contours, first, count: int) {
	// Size, then fill: once reserved, appending moves nothing.
	np, nk := 0, 0
	for i in first ..< first + count {
		np += contour_points(src, i)
		nk += int(src.contours[i].segs)
	}
	grow(&dst.pts, np)
	grow(&dst.kinds, nk)
	grow(&dst.contours, count)
	for i in first ..< first + count {
		ct := src.contours[i]
		n := contour_points(src, i)
		append(&dst.contours, Contour{start = u32(len(dst.pts)), seg = u32(len(dst.kinds)), segs = ct.segs, closed = ct.closed})
		append(&dst.pts, ..src.pts[ct.start:][:n])
		append(&dst.kinds, ..src.kinds[ct.seg:][:ct.segs])
	}
}

// Reserves room for n more: a table appended to again and again grows
// geometrically; one filled once from empty is exact.
@(private)
grow :: proc(a: ^[dynamic]$T, n: int) {
	if len(a) + n > cap(a) {
		reserve(a, max(2 * cap(a), len(a) + n))
	}
}

// Starts a contour at p.
contours_begin :: proc(c: ^Contours, p: Vec2) {
	append(&c.contours, Contour{start = u32(len(c.pts)), seg = u32(len(c.kinds))})
	append(&c.pts, p)
}

// Appends a segment of `kind` to the open contour (a line keeps only p).
contours_segment :: proc(c: ^Contours, kind: Seg_Kind, c1, c2, p: Vec2) {
	if kind == .Line {
		append(&c.pts, p)
	} else {
		append(&c.pts, c1, c2, p)
	}
	append(&c.kinds, kind)
	c.contours[len(c.contours) - 1].segs += 1
}

contours_cubic :: proc(c: ^Contours, c1, c2, p: Vec2) {
	contours_segment(c, .Cubic, c1, c2, p)
}

// Appends the quadratic with control `ctrl` ending at p, as the cubic it is
// (cubic_from_quad; a Builder's cubic_to gets the quadratic back).
contours_quad :: proc(c: ^Contours, ctrl, p: Vec2) {
	q := cubic_from_quad(c.pts[len(c.pts) - 1], ctrl, p)
	contours_segment(c, .Cubic, q[1], q[2], q[3])
}

contours_line :: proc(c: ^Contours, p: Vec2) {
	append(&c.pts, p)
	append(&c.kinds, Seg_Kind.Line)
	c.contours[len(c.contours) - 1].segs += 1
}

// Ends the open contour, reversing it if asked.
contours_end :: proc(c: ^Contours, closed, reversed: bool) {
	c.contours[len(c.contours) - 1].closed = closed
	if reversed {
		contours_reverse(c, len(c.contours) - 1)
	}
}

// The winding of q about contours [first, first + count), an open contour
// closed by a line (as fills close it): exact, by curve_winding. `on`
// reports q on an outline, or within `on_tol` of one.
contours_winding :: proc(c: ^Contours, first, count: int, q: [2]f64, stack: ^[dynamic][2]f64, on_tol := 0.0) -> (w: i32, on: bool) {
	f :: #force_inline proc "contextless" (v: Vec2) -> [2]f64 {
		return {f64(v.x), f64(v.y)}
	}
	for i in first ..< first + count {
		it := contour_segments(c, i)
		for s in segments_next(&it) {
			cw, con := curve_winding({f(s.p[0]), f(s.p[1]), f(s.p[2]), f(s.p[3])}, q, on_tol, stack)
			w += cw
			on ||= con
		}
		if a, b := c.pts[it.at - 1], c.pts[c.contours[i].start]; a != b {
			cw, con := curve_winding({f(a), f(a + (b - a) / 3), f(a + (b - a) * (2.0 / 3)), f(b)}, q, on_tol, stack)
			w += cw
			on ||= con
		}
	}
	return
}

// The signed area contour i encloses, closed by a line when open: positive
// when it winds Solid (orient's sign). A line counts by its ends, so a line
// and its reverse cancel exactly; a cubic by cubic_area.
contours_area :: proc(c: ^Contours, i: int) -> (area: f64) {
	f :: #force_inline proc "contextless" (v: Vec2) -> [2]f64 {
		return {f64(v.x), f64(v.y)}
	}
	line :: #force_inline proc "contextless" (a, b: [2]f64) -> f64 {
		return (b.x - a.x) * (a.y + b.y) / 2
	}
	it := contour_segments(c, i)
	for s in segments_next(&it) {
		if s.kind == .Line {
			area += line(f(s.p[0]), f(s.p[3]))
		} else {
			area += cubic_area([4][2]f64{f(s.p[0]), f(s.p[1]), f(s.p[2]), f(s.p[3])})
		}
	}
	if a, b := c.pts[it.at - 1], c.pts[c.contours[i].start]; a != b {
		area += line(f(a), f(b))
	}
	return
}

// Reverses contour i in place: its points and its segments' kinds (a
// cubic's points, read backwards, are the reversed cubic's).
contours_reverse :: proc(c: ^Contours, i: int) {
	ct := c.contours[i]
	slice.reverse(c.pts[ct.start:][:contour_points(c, i)])
	slice.reverse(c.kinds[ct.seg:][:ct.segs])
}
