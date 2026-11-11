// The GLSL twin of the curves package (curves.odin), in GLSL ES 3.0 as oksl
// reads it, and the same functions as curves.slang: exact coverage of a
// pixel's footprint (a box, or any parallelogram) by a shape's monotone
// quadratic pieces in a grid of cells with backdrops. The same arithmetic,
// except that a pixel's crossing pieces are integrated after the scan (see
// curves_coverage), so sums may round differently. `s` is a shape's first
// word in the host's words, which any number of shapes share; the layout is
// documented in curves.odin, and CURVES_FORMAT is its curves.FORMAT. The
// curves package ships this file as curves.GLSL.
//
// It binds nothing: the host defines how a word is read, over the buffer it
// binds, for example
//
//	layout(std430) readonly buffer Shape_Words { uint words[]; } shapeWords;
//	uint curves_word(uint i) { return shapeWords.words[i]; }
//
// Everything is highp (32-bit).

#define CURVES_FORMAT 1

uint curves_word(uint i);

float curves_f(uint i) { return uintBitsToFloat(curves_word(i)); }

vec2 curves_point(uint c, vec2 rc) {
    return vec2(curves_f(c), curves_f(c + 1u)) - rc;
}

// The cells a footprint covers (columns x, rows y, clamped to the grid) and
// the grid's size.
struct Curves_Span {
    int nx, ny, i0, i1, j0, j1;
    float y0, y1;
};

Curves_Span curves_span(uint s, vec2 rc, float x0, float x1, float y0, float y1) {
    Curves_Span g;
    g.nx = int(curves_word(s));
    g.ny = int(curves_word(s + 1u));
    float cw = curves_f(s + 2u);
    float ch = curves_f(s + 3u);
    g.i0 = clamp(int(floor((rc.x + x0) / cw)), 0, g.nx - 1);
    g.i1 = clamp(int(floor((rc.x + x1) / cw)), 0, g.nx - 1);
    g.j0 = clamp(int(floor((rc.y + y0) / ch)), 0, g.ny - 1);
    g.j1 = clamp(int(floor((rc.y + y1) / ch)), 0, g.ny - 1);
    g.y0 = y0;
    g.y1 = y1;
    return g;
}

// Row j's part of the footprint's rows (xy; the first and last rows reach
// out) and the row's own extent (zw), relative to ry.
vec4 curves_rows(uint s, Curves_Span g, int j, float ry) {
    float ch = curves_f(s + 3u);
    float rlo = float(j) * ch - ry;
    float rhi = float(j + 1) * ch - ry;
    return vec4(j == 0 ? g.y0 : max(g.y0, rlo), j == g.ny - 1 ? g.y1 : min(g.y1, rhi), rlo, rhi);
}

uint curves_cell(uint s, Curves_Span g, int i, int j) {
    return s + 12u + 4u * uint(j * g.nx + i);
}

// The integral over rows [a, b] (relative to ry) of the cell's backdrop.
float curves_backdrop_box(uint s, uint cell, float ry, float a, float b) {
    if (a >= b) return 0.0;
    int v = int(curves_word(cell + 2u));
    uint n = curves_word(cell + 3u);
    uint at = s + curves_word(cell) + curves_word(cell + 1u);
    float area = 0.0;
    float pos = a;
    for (uint k = 0u; k < n; k++) {
        float y = curves_f(at + 2u * k) - ry;
        if (y >= b) break;
        if (y > a) {
            area += float(v) * (y - pos);
            pos = y;
        }
        v += int(curves_word(at + 2u * k + 1u));
    }
    return area + float(v) * (b - pos);
}

// t in [0, 1] where a t^2 + b t + c = v, for a coordinate monotone on
// [0, 1].
float curves_solve_monotone(float a, float b, float c, float v) {
    float cc = c - v;
    if (abs(a) <= 1e-7 * abs(b)) {
        return clamp(-cc / b, 0.0, 1.0);
    }
    float d = sqrt(max(b * b - 4.0 * a * cc, 0.0));
    float q = -0.5 * (b + (b >= 0.0 ? d : -d));
    float t1 = q / a;
    float t2 = q != 0.0 ? cc / q : t1;
    float e1 = max(max(-t1, t1 - 1.0), 0.0);
    float e2 = max(max(-t2, t2 - 1.0), 0.0);
    return clamp(e1 <= e2 ? t1 : t2, 0.0, 1.0);
}

