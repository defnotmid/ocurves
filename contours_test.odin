package curves

import "core:math"
import "core:testing"

// A circle of four quarter cubics has area pi r^2 within the cubic
// approximation's error, positive when it winds as Solid; reversing a
// contour flips its area and the order of its kinds.
@(test)
test_contours_area_and_reverse :: proc(t: ^testing.T) {
	c: Contours
	defer contours_destroy(&c)
	K :: 0.5522848
	r: f32 = 10
	contours_begin(&c, {r, 0})
	contours_cubic(&c, {r, r * K}, {r * K, r}, {0, r})
	contours_cubic(&c, {-r * K, r}, {-r, r * K}, {-r, 0})
	contours_line(&c, {0, -r})
	contours_line(&c, {r, 0})
	contours_end(&c, true, false)
	// Half a circle plus the triangle under the two lines.
	want := f64(math.PI) * 100 / 2 + 100
	a := contours_area(&c, 0)
	testing.expectf(t, abs(abs(a) - want) < 0.05, "area %v, want %v", a, want)
	contours_reverse(&c, 0)
	testing.expect(t, abs(contours_area(&c, 0) + a) < 1e-9)
	testing.expect_value(t, c.kinds[0], Seg_Kind.Line)
	testing.expect_value(t, c.kinds[3], Seg_Kind.Cubic)
	testing.expect_value(t, c.pts[0], Vec2{r, 0})
}

// A line out and back encloses nothing, exactly, at any coordinates; an
// open contour counts its closing line. A quadratic is stored as the cubic
// it is.
@(test)
test_contours_area_exact_and_quad :: proc(t: ^testing.T) {
	c: Contours
	defer contours_destroy(&c)
	contours_begin(&c, {1e-3, 7.1})
	contours_line(&c, {3e4, -0.3})
	contours_line(&c, {1e-3, 7.1})
	contours_end(&c, true, false)
	testing.expect_value(t, contours_area(&c, 0), 0)
	contours_begin(&c, {0, 0})
	contours_line(&c, {4, 0})
	contours_line(&c, {4, 4})
	contours_end(&c, false, false)
	testing.expect_value(t, contours_area(&c, 1), -8)
	contours_begin(&c, {0, 0})
	contours_quad(&c, {3, 6}, {6, 0})
	contours_end(&c, false, false)
	testing.expect_value(t, c.kinds[len(c.kinds) - 1], Seg_Kind.Cubic)
	q := cubic_from_quad(Vec2{0, 0}, Vec2{3, 6}, Vec2{6, 0})
	testing.expect_value(t, c.pts[len(c.pts) - 3], q[1])
	testing.expect_value(t, c.pts[len(c.pts) - 2], q[2])
	testing.expect_value(t, c.pts[len(c.pts) - 1], q[3])
	// Between the parabola (peaking at y = 3) and its chord: 2/3 of 6 x 3.
	testing.expect(t, abs(abs(contours_area(&c, 2)) - 12) < 1e-4)
}
