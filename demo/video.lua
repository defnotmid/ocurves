-- ocurves in 40 seconds: the launch video for ocurves' page, an onimite
-- script (https://github.com/defnotmid/onimite). What it shows is baked
-- by bake/main.odin against ocurves v0.0.6 (media/bake.json; every number
-- is in facts.lua with its command), drawn by onimite (through ovg, which
-- fills with ocurves). The soundtrack is an odawg song (track.lua:
-- downtempo, a harp's arches over a jazz kit) whose pops the picture
-- follows.
--
--     onimite render demo/video.lua -o demo/demo.mp4 --qp 22   # from ocurves' root

local beat = require("beat")
local ui = require("ui")
local score = require("track")
local T = require("timeline")

local SCENES = {
  require("scenes.title"),
  require("scenes.shapes"),
  require("scenes.coverage"),
  require("scenes.booleans"),
  require("scenes.gpu"),
  (require("scenes.outro")),
}
local SECTIONS = { "01 / TITLE", "02 / SHAPES", "03 / COVERAGE", "04 / BOOLEANS", "05 / GPU TWIN", "06 / OUTRO" }

cue("impact", score.hits { part = "fx" }, { hit = "score" })
local KICK = { part = "drums", note = "kick", decay = 9 }
local IMPACT = { part = "fx", decay = 5 }

local function hud(f, b)
  if b >= T.END then return end
  local bar, q = math.floor(b / 4) + 1, math.floor(b % 4) + 1
  local section = 1
  for i, s in ipairs(SCENES) do if b >= s.start then section = i end end
  group({ opacity = 0.8 }, function()
    text { "OCURVES · CURVE GEOMETRY", x = 60, y = 66, font = ui.MONO, size = 16, fill = ui.DIM }
    text { string.format("%d BPM   BAR %02d.%d", score.sections[score.section(f).index].bpm, bar, q), x = 1830,
      y = 66, align = "right", font = ui.MONO, size = 16, fill = ui.DIM }
    rect { x = 1844, y = 53, w = 14, h = 14, fill = ui.A, opacity = 0.2 + 0.8 * beat.pulse(b, 7) }
    text { SECTIONS[section], x = 1860, y = 1050, align = "right", font = ui.MONO, size = 16, fill = ui.DIM }
    rect { x = 60, y = 1062, w = 1800, h = 1, fill = ui.LINE }
    rect { x = 60, y = 1061, w = math.max(1800 * b / T.TOTAL, 1), h = 3, fill = ui.DIM }
  end)
end

video {
  width = 1920, height = 1080, fps = beat.FPS, background = ui.BG,
  audio = { { "score", fade_out = 0.5 } },
  master_gain_db = 5, -- about -14.3 LUFS under the limiter's -2 dBTP, as the other demos (README.md)
  render = function(f)
    local b = beat.gbeat(f)
    rect { x = 0, y = 0, w = 1920, h = 1080, fill = ui.BG }
    group({ transform = { scale = 1 + score.pulse(f, KICK) * 0.005, origin = { 960, 540 } } }, function()
      render_scenes(f)
    end)
    local flash = score.pulse(f, IMPACT)
    if flash > 0.01 then rect { x = 0, y = 0, w = 1920, h = 1080, fill = ui.TEXT, opacity = flash * 0.35 } end
    hud(f, b)
  end,
}

for _, s in ipairs(SCENES) do
  local start, render = s.start, s.render
  scene { s.name, duration = { frames = beat.beat_frame(s.stop) - beat.beat_frame(start) }, render = function(f)
    render(f, beat.gbeat(f) - start)
  end }
end