// The integral over [t0, t1] of g(t) y'(t), g = gp t^2 + gq t + gr, y' = 2 yd t + ye.
float curves_area_term(float gp, float gq, float gr, float yd, float ye, float t0, float t1) {
    float k3 = gp * yd * 0.5;
    float k2 = (gp * ye + 2.0 * gq * yd) / 3.0;
    float k1 = (gq * ye + 2.0 * gr * yd) * 0.5;
    float k0 = gr * ye;
    float g1 = ((k3 * t1 + k2) * t1 + k1) * t1 * t1 + k0 * t1;
    float g0 = ((k3 * t0 + k2) * t0 + k1) * t0 * t0 + k0 * t0;
    return g1 - g0;
}

// How a fill reads winding numbers (curves.Fill_Rule, in its order): inside
// where the winding is non-zero, or where it is odd.
const int CURVES_NON_ZERO = 0;
const int CURVES_EVEN_ODD = 1;

bool curves_fill_inside(int w, int rule) {
    return rule == CURVES_EVEN_ODD ? (w & 1) != 0 : w != 0;
}

float curves_fill(float area, int rule) {
    float cov = abs(area);
    if (rule == CURVES_EVEN_ODD) {
        return 1.0 - abs(1.0 - (cov * 0.5 - floor(cov * 0.5)) * 2.0);
    }
    return min(cov, 1.0);
}

// A curve as polynomials: x(t) = A t^2 + B t + C, y(t) = D t^2 + E t + F.
struct Curves_Quadratic {
    float A, B, C, D, E, F;
};

Curves_Quadratic curves_quadratic(vec2 p1, vec2 p2, vec2 p3) {
    Curves_Quadratic q;
    q.A = p1.x - 2.0 * p2.x + p3.x;
    q.B = 2.0 * (p2.x - p1.x);
    q.C = p1.x;
    q.D = p1.y - 2.0 * p2.y + p3.y;
    q.E = 2.0 * (p2.y - p1.y);
    q.F = p1.y;
    return q;
}

// `q` as a polynomial in s = t - t0.
Curves_Quadratic curves_from(Curves_Quadratic q, float t0) {
    Curves_Quadratic r;
    r.A = q.A;
    r.B = 2.0 * q.A * t0 + q.B;
    r.C = (q.A * t0 + q.B) * t0 + q.C;
    r.D = q.D;
    r.E = 2.0 * q.D * t0 + q.E;
    r.F = (q.D * t0 + q.E) * t0 + q.F;
    return r;
}

// The area a piece [t0, t1] of a curve adds to the box [x0, x1], the part
// inside in a parameter starting at t0 (as curves_affine_curve's).
float curves_box_piece(Curves_Quadratic q, float x0, float x1, float t0, float t1) {
    if (t1 <= t0) return 0.0;
    float tm = (t0 + t1) * 0.5;
    float xm = (q.A * tm + q.B) * tm + q.C;
    if (xm <= x0) return 0.0;
    if (xm >= x1) return (x1 - x0) * (((q.D * t1 + q.E) * t1 + q.F) - ((q.D * t0 + q.E) * t0 + q.F));
    Curves_Quadratic r = curves_from(q, t0);
    return curves_area_term(r.A, r.B, r.C - x0, r.D, r.E, 0.0, t1 - t0);
}

