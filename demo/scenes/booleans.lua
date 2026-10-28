-- Booleans that keep their curves: a circle and an S, their union,
-- difference, intersection and xor one after another, every segment of
-- each result coloured by the operand it is a range of and its cubic's
-- handles shown; then bool_divide's faces.

local beat = require("beat")
local ui = require("ui")
local T = require("timeline")
local F = require("facts")
local D = require("data")
local prog, snap = beat.prog, beat.snap

local X, Y = 330, 300 -- the operands' origin on screen
local OPERANDS = { path_data(D.operand_paths[1]), path_data(D.operand_paths[2]) }
local COLOUR = { [0] = ui.A, [1] = ui.B, [-1] = ui.C }
local RESULTS = {}
for k, b in ipairs(D.bools) do
  local segs = {}
  for i, s in ipairs(b.segments) do segs[i] = { d = path_data(s.d), cubic = s.cubic, p = s.points, source = s.source } end
  RESULTS[k] = { op = b.op, fill = path_data(b.fill), segs = segs, cubics = b.cubics, lines = b.lines }
end
local FACES = {}
for i, face in ipairs(D.faces) do
  local a, b = face.inside[1], face.inside[2]
  FACES[i] = { d = path_data(face.d), fill = a and b and ui.C or (a and ui.A or ui.B) }
end

local function render(f, lb)
  ui.label(lb, 4, "Booleans")
  local pops = T.BOOLEAN_POPS
  local k = 0
  for i = 1, 4 do if lb >= pops[i] then k = i end end
  local divide = lb >= pops[5]
  group({ transform = translate(X, Y) }, function()
    for i, o in ipairs(OPERANDS) do
      path { d = o, fill = "none", stroke = i == 1 and ui.A or ui.B, stroke_width = 2, stroke_dasharray = { 8, 8 }, opacity = 0.35 }
    end
    if divide then
      local p = snap(lb - pops[5])
      for i, face in ipairs(FACES) do
        group({ opacity = prog(lb, pops[5] + (i - 1) * 0.15, pops[5] + (i - 1) * 0.15 + 0.3) }, function()
          path { d = face.d, fill = face.fill, fill_opacity = 0.75, stroke = ui.BG, stroke_width = 6 * p }
        end)
      end
    elseif k > 0 then
      local r = RESULTS[k]
      local p = snap(lb - pops[k])
      path { d = r.fill, fill = ui.TEXT, fill_opacity = 0.07 * p }
      for _, s in ipairs(r.segs) do
        path { d = s.d, fill = "none", stroke = COLOUR[s.source], stroke_width = 6, line_cap = "round" }
        if s.cubic then
          local q = s.p
          line { x1 = q[1], y1 = q[2], x2 = q[3], y2 = q[4], stroke = ui.HANDLE, stroke_width = 1.5, opacity = 0.55 * p }
          line { x1 = q[7], y1 = q[8], x2 = q[5], y2 = q[6], stroke = ui.HANDLE, stroke_width = 1.5, opacity = 0.55 * p }
          if p > 0.05 then
            circle { cx = q[3], cy = q[4], r = 4 * p, fill = ui.HANDLE }
            circle { cx = q[5], cy = q[6], r = 4 * p, fill = ui.HANDLE }
          end
        end
        rect { x = s.p[1] - 4, y = s.p[2] - 4, w = 8, h = 8, fill = ui.TEXT }
      end
    end
  end)
  -- the account, right
  if divide then
    ui.chip(1080, 300, "bool_divide", ui.C, ui.BG, 26, snap(lb - pops[5]))
    text { string.format("%d faces, each with the operands it lies in", F.FACES), x = 1080, y = 420, font = ui.SANS, size = 34, fill = ui.TEXT,
      opacity = prog(lb, pops[5] + 0.5, pops[5] + 0.7) }
    text { "in the circle · in the S · in both", x = 1080, y = 480, font = ui.MONO, size = 22, fill = ui.DIM,
      opacity = prog(lb, pops[5] + 0.5, pops[5] + 0.7) }
  elseif k > 0 then
    local r = RESULTS[k]
    ui.chip(1080, 300, r.op, k % 2 == 1 and ui.A or ui.B, ui.BG, 26, snap(lb - pops[k]))
    text { string.format("%d segments, %d of them cubics", r.cubics + r.lines, r.cubics), x = 1080, y = 420, font = ui.SANS,
      size = 34, fill = ui.TEXT }
    text { "each a range of an operand's own line or cubic", x = 1080, y = 470, font = ui.SANS, size = 34, fill = ui.TEXT }
    group({ opacity = 0.9 }, function()
      rect { x = 1080, y = 540, w = 22, h = 6, fill = ui.A }
      text { "from the circle", x = 1114, y = 548, font = ui.MONO, size = 20, fill = ui.DIM }
      rect { x = 1320, y = 540, w = 22, h = 6, fill = ui.B }
      text { "from the S", x = 1354, y = 548, font = ui.MONO, size = 20, fill = ui.DIM }
    end)
  end
  ui.caption(lb, 1, "Every output segment says where it came from: no flattening, no refitting.",
    "bool_run: union, difference, intersection, xor of any number of operands · Bool_Scratch.out_row")
end

return { name = "Booleans", start = T.BOOLEANS, stop = T.GPU, render = render }
