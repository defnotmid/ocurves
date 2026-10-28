-- ocurves' thumbnail for the site's project list (480 x 480, the faceless
-- projects' layout): Bez over a cubic with its handles, on the list's
-- slate.
--
--     onimite frame demo/thumb.lua 0s -o thumb.png   # from ocurves' root

local SLATE, AMBER, HANDLE, KNOT = "#26304a", "#f5a33b", "#5fd0ff", "#ffffff"
local P = { { 70, 418 }, { 170, 362 }, { 310, 466 }, { 410, 410 } }

video {
  width = 480, height = 480, fps = 1, duration = 1, background = SLATE,
  render = function(f)
    rect { x = 0, y = 0, w = 480, h = 480, fill = SLATE }
    svg { src = "bez.svg", x = 90, y = 16, w = 320, h = 320 }
    line { x1 = P[1][1], y1 = P[1][2], x2 = P[2][1], y2 = P[2][2], stroke = HANDLE, stroke_width = 3 }
    line { x1 = P[4][1], y1 = P[4][2], x2 = P[3][1], y2 = P[3][2], stroke = HANDLE, stroke_width = 3 }
    path { d = string.format("M%d %d C%d %d %d %d %d %d", P[1][1], P[1][2], P[2][1], P[2][2], P[3][1], P[3][2], P[4][1], P[4][2]),
      fill = "none", stroke = AMBER, stroke_width = 10, line_cap = "round" }
    for i, p in ipairs(P) do
      local s = (i == 1 or i == 4) and 16 or 12
      rect { x = p[1] - s / 2, y = p[2] - s / 2, w = s, h = s, fill = (i == 1 or i == 4) and KNOT or HANDLE, stroke = SLATE, stroke_width = 2 }
    end
  end,
}