// The area a curve crossing the box adds over its rows [ca, cb].
float curves_box_curve(uint c, vec2 rc, float ca, float cb, float x0, float x1) {
    vec2 p1 = curves_point(c, rc);
    vec2 p2 = curves_point(c + 2u, rc);
    vec2 p3 = curves_point(c + 4u, rc);
    Curves_Quadratic q = curves_quadratic(p1, p2, p3);
    float ta = curves_solve_monotone(q.D, q.E, q.F, ca);
    float tb = curves_solve_monotone(q.D, q.E, q.F, cb);
    float tlo = min(ta, tb);
    float thi = max(ta, tb);
    float xa = (q.A * tlo + q.B) * tlo + q.C;
    float xb = (q.A * thi + q.B) * thi + q.C;
    float xlo = min(xa, xb);
    float xhi = max(xa, xb);
    if (xhi <= x0) return 0.0;
    if (xlo >= x1) return (p3.y > p1.y ? x1 - x0 : x0 - x1) * (cb - ca);
    float s1 = thi;
    float s2 = thi;
    if (x0 > xlo && x0 < xhi) s1 = clamp(curves_solve_monotone(q.A, q.B, q.C, x0), tlo, thi);
    if (x1 > xlo && x1 < xhi) s2 = clamp(curves_solve_monotone(q.A, q.B, q.C, x1), tlo, thi);
    float lo = min(s1, s2);
    float hi = max(s1, s2);
    return curves_box_piece(q, x0, x1, tlo, lo) + curves_box_piece(q, x0, x1, lo, hi) + curves_box_piece(q, x0, x1, hi, thi);
}

// Exact coverage of the axis-aligned box `footprint` centered at `rc`: a
// pixel without rotation or skew (curves_coverage_affine for the others).
// Its cells' pieces wholly right of it are summed as found and the few
// crossing it kept, integrated after: pixels running together then
// integrate together instead of each stalling the others' scans.
float curves_coverage(uint s, vec2 rc, vec2 footprint, int rule) {
    float fx = footprint.x;
    float fy = footprint.y;
    if (fx <= 0.0 || fy <= 0.0) return 0.0;
    float x0 = -0.5 * fx;
    float x1 = 0.5 * fx;
    Curves_Span g = curves_span(s, rc, x0, x1, -0.5 * fy, 0.5 * fy);
    uint curves = s + curves_word(s + 6u);
    float area = 0.0;
    // Up to two crossing pieces: word offsets and rows.
    uint kept[2];
    float kept_a[2];
    float kept_b[2];
    int n = 0;
    for (int j = g.j0; j <= g.j1; j++) {
        vec4 rows = curves_rows(s, g, j, rc.y);
        if (rows.x >= rows.y) continue;
        for (int i = g.i0; i <= g.i1; i++) {
            uint cell = curves_cell(s, g, i, j);
            uint list = s + curves_word(cell);
            uint count = curves_word(cell + 1u);
            for (uint k = 0u; k < count; k++) {
                uint c = curves + 6u * curves_word(list + k);
                float x1c = curves_f(c) - rc.x;
                float y1c = curves_f(c + 1u) - rc.y;
                float x3c = curves_f(c + 4u) - rc.x;
                float y3c = curves_f(c + 5u) - rc.y;
                float ca = max(rows.x, min(y1c, y3c));
                float cb = min(rows.y, max(y1c, y3c));
                if (ca >= cb || max(x1c, x3c) <= x0) continue;
                if (min(x1c, x3c) >= x1) {
                    area += (y3c > y1c ? fx : -fx) * (cb - ca);
                } else if (n < 2) {
                    kept[n] = c;
                    kept_a[n] = ca;
                    kept_b[n] = cb;
                    n++;
                } else {
                    area += curves_box_curve(c, rc, ca, cb, x0, x1);
                }
            }
        }
        area += fx * curves_backdrop_box(s, curves_cell(s, g, g.i1, j), rc.y, max(rows.x, rows.z), min(rows.y, rows.w));
    }
    for (int i = 0; i < n; i++) {
        area += curves_box_curve(kept[i], rc, kept_a[i], kept_b[i], x0, x1);
    }
    return curves_fill(area / (fx * fy), rule);
}

// A pixel's parallelogram footprint centered on the origin (see Footprint
// in curves.odin): corners at heights -h0, -h1, h1, h0; long sides of slope
// s1 with intercepts c1, c2, short sides of slope s2 with c3, c4.
struct Curves_Footprint {
    float h0, h1, s1, s2, c1, c2, c3, c4, width, xmin, xmax;
};

