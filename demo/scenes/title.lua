-- A cubic draws itself on across the frame with its handles, Bez slides
-- in, then the wordmark slams in on the second bar.

local beat = require("beat")
local ui = require("ui")
local T = require("timeline")
local prog, snap, soft, expo_out = beat.prog, beat.snap, beat.soft, beat.expo_out

local P = { { 260, 760 }, { 700, 180 }, { 1220, 1000 }, { 1660, 360 } }
local CURVE = string.format("M%d %d C%d %d %d %d %d %d", P[1][1], P[1][2], P[2][1], P[2][2], P[3][1], P[3][2], P[4][1], P[4][2])
local WORD = { "OCURVES", font = ui.DISPLAY, size = 300 }

local function render(f, lb)
  local slam = T.TITLE_SLAM
  local draw = expo_out(prog(lb, 0, 2.5))
  local out = expo_out(prog(lb, slam - 0.25, slam + 0.6))
  group({ opacity = 1 - out * 0.8 }, function()
    -- the handles first, then the curve between them
    local h = prog(lb, 0, 0.6)
    line { x1 = P[1][1], y1 = P[1][2], x2 = P[2][1], y2 = P[2][2], stroke = ui.HANDLE, stroke_width = 2, opacity = h }
    line { x1 = P[4][1], y1 = P[4][2], x2 = P[3][1], y2 = P[3][2], stroke = ui.HANDLE, stroke_width = 2, opacity = h }
    for i, p in ipairs(P) do
      local k = snap(lb - (i - 1) * 0.25)
      if k > 0.05 then
        rect { x = p[1] - 9 * k, y = p[2] - 9 * k, w = 18 * k, h = 18 * k, fill = (i == 1 or i == 4) and ui.TEXT or ui.HANDLE }
      end
    end
    path { d = CURVE, fill = "none", stroke = ui.A, stroke_width = 12, line_cap = "round", path_length = 1,
      stroke_dasharray = { 1, 1 }, stroke_dashoffset = 1 - draw }
  end)
  -- Bez, sliding in from the left
  local bz = soft(lb - 0.5)
  ui.bez(-300 + 520 * bz, 300, 300, lb, lb >= slam and lb < slam + 1 and "o" or nil)

  if lb >= slam then
    local s = 1 + 0.3 * (1 - soft(lb - slam))
    group({ transform = { scale = s, origin = { 1060, 480 } } }, function()
      text { WORD[1], x = 1060, y = 560, align = "center", font = WORD.font, size = WORD.size, fill = ui.TEXT }
    end)
    local p = snap(lb - slam - 1)
    group({ opacity = prog(lb, slam + 1, slam + 1.2), transform = translate(0, (1 - p) * 30) }, function()
      text { "curves with exact pixel coverage, and booleans that keep them", x = 1060, y = 660, align = "center",
        font = ui.SANS, size = 42, fill = ui.TEXT }
    end)
    if lb >= slam + 2 then
      local label = "Odin · core only · CPU + GPU (curves.slang)"
      local w = text_width { label, font = ui.MONO, size = 22 } + 31
      ui.chip(1060 - w / 2, 730, label, ui.LINE, ui.A, 22, snap(lb - slam - 2))
    end
  end
end

return { name = "Title", start = T.TITLE, stop = T.SHAPES, render = render }
