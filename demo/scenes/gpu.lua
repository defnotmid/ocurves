-- The GPU twin: the coverage scene's '&' drawn by ovg's software
-- rasterizer (ocurves' coverage on the CPU) and by its SDL_GPU backend
-- (curves.slang), pixel for pixel, and how far apart they are.

local beat = require("beat")
local ui = require("ui")
local T = require("timeline")
local F = require("facts")
local D = require("data")
local prog, snap = beat.prog, beat.snap

local G = D.gpu
local PX = 18
local SIZE = G.w * PX
local GAP = 140
local X0 = (1920 - 2 * SIZE - GAP) / 2
local Y0 = 290

local function grid(x, values, lb, at)
  for y = 0, G.h - 1 do
    for i = 0, G.w - 1 do
      local v = values[y * G.w + i + 1] / 255
      local reveal = prog(lb, at + (i + y) * 0.02, at + (i + y) * 0.02 + 0.2)
      if reveal > 0 then
        rect { x = x + i * PX, y = Y0 + y * PX, w = (PX - 1) * reveal, h = PX - 1, fill = ui.mix(ui.TEXT, ui.PANEL, 1 - v) }
      end
    end
  end
end

local function render(f, lb)
  ui.label(lb, 5, "GPU twin")
  text { "CPU · ocurves' coverage", x = X0, y = Y0 - 50, font = ui.MONO, size = 22, fill = ui.TEXT }
  text { "ovg's software rasterizer", x = X0, y = Y0 - 22, font = ui.MONO, size = 18, fill = ui.DIM }
  text { "GPU · curves.slang", x = X0 + SIZE + GAP, y = Y0 - 50, font = ui.MONO, size = 22, fill = ui.TEXT }
  text { string.format("ovg's SDL_GPU backend (%s)", F.GPU_DRIVER), x = X0 + SIZE + GAP, y = Y0 - 22, font = ui.MONO, size = 18, fill = ui.DIM }
  grid(X0, G.cpu, lb, 0)
  grid(X0 + SIZE + GAP, G.gpu, lb, 0.5)
  local pops = T.GPU_POPS
  if lb >= pops[1] then
    local p = snap(lb - pops[1])
    text { "=", x = 960, y = Y0 + SIZE / 2 + 30, align = "center", font = ui.DISPLAY, size = 120 * p, fill = ui.A }
    text { string.format("max difference %s", F.GPU_MAX), x = 960, y = Y0 + SIZE + 80, align = "center", font = ui.SANS,
      size = 40, fill = ui.TEXT, opacity = prog(lb, pops[1], pops[1] + 0.2) }
  end
  if lb >= pops[2] then
    text { string.format("%s pixels differ, by one 8-bit step at most", F.GPU_DIFFER), x = 960, y = Y0 + SIZE + 130,
      align = "center", font = ui.MONO, size = 22, fill = ui.DIM, opacity = prog(lb, pops[2], pops[2] + 0.2) }
  end
  ui.caption(lb, 5, "One coverage function, twice: a shader includes curves.slang and reads the same words.",
    "both sides measured at ocurves v0.0.6 (bake/main.odin)")
end

return { name = "GPU twin", start = T.GPU, stop = T.OUTRO, render = render }