bool curves_footprint_parallelogram(vec2 u, vec2 v, out Curves_Footprint fp) {
    vec2 d1 = 0.5 * (u + v);
    vec2 d2 = 0.5 * (u - v);
    if (abs(d1.y) < abs(d2.y)) {
        vec2 tt = d1;
        d1 = d2;
        d2 = tt;
    }
    vec2 b = d1.y <= 0.0 ? d1 : -d1;
    vec2 p = d2.y <= 0.0 ? d2 : -d2;
    fp.h0 = -b.y;
    fp.h1 = -p.y;
    fp.s1 = 0.0;
    fp.s2 = 0.0;
    if (fp.h0 <= 0.0) {
        fp.c1 = 0.0;
        fp.c2 = 0.0;
        fp.c3 = 0.0;
        fp.c4 = 0.0;
        fp.width = 0.0;
        fp.xmin = 0.0;
        fp.xmax = 0.0;
        return false;
    }
    fp.s1 = (-p.x - b.x) / (fp.h1 + fp.h0);
    if (fp.h0 > fp.h1) fp.s2 = (p.x - b.x) / (fp.h0 - fp.h1);
    fp.c1 = b.x + fp.h0 * fp.s1;
    fp.c2 = p.x + fp.h1 * fp.s1;
    fp.c3 = b.x + fp.h0 * fp.s2;
    fp.c4 = -p.x - fp.h1 * fp.s2;
    fp.width = abs(fp.c2 - fp.c1);
    fp.xmin = min(min(b.x, p.x), min(-b.x, -p.x));
    fp.xmax = max(max(b.x, p.x), max(-b.x, -p.x));
    return fp.width > 0.0;
}

// The footprint's area below row y.
float curves_width_below(Curves_Footprint fp, float y) {
    if (y <= -fp.h0) return 0.0;
    float total = fp.width * (fp.h0 + fp.h1);
    if (y >= fp.h0) return total;
    if (y < -fp.h1) {
        float d = y + fp.h0;
        return 0.5 * fp.width * d * d / (fp.h0 - fp.h1);
    }
    if (y <= fp.h1) return 0.5 * fp.width * (fp.h0 - fp.h1) + fp.width * (y + fp.h1);
    float d = fp.h0 - y;
    return total - 0.5 * fp.width * d * d / (fp.h0 - fp.h1);
}

// Four values in ascending order (a sorting network).
vec4 curves_sort4(float w, float x, float y, float z) {
    float a = min(w, x);
    float b = max(w, x);
    float c = min(y, z);
    float d = max(y, z);
    float a2 = min(a, c);
    float c2 = max(a, c);
    float b2 = min(b, d);
    float d2 = max(b, d);
    return vec4(a2, min(b2, c2), max(b2, c2), d2);
}

// The real roots of a t^2 + b t + c in (lo, hi); `hi` stands for each one
// missing.
vec2 curves_roots_between(float a, float b, float c, float lo, float hi) {
    vec2 r = vec2(hi, hi);
    float glo = (a * lo + b) * lo + c;
    float ghi = (a * hi + b) * hi + c;
    float vertex = a != 0.0 ? -b / (2.0 * a) : lo;
    if ((glo > 0.0) == (ghi > 0.0) && !(vertex > lo && vertex < hi)) return r;
    if (abs(a) <= 1e-9 * (abs(b) + abs(c))) {
        if (b != 0.0) {
            float t = -c / b;
            if (t > lo && t < hi) r.x = t;
        }
        return r;
    }
    float disc = b * b - 4.0 * a * c;
    if (disc < 0.0) return r;
    float d = sqrt(disc);
    float q = -0.5 * (b + (b >= 0.0 ? d : -d));
    float t1 = q / a;
    if (t1 > lo && t1 < hi) r.x = t1;
    if (q != 0.0) {
        float t2 = c / q;
        if (t2 > lo && t2 < hi) r.y = t2;
    }
    return r;
}

