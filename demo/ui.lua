-- Palette, type and the small parts the scenes share (the sibling demos'),
-- in Bez's colours.

local beat = require("beat")

local M = {}

M.BG, M.PANEL, M.LINE = "#0b0910", "#17131f", "#2c2538"
M.TEXT, M.DIM = "#f6f1ea", "#9b91a8"
M.A, M.B, M.C = "#f5a33b", "#4fd1c5", "#ea4c6f" -- amber (the circle), teal (the S), coral
M.HANDLE = "#5fd0ff"

M.DISPLAY, M.SANS, M.MONO, M.SERIF = "Bebas Neue", "Space Grotesk", "JetBrains Mono", "Instrument Serif"

-- "#rrggbb" between two colours.
local function rgb(c) return tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) end
function M.mix(a, b, t)
  local r1, g1, b1 = rgb(a)
  local r2, g2, b2 = rgb(b)
  t = beat.clamp01(t)
  return string.format("#%02x%02x%02x", math.floor(r1 + (r2 - r1) * t + 0.5), math.floor(g1 + (g2 - g1) * t + 0.5),
    math.floor(b1 + (b2 - b1) * t + 0.5))
end
-- A grey for coverage `v` (0..1) between the background and the text.
function M.gray(v) return M.mix(M.PANEL, M.TEXT, v) end

-- A filled label, popping from its left edge; returns its width.
function M.chip(x, y, label, fill, ink, size, pop, font)
  size = size or 22
  font = font or M.MONO
  local w = text_width { label, font = font, size = size } + size * 1.4
  local h = size * 1.9
  group({ transform = { scale = pop or 1, origin = { x, y + h / 2 } } }, function()
    rect { x = x, y = y, w = w, h = h, rx = h / 2, fill = fill }
    text { label, x = x + size * 0.7, y = y + h / 2, baseline = "middle", font = font, size = size, fill = ink or M.BG }
  end)
  return w
end

-- The section label top left: "02 · Shapes", popping on its first beat.
function M.label(lb, n, s)
  M.chip(120, 120, string.format("%02d · %s", n, s), M.LINE, M.TEXT, 24, beat.snap(lb))
end

-- A caption at the bottom, rising in at beat `at`: a line and a small one.
function M.caption(lb, at, s, small)
  if lb < at then return end
  local p = beat.snap(lb - at)
  group({ opacity = beat.prog(lb, at, at + 0.2), transform = translate(0, (1 - p) * 30) }, function()
    text { s, x = 960, y = 940, align = "center", font = M.SANS, size = 40, fill = M.TEXT }
    if small then text { small, x = 960, y = 988, align = "center", font = M.MONO, size = 20, fill = M.DIM } end
  end)
end

-- Bez, the mascot, its size `s` at (x, y): blinking, tongue flicking on
-- the beat, the tail's handle nudged on every other.
function M.bez(x, y, s, lb, face)
  local flick = math.floor(lb * 2) % 2 == 0
  local blink = (lb % 8) > 7.6
  svg { src = "bez.svg", x = x, y = y, w = s, h = s, overrides = {
    tongue_a = { visible = flick }, tongue_b = { visible = not flick },
    handles_a = { visible = math.floor(lb) % 2 == 0 }, handles_b = { visible = math.floor(lb) % 2 == 1 },
    eyes_open = { visible = not blink and face ~= "o" }, eyes_closed = { visible = blink and face ~= "o" },
    eyes_o = { visible = face == "o" }, mouth_smile = { visible = face ~= "o" }, mouth_o = { visible = face == "o" },
  } }
end

return M
