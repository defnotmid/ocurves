-- A shape is its curves: the '&' drawn on, its quadratic pieces (each
-- monotone in x and y) arriving along it, then the grid of cells each
-- listing its pieces, the backdrops (the winding right of a cell) tinted.

local beat = require("beat")
local ui = require("ui")
local T = require("timeline")
local F = require("facts")
local D = require("data")
local prog, snap, expo_out = beat.prog, beat.snap, beat.expo_out

local S = D.shape
local X, Y = 300, 840 -- the glyph's origin on screen
local OUTLINE = path_data(S.outline)
local PIECES = {}
for i, q in ipairs(S.pieces) do
  PIECES[i] = path_data(string.format("M%.2f %.2fQ%.2f %.2f %.2f %.2f", q[1], q[2], q[3], q[4], q[5], q[6]))
end

local function render(f, lb)
  ui.label(lb, 2, "Shapes")
  group({ transform = translate(X, Y) }, function()
    local cells = prog(lb, 5, 6)
    if cells > 0 then
      -- the grid, its cells with a backdrop tinted, their piece counts
      for j = 0, S.ny - 1 do
        for i = 0, S.nx - 1 do
          local k = j * S.nx + i + 1
          local x, y = S.origin[1] + i * S.cell[1], S.origin[2] + j * S.cell[2]
          if S.backdrops[k] ~= 0 then
            rect { x = x, y = y, w = S.cell[1], h = S.cell[2], fill = ui.B, opacity = 0.16 * prog(lb, 7, 8) }
          end
          rect { x = x, y = y, w = S.cell[1], h = S.cell[2], fill = "none", stroke = ui.LINE, stroke_width = 1.5, opacity = cells }
          if lb >= 8.5 and S.counts[k] > 0 then
            text { tostring(S.counts[k]), x = x + S.cell[1] / 2, y = y + S.cell[2] / 2, align = "center", baseline = "middle",
              font = ui.MONO, size = 13, fill = ui.DIM, opacity = prog(lb, 8.5, 9) }
          end
        end
      end
    end
    path { d = OUTLINE, fill = ui.TEXT, fill_opacity = 0.08 * prog(lb, 1, 2), stroke = ui.TEXT, stroke_width = 2,
      path_length = 1, stroke_dasharray = { 1, 1 }, stroke_dashoffset = 1 - expo_out(prog(lb, 0, 1.6)), opacity = 1 - 0.6 * prog(lb, 2, 3) }
    -- the pieces, in order along the contours, alternating colours
    local n = math.floor(#PIECES * prog(lb, 2, 5) + 0.5)
    for i = 1, n do
      path { d = PIECES[i], fill = "none", stroke = i % 2 == 0 and ui.A or ui.B, stroke_width = 4, line_cap = "round" }
    end
  end)
  -- the account, right
  local lines = {
    { 1.0, string.format("%d %s of lines and cubics", F.SHAPE_CONTOURS, F.SHAPE_CONTOURS == 1 and "contour" or "contours") },
    { 2.5, string.format("%d quadratic pieces, each monotone in x and y", F.SHAPE_PIECES) },
    { 5.0, string.format("a %s grid: each cell lists its pieces", F.SHAPE_GRID) },
    { 7.0, "and its backdrop, the winding right of it" },
    { 9.0, string.format("built in %s, in time linear in the pieces", F.SHAPE_BUILD) },
  }
  for i, l in ipairs(lines) do
    if lb >= l[1] then
      local p = snap(lb - l[1])
      text { l[2], x = 1020 + (1 - p) * 40, y = 330 + i * 70, font = ui.SANS, size = 34, fill = i == 5 and ui.A or ui.TEXT,
        opacity = prog(lb, l[1], l[1] + 0.2) }
    end
  end
  ui.caption(lb, 10, "A pixel then reads the few pieces near it, not the whole shape.", "curves.odin: build, coverage")
end

return { name = "Shapes", start = T.SHAPES, stop = T.COVERAGE, render = render }