float curves_footprint_span(Curves_Footprint fp, Curves_Quadratic q, float ac, float as_, float bc, float bs, float t0, float t1) {
    if (t1 <= t0) return 0.0;
    float tm = (t0 + t1) * 0.5;
    float xm = (q.A * tm + q.B) * tm + q.C;
    float ym = (q.D * tm + q.E) * tm + q.F;
    if (xm <= ac + as_ * ym) return 0.0;
    if (xm >= bc + bs * ym) {
        return curves_width_below(fp, (q.D * t1 + q.E) * t1 + q.F) - curves_width_below(fp, (q.D * t0 + q.E) * t0 + q.F);
    }
    return curves_area_term(q.A - as_ * q.D, q.B - as_ * q.E, q.C - ac - as_ * q.F, q.D, q.E, t0, t1);
}

// The area the curve's stretch [ta, tb] adds within piece k (0 bottom, 1
// middle, 2 top) of the footprint.
float curves_footprint_piece(Curves_Footprint fp, int k, Curves_Quadratic q, float ta, float tb) {
    float t0 = min(ta, tb);
    float t1 = max(ta, tb);
    if (t1 <= t0) return 0.0;
    float ac = k == 2 ? fp.c2 : fp.c1;
    float as_ = fp.s1;
    float bc = k == 0 ? fp.c3 : (k == 1 ? fp.c2 : fp.c4);
    float bs = k == 1 ? fp.s1 : fp.s2;
    float y0 = (q.D * t0 + q.E) * t0 + q.F;
    float y1 = (q.D * t1 + q.E) * t1 + q.F;
    float ym = 0.5 * (y0 + y1);
    if (ac + as_ * ym > bc + bs * ym) {
        float tc = ac;
        ac = bc;
        bc = tc;
        float ts = as_;
        as_ = bs;
        bs = ts;
    }
    float xa = (q.A * t0 + q.B) * t0 + q.C;
    float xb = (q.A * t1 + q.B) * t1 + q.C;
    if (max(xa, xb) <= min(ac + as_ * y0, ac + as_ * y1)) return 0.0;
    if (min(xa, xb) >= max(bc + bs * y0, bc + bs * y1)) {
        return curves_width_below(fp, y1) - curves_width_below(fp, y0);
    }
    vec2 l = curves_roots_between(q.A - as_ * q.D, q.B - as_ * q.E, q.C - ac - as_ * q.F, t0, t1);
    vec2 r = curves_roots_between(q.A - bs * q.D, q.B - bs * q.E, q.C - bc - bs * q.F, t0, t1);
    vec4 t = curves_sort4(l.x, l.y, r.x, r.y);
    float area = curves_footprint_span(fp, q, ac, as_, bc, bs, t0, t.x);
    area += curves_footprint_span(fp, q, ac, as_, bc, bs, t.x, t.y);
    area += curves_footprint_span(fp, q, ac, as_, bc, bs, t.y, t.z);
    area += curves_footprint_span(fp, q, ac, as_, bc, bs, t.z, t.w);
    area += curves_footprint_span(fp, q, ac, as_, bc, bs, t.w, t1);
    return area;
}

// The integral over rows [a, b] (relative to ry) of the cell's backdrop
// times the footprint's slice widths.
float curves_backdrop_fp(uint s, uint cell, float ry, float a, float b, Curves_Footprint fp) {
    if (a >= b) return 0.0;
    int v = int(curves_word(cell + 2u));
    uint n = curves_word(cell + 3u);
    uint at = s + curves_word(cell) + curves_word(cell + 1u);
    float area = 0.0;
    float pos = a;
    for (uint k = 0u; k < n; k++) {
        float y = curves_f(at + 2u * k) - ry;
        if (y >= b) break;
        if (y > a) {
            area += float(v) * (curves_width_below(fp, y) - curves_width_below(fp, pos));
            pos = y;
        }
        v += int(curves_word(at + 2u * k + 1u));
    }
    return area + float(v) * (curves_width_below(fp, b) - curves_width_below(fp, pos));
}

