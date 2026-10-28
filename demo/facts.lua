-- Every number on screen, with where it comes from. Most are measured by
-- the bake (media/bake.json), against ocurves v0.0.6 and ovg v0.0.52:
--
--     sh demo/fetch.sh                                   # Adwaita Sans, once
--     odin run demo/bake -collection:deps=.. -o:speed -- demo/media/bake.json
--
-- from ocurves' root, which prints them too.

local D = require("data")

local M = {}

local function n255(v) return string.format("%.2f / 255", v) end

-- The shapes scene: '&' in Instrument Serif Italic at 620 px.
M.SHAPE_CONTOURS, M.SHAPE_SEGMENTS = D.shape.contours, D.shape.segments
M.SHAPE_PIECES, M.SHAPE_GRID = #D.shape.pieces, string.format("%d × %d", D.shape.nx, D.shape.ny)
M.SHAPE_BUILD = string.format("%.0f µs", D.shape.build_us)

-- The coverage scene: '&' at 22 px, each pixel against a 128 × 128-sample
-- reference; 4x MSAA is D3D's standard pattern.
local c = D.coverage
M.SAMPLES = string.format("%d", c.samples):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
M.EXACT_MAX, M.EXACT_MEAN = n255(c.exact_max), n255(c.exact_mean)
M.MSAA_MAX, M.MSAA_MEAN = n255(c.msaa_max), n255(c.msaa_mean)

-- The booleans: a circle and an S, each result's segments with their
-- sources (Bool_Scratch.out_row).
M.BOOLS = D.bools
M.FACES = #D.faces

-- The GPU twin: the same '&' drawn by ovg's software rasterizer (ocurves'
-- coverage on the CPU) and its SDL_GPU backend (curves.slang), both at
-- ocurves v0.0.6, compared pixel for pixel.
M.GPU_MAX = string.format("%d / 255", D.gpu.max_diff)
M.GPU_DIFFER = string.format("%d of %d", D.gpu.differing, D.gpu.w * D.gpu.h)
M.GPU_DRIVER = D.gpu.driver

-- ovg's tools/bool_suite at ovg v0.0.52 / ocurves v0.0.6 (ocurves README):
--     odin build tools/bool_suite -collection:deps=.. -o:speed -out:bool_suite
--     ./bool_suite -seed:1 -cases:2000 && ./bool_suite -seed:7 -cases:2000
-- 2,000 cases, 16,000 results and 2,000 divides each: 0 errors, 0 wrong,
-- 0 overlapping, 0 with bad regions.
M.SUITE = "0 wrong in 32,000 results"

-- `odin test . -vet -strict-style` at ocurves v0.0.6.
M.TESTS = 30

return M
