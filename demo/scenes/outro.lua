-- The wordmark with Bez, where to get it, and what it measured.

local beat = require("beat")
local ui = require("ui")
local T = require("timeline")
local F = require("facts")
local prog, snap, soft = beat.prog, beat.snap, beat.soft

local function render(f, lb)
  local s = soft(lb)
  ui.bez(220, 250 + (1 - s) * 80, 360, lb + 2, lb < 1 and "o" or nil)
  group({ transform = { scale = 0.8 + 0.2 * s, origin = { 1080, 420 } } }, function()
    text { "OCURVES", x = 1080, y = 470, align = "center", font = ui.DISPLAY, size = 240, fill = ui.TEXT }
  end)
  text { "github.com/defnotmid/ocurves", x = 1080, y = 560, align = "center", font = ui.MONO, size = 30, fill = ui.A,
    opacity = prog(lb, 0.5, 0.8) }
  local stats = {
    string.format("exact coverage · within %s of %s samples", F.EXACT_MAX, F.SAMPLES),
    "booleans keep their curves",
    string.format("bool_suite · %s", F.SUITE),
    string.format("core only · %d tests · MIT", F.TESTS),
  }
  for i, st in ipairs(stats) do
    local at = 1 + (i - 1) * 0.5
    if lb >= at then
      local w = text_width { st, font = ui.MONO, size = 22 } + 31
      ui.chip(1080 - w / 2, 610 + (i - 1) * 62, st, ui.LINE, i % 2 == 1 and ui.A or ui.B, 22, snap(lb - at))
    end
  end
  text { "made with onimite · music by odawg", x = 1080, y = 900, align = "center", font = ui.MONO, size = 18, fill = ui.DIM,
    opacity = prog(lb, 4, 4.5) }
end

return { name = "Outro", start = T.OUTRO, stop = T.TOTAL, render = render }