// The area a curve crossing the footprint adds over its rows [ca, cb]: its
// parameters at the rows' ends and where they cross the pieces'
// boundaries (no solve where those coincide), then each piece.
float curves_affine_curve(uint c, vec2 rc, Curves_Footprint fp, float ca, float cb) {
    Curves_Quadratic q = curves_quadratic(curves_point(c, rc), curves_point(c + 2u, rc), curves_point(c + 4u, rc));
    float ta = curves_solve_monotone(q.D, q.E, q.F, ca);
    float tb = curves_solve_monotone(q.D, q.E, q.F, cb);
    float y1 = clamp(-fp.h1, ca, cb);
    float y2 = clamp(fp.h1, ca, cb);
    float t1 = y1 == ca ? ta : (y1 == cb ? tb : curves_solve_monotone(q.D, q.E, q.F, y1));
    float t2 = y2 == ca ? ta : (y2 == cb ? tb : curves_solve_monotone(q.D, q.E, q.F, y2));
    // Each piece in a parameter starting at its stretch (see affine_curve).
    return curves_footprint_piece(fp, 0, curves_from(q, ta), 0.0, t1 - ta) + curves_footprint_piece(fp, 1, curves_from(q, t1), 0.0, t2 - t1) + curves_footprint_piece(fp, 2, curves_from(q, t2), 0.0, tb - t2);
}

// Exact coverage of the parallelogram rc + a u + b v, a, b in [-1/2, 1/2]
// (u, v: dFdx(rc), dFdy(rc), or the inverse transform's columns).
float curves_coverage_affine(uint s, vec2 rc, vec2 u, vec2 v, int rule) {
    if (u.y == 0.0 && v.x == 0.0) {
        return curves_coverage(s, rc, vec2(abs(u.x), abs(v.y)), rule);
    }
    Curves_Footprint fp;
    if (!curves_footprint_parallelogram(u, v, fp)) return 0.0;
    Curves_Span g = curves_span(s, rc, fp.xmin, fp.xmax, -fp.h0, fp.h0);
    uint curves = s + curves_word(s + 6u);
    float area = 0.0;
    // Up to two crossing pieces, integrated after the scan (as curves_coverage).
    uint kept[2];
    float kept_a[2];
    float kept_b[2];
    int n = 0;
    for (int j = g.j0; j <= g.j1; j++) {
        vec4 rows = curves_rows(s, g, j, rc.y);
        if (rows.x >= rows.y) continue;
        for (int i = g.i0; i <= g.i1; i++) {
            uint cell = curves_cell(s, g, i, j);
            uint list = s + curves_word(cell);
            uint count = curves_word(cell + 1u);
            for (uint k = 0u; k < count; k++) {
                uint c = curves + 6u * curves_word(list + k);
                float x1c = curves_f(c) - rc.x;
                float y1c = curves_f(c + 1u) - rc.y;
                float x3c = curves_f(c + 4u) - rc.x;
                float y3c = curves_f(c + 5u) - rc.y;
                float ca = max(rows.x, min(y1c, y3c));
                float cb = min(rows.y, max(y1c, y3c));
                if (ca >= cb || max(x1c, x3c) <= fp.xmin) continue;
                if (min(x1c, x3c) >= fp.xmax) {
                    area += (y3c > y1c ? 1.0 : -1.0) * (curves_width_below(fp, cb) - curves_width_below(fp, ca));
                } else if (n < 2) {
                    kept[n] = c;
                    kept_a[n] = ca;
                    kept_b[n] = cb;
                    n++;
                } else {
                    area += curves_affine_curve(c, rc, fp, ca, cb);
                }
            }
        }
        area += curves_backdrop_fp(s, curves_cell(s, g, g.i1, j), rc.y, max(rows.x, rows.z), min(rows.y, rows.w), fp);
    }
    for (int i = 0; i < n; i++) {
        area += curves_affine_curve(kept[i], rc, fp, kept_a[i], kept_b[i]);
    }
    return curves_fill(area / (fp.width * (fp.h0 + fp.h1)), rule);
}

// The per-axis extent of the footprint from the shape coordinate's screen
// derivatives (dFdx(rc), dFdy(rc)): fwidth.
vec2 curves_footprint(vec2 dx, vec2 dy) {
    return abs(dx) + abs(dy);
}

