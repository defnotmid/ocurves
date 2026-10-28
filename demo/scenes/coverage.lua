-- Coverage, zoomed in: the same small '&' as 4x MSAA's four samples see
-- it, as ocurves integrates it exactly, and as 16,384 samples a pixel
-- do; then each panel's error against the reference.

local beat = require("beat")
local ui = require("ui")
local T = require("timeline")
local F = require("facts")
local D = require("data")
local prog, snap = beat.prog, beat.snap

local C = D.coverage
local PX = 15 -- screen pixels a glyph pixel
local SIZE = C.w * PX
local GAP = 80
local X0 = (1920 - 3 * SIZE - 2 * GAP) / 2
local Y0 = 300
local OUTLINE = path_data(C.outline)
local PANELS = {
  { "4× MSAA", C.msaa, string.format("max error %s", F.MSAA_MAX), string.format("mean %s", F.MSAA_MEAN) },
  { "ocurves: exact", C.exact, string.format("max error %s", F.EXACT_MAX), string.format("mean %s", F.EXACT_MEAN) },
  { string.format("%s samples a pixel", F.SAMPLES), C.reference, "the reference", "errors against it" },
}

local function render(f, lb)
  ui.label(lb, 3, "Coverage")
  local pops = T.COVERAGE_POPS
  local err = prog(lb, pops[4] + 1, pops[4] + 2) -- the panels turn to their errors
  for k, panel in ipairs(PANELS) do
    if lb >= pops[k] then
      local x = X0 + (k - 1) * (SIZE + GAP)
      local p = snap(lb - pops[k])
      group({ transform = { scale = 0.9 + 0.1 * p, origin = { x + SIZE / 2, Y0 + SIZE / 2 } }, opacity = prog(lb, pops[k], pops[k] + 0.25) }, function()
        text { panel[1], x = x, y = Y0 - 24, font = ui.MONO, size = 22, fill = k == 2 and ui.A or ui.TEXT }
        for y = 0, C.h - 1 do
          for i = 0, C.w - 1 do
            local idx = y * C.w + i + 1
            local v = panel[2][idx]
            local fill = ui.gray(v)
            if k < 3 and err > 0 then
              local e = math.min(1, math.abs(v - C.reference[idx]) * 255 / 48)
              fill = ui.mix(fill, ui.mix(ui.PANEL, ui.C, e), err)
            end
            rect { x = x + i * PX, y = Y0 + y * PX, w = PX - 1, h = PX - 1, fill = fill }
          end
        end
        group({ transform = { translate = { x, Y0 }, scale = PX } }, function()
          path { d = OUTLINE, fill = "none", stroke = ui.B, stroke_width = 1.5 / PX, opacity = 0.7 }
        end)
      end)
      if lb >= pops[4] then
        local o = prog(lb, pops[4], pops[4] + 0.2)
        text { panel[3], x = x, y = Y0 + SIZE + 44, font = ui.MONO, size = 22, fill = k == 2 and ui.A or ui.TEXT, opacity = o }
        text { panel[4], x = x, y = Y0 + SIZE + 76, font = ui.MONO, size = 20, fill = ui.DIM, opacity = o }
      end
    end
  end
  ui.caption(lb, pops[4] + 1, "Each pixel is the area its footprint covers, in closed form: exact under any transform.",
    "Green's theorem over the cell's pieces plus the backdrop · coverage, coverage_affine")
end

return { name = "Coverage", start = T.COVERAGE, stop = T.BOOLEANS, render = render }