// The winding number at `p` (shape units): signed crossings of the ray
// toward +x (non-zero: != 0; even-odd: odd). For sample masks.
int curves_winding(uint s, vec2 p) {
    if (p.x >= curves_f(s + 10u) || p.y < 0.0 || p.y >= curves_f(s + 11u)) return 0;
    Curves_Span g = curves_span(s, p, 0.0, 0.0, 0.0, 0.0);
    uint cell = curves_cell(s, g, g.i0, g.j0);
    // The backdrop at p.y, then the cell's pieces right of p.
    int w = int(curves_word(cell + 2u));
    uint at = s + curves_word(cell) + curves_word(cell + 1u);
    uint steps = curves_word(cell + 3u);
    for (uint k = 0u; k < steps; k++) {
        if (curves_f(at + 2u * k) <= p.y) w += int(curves_word(at + 2u * k + 1u));
    }
    uint curves = s + curves_word(s + 6u);
    uint list = s + curves_word(cell);
    uint count = curves_word(cell + 1u);
    for (uint k = 0u; k < count; k++) {
        uint c = curves + 6u * curves_word(list + k);
        vec2 p1 = curves_point(c, p);
        vec2 p2 = curves_point(c + 2u, p);
        vec2 p3 = curves_point(c + 4u, p);
        float lo = min(p1.y, p3.y);
        float hi = max(p1.y, p3.y);
        if (0.0 < lo || 0.0 >= hi || max(p1.x, p3.x) <= 0.0) continue;
        float t = curves_solve_monotone(p1.y - 2.0 * p2.y + p3.y, 2.0 * (p2.y - p1.y), p1.y, 0.0);
        if (((p1.x - 2.0 * p2.x + p3.x) * t + 2.0 * (p2.x - p1.x)) * t + p1.x > 0.0) {
            w += p3.y > p1.y ? 1 : -1;
        }
    }
    return w;
}

// The share of the unit pixel at the origin (pixel units) within w / 2 of
// the line through the quadratic's point nearest it, across the normal
// there (curves.odin's band_coverage).
float curves_projected_box(float x, float a, float b) {
    float s1 = 0.5 * (a + b);
    float s2 = 0.5 * (a - b);
    float y = clamp(x, -s1, s1);
    float q1 = max(y + s1, 0.0);
    float q2 = max(y + s2, 0.0);
    float q3 = max(y - s2, 0.0);
    float q4 = max(y - s1, 0.0);
    return (q1 * q1 - q2 * q2 - q3 * q3 + q4 * q4) / (2.0 * a * b);
}

float curves_band_coverage(vec2 p1, vec2 p2, vec2 p3, float w) {
    vec2 a = p1 - 2.0 * p2 + p3;
    vec2 b = 2.0 * (p2 - p1);
    vec2 chord = p3 - p1;
    float l2 = dot(chord, chord);
    if (l2 == 0.0 && a == vec2(0.0, 0.0)) return 0.0;
    float t = l2 > 0.0 ? clamp(-dot(p1, chord) / l2, 0.0, 1.0) : 0.0;
    // A piece within 1/400 pixel of its chord (|a| / 4 apart at most) is
    // taken as its chord, whose nearest point is in closed form, so the
    // normal there is the chord's; any other gets Newton's.
    vec2 q = p1 + chord * t;
    if (dot(a, a) > 1e-4) {
        for (int k = 0; k < 3; k++) {
            vec2 qk = (a * t + b) * t + p1;
            vec2 dq = 2.0 * a * t + b;
            float f = dot(qk, dq);
            float fp = dot(dq, dq) + 2.0 * dot(qk, a);
            if (fp > 0.0) t = clamp(t - f / fp, 0.0, 1.0);
        }
        q = (a * t + b) * t + p1;
    }
    float d2 = dot(q, q);
    float reach = 0.5 * w + 0.7072;
    if (d2 >= reach * reach) return 0.0;
    float d = sqrt(d2);
    vec2 n = q / d;
    if (!(d > 1e-6)) {
        vec2 dq = 2.0 * a * t + b;
        // Where the curve stops it runs along `a`: B(t) = B(t*) + a (t - t*)^2.
        if (dot(dq, dq) == 0.0) dq = a;
        n = vec2(-dq.y, dq.x) / sqrt(dot(dq, dq));
    }
    float wa = max(abs(n.x), abs(n.y));
    float wb = max(min(abs(n.x), abs(n.y)), 1e-3);
    return clamp(curves_projected_box(d + 0.5 * w, wa, wb) - curves_projected_box(d - 0.5 * w, wa, wb), 0.0, 1.0);
}

// The coverage of the pixel at `rc` (sides u, v in shape units) by the
// shape's outline `width` pixels wide (curves.odin's hairline); 0 without
// an outline.
float curves_hairline(uint s, vec2 rc, vec2 u, vec2 v, float width) {
    uint outline = curves_word(s + 4u);
    float det = u.x * v.y - u.y * v.x;
    if (outline == 0u || det == 0.0 || !(width > 0.0)) return 0.0;
    vec4 m = vec4(v.y, -u.y, -v.x, u.x) / det;
    float reach = 0.5 * width + 0.7072;
    float ex = reach * (abs(u.x) + abs(v.x));
    float ey = reach * (abs(u.y) + abs(v.y));
    Curves_Span g = curves_span(s, rc, -ex, ex, -ey, ey);
    uint curves = s + curves_word(s + 6u);
    float cov = 0.0;
    for (int j = g.j0; j <= g.j1; j++) {
        for (int i = g.i0; i <= g.i1; i++) {
            uint cell = s + outline + 2u * uint(j * g.nx + i);
            uint list = s + curves_word(cell);
            uint count = curves_word(cell + 1u);
            for (uint k = 0u; k < count; k++) {
                uint c = curves + 6u * curves_word(list + k);
                vec2 p1 = curves_point(c, rc);
                vec2 p3 = curves_point(c + 4u, rc);
                if (min(p1.x, p3.x) > ex || max(p1.x, p3.x) < -ex || min(p1.y, p3.y) > ey || max(p1.y, p3.y) < -ey) continue;
                vec2 p2 = curves_point(c + 2u, rc);
                vec2 a1 = vec2(m.x * p1.x + m.z * p1.y, m.y * p1.x + m.w * p1.y);
                vec2 a2 = vec2(m.x * p2.x + m.z * p2.y, m.y * p2.x + m.w * p2.y);
                vec2 a3 = vec2(m.x * p3.x + m.z * p3.y, m.y * p3.x + m.w * p3.y);
                cov = max(cov, curves_band_coverage(a1, a2, a3, width));
            }
        }
    }
    return cov;
}

// The coverage of the pixel at `rc` by a marker (curves.odin's marker): in
// its own units the square [-1, 1]^2 or the unit circle, u and v the
// pixel's sides there, drawn unrotated; filled, or with `outline` > 0 a
// ring that many pixels wide on its edge.
float curves_marker(bool circle, vec2 rc, vec2 u, vec2 v, float outline) {
    float det = u.x * v.y - u.y * v.x;
    if (det == 0.0) return 0.0;
    vec2 d = vec2(v.y * rc.x - v.x * rc.y, u.x * rc.y - u.y * rc.x) / det;
    float r = sqrt(v.y * v.y + u.y * u.y) / abs(det);
    float h = 0.5 * outline;
    if (circle) {
        float dist = sqrt(dot(d, d));
        vec2 n = dist > 1e-6 ? d / dist : vec2(1.0, 0.0);
        float wa = max(abs(n.x), abs(n.y));
        float wb = max(min(abs(n.x), abs(n.y)), 1e-3);
        if (outline > 0.0) {
            return clamp(curves_projected_box(r + h - dist, wa, wb) - curves_projected_box(r - h - dist, wa, wb), 0.0, 1.0);
        }
        return curves_projected_box(r - dist, wa, wb);
    }
    vec2 a = vec2(r + h, r + h);
    float ox = clamp(min(d.x + 0.5, a.x) - max(d.x - 0.5, -a.x), 0.0, 1.0);
    float oy = clamp(min(d.y + 0.5, a.y) - max(d.y - 0.5, -a.y), 0.0, 1.0);
    if (outline > 0.0) {
        float b = max(r - h, 0.0);
        float ix = clamp(min(d.x + 0.5, b) - max(d.x - 0.5, -b), 0.0, 1.0);
        float iy = clamp(min(d.y + 0.5, b) - max(d.y - 0.5, -b), 0.0, 1.0);
        return ox * oy - ix * iy;
    }
    return ox * oy;
}
