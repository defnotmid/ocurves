-- The soundtrack: an odawg song, downtempo after Bonobo's "Kiara" (Black
-- Sands, 2010). Why: ocurves is curves, and that record is built of them:
-- a harp's figure rising and falling over a laid-back kit, strings
-- swelling in, a breakdown before the last lift. Its decisions, followed:
-- 96 BPM in D minor; the harp alone first, its sixteenths climbing a chord
-- and coming back down every bar (an arch, the picture's curve); a jazz
-- kit's cross-stick groove entering with the shapes, its snare backbeat
-- with the booleans; a fingered bass and a soft grand under it; string
-- sections from the coverage on; the drums dropping to hats under the GPU
-- scene, back for the outro. The picture answers the notes (timeline.lua):
-- the glockenspiel's notes are its pops, the timpani its impacts, the
-- kick its pulse.
--
-- Instruments: VS Chamber Orchestra 2's own SFZ files (harp, glockenspiel,
-- timpani; CC0), fetched from its repository at a pinned commit and checked
-- against media/pins/vsco.pins (`onimite audio pin demo/video.lua`), and
-- odawg's CC0 sets: Osiris's soft grand, Karoryfer's fingered bass, the
-- Virtuosity jazz kit and VSCO 2's string sections. Levels by
-- measurement: each part in its role's band of LU under the mix
-- (`onimite audio parts demo/video.lua`).

local VSCO = {
  url = "https://raw.githubusercontent.com/sgossner/VSCO-2-CE/6dd651d55dde97fd4028699be9d4481f26917891/",
  page = "https://github.com/sgossner/VSCO-2-CE/tree/SFZ",
  licence = "CC0-1.0",
  credit = "VS Chamber Orchestra 2: Community Edition by Versilian Studios LLC (Sam Gossner, Simon Dalzell, Elan Hickler), CC0 1.0",
  pins = "pins/vsco.pins",
}

local function at(bar, quarter, sixteenth) return string.format("%d:%d:%d", bar, quarter, sixteenth) end

-- Each chord as the harp spreads it, nine tones low to high.
local HARP = {
  Dm9 = { "D3", "A3", "C4", "E4", "F4", "A4", "C5", "E5", "F5" },
  Bbmaj7 = { "Bb2", "F3", "A3", "D4", "F4", "A4", "D5", "F5", "A5" },
  Gm9 = { "G2", "D3", "F3", "A3", "Bb3", "D4", "F4", "A4", "Bb4" },
  Fmaj7 = { "F2", "C3", "E3", "A3", "C4", "E4", "A4", "C5", "E5" },
  A7sus4 = { "A2", "E3", "G3", "A3", "D4", "E4", "G4", "A4", "D5" },
  A7 = { "A2", "E3", "G3", "C#4", "E4", "G4", "A4", "C#5", "E5" },
}

-- The harp's arch: a bar of sixteenths up a chord's tones and back down,
-- one chord a bar, the top of each arch the strongest.
local function arches(chords, v)
  local ev = {}
  for bar, name in ipairs(chords) do
    local tones = HARP[name]
    for i = 0, 15 do
      local k = i < 8 and i + 1 or 17 - i
      local lift = 0.12 * math.sin(math.pi * i / 16)
      ev[#ev + 1] = { time = at(bar - 1, i // 4, i % 4), note = tones[k], duration = "8n", velocity = v + lift }
    end
  end
  return ev
end

-- The piano's comp: the chord held from the downbeat, touched again on
-- the "and" of three.
local PIANO = {
  Dm9 = { "F3", "A3", "C4", "E4" }, Bbmaj7 = { "F3", "A3", "D4" }, Gm9 = { "F3", "Bb3", "D4", "A4" },
  Fmaj7 = { "E3", "A3", "C4" }, A7sus4 = { "G3", "A3", "D4" }, A7 = { "G3", "C#4", "E4" },
}
local function comp(chords, v)
  local ev = {}
  for bar, name in ipairs(chords) do
    for _, n in ipairs(PIANO[name]) do
      ev[#ev + 1] = { time = at(bar - 1, 0, 0), note = n, duration = "2n.", velocity = v }
      ev[#ev + 1] = { time = at(bar - 1, 2, 2), note = n, duration = "8n", velocity = v * 0.7 }
    end
  end
  return ev
end

-- The bass: the root on the downbeat and pushed into the third beat, the
-- fifth leading back.
local ROOT = { Dm9 = { "D2", "A2" }, Bbmaj7 = { "Bb1", "F2" }, Gm9 = { "G1", "D2" }, Fmaj7 = { "F1", "C2" },
  A7sus4 = { "A1", "E2" }, A7 = { "A1", "E2" } }
local function walk(chords, v)
  local ev = {}
  for bar, name in ipairs(chords) do
    local r = ROOT[name]
    ev[#ev + 1] = { time = at(bar - 1, 0, 0), note = r[1], duration = "4n.", velocity = v + 0.1 }
    ev[#ev + 1] = { time = at(bar - 1, 1, 3), note = r[1], duration = "8n", velocity = v }
    ev[#ev + 1] = { time = at(bar - 1, 3, 2), note = r[2], duration = "8n", velocity = v - 0.05 }
  end
  return ev
end

return song { "score", key = "D minor", bpm = 96, seed = 6, gain_db = -13.5,
  sources = { vsco = VSCO },
  sections = {
    { "title", duration = "1m", chords = "Dm9" },
    { "slam", duration = "1m", chords = "Bbmaj7" },
    { "shapes", duration = "3m", chords = "Gm9 Bbmaj7 Asus4" },
    { "coverage", duration = "3m", chords = "Dm9 Fmaj7 Gm9" },
    { "booleans", duration = "3m", chords = "Bbmaj7 Gm9 A7" },
    { "gpu", duration = "2m", chords = "Dm9 Bbmaj7" },
    { "outro", duration = "2m", chords = "Gm9 Asus4" },
    { "tail", duration = "1m", chords = "Dm9" },
  },
  returns = {
    hall = { { "Reverb", decay = 2.8, pre_delay = 0.03 }, { "Filter", type = "highpass", frequency = 220 } },
    room = { { "Reverb", decay = 0.9, pre_delay = 0.01 } },
  },
  parts = {
    -- The curve: the harp's arches, a chord a bar, the whole way through.
    harp = { role = "melody", instrument = "vsco/Harp.sfz", gain_db = 10.5, pan = -0.2, sends = { hall = -10 },
      play = {
        { "title", events = arches({ "Dm9" }, 0.42), humanize = 0.004 },
        { "slam", events = arches({ "Bbmaj7" }, 0.5), humanize = 0.004 },
        { "shapes", events = arches({ "Gm9", "Bbmaj7", "A7sus4" }, 0.5), humanize = 0.004 },
        { "coverage", events = arches({ "Dm9", "Fmaj7", "Gm9" }, 0.52), humanize = 0.004 },
        { "booleans", events = arches({ "Bbmaj7", "Gm9", "A7" }, 0.55), humanize = 0.004 },
        { "gpu", events = arches({ "Dm9", "Bbmaj7" }, 0.5), humanize = 0.004 },
        { "outro", events = arches({ "Gm9", "A7sus4" }, 0.58), humanize = 0.004 },
        { "tail", events = { { time = 0, note = "D4", duration = "1m", velocity = 0.5 }, { time = 0, note = "A4", duration = "1m", velocity = 0.45 },
          { time = 0, note = "F5", duration = "1m", velocity = 0.45 } } },
      } },
    piano = { role = "comp", instrument = { "Sampler", set = "osiris/soft_piano", release = 0.8 }, gain_db = -4.5, sends = { hall = -14 },
      play = {
        { "slam", events = comp({ "Bbmaj7" }, 0.4), humanize = 0.006 },
        { "shapes", events = comp({ "Gm9", "Bbmaj7", "A7sus4" }, 0.42), humanize = 0.006 },
        { "coverage", events = comp({ "Dm9", "Fmaj7", "Gm9" }, 0.44), humanize = 0.006 },
        { "booleans", events = comp({ "Bbmaj7", "Gm9", "A7" }, 0.48), humanize = 0.006 },
        { "gpu", events = comp({ "Dm9", "Bbmaj7" }, 0.52), humanize = 0.006 },
        { "outro", events = comp({ "Gm9", "A7sus4" }, 0.5), humanize = 0.006 },
        { "tail", events = { { time = 0, note = "D3", duration = "1m", velocity = 0.42 }, { time = 0, note = "A3", duration = "1m", velocity = 0.4 },
          { time = 0, note = "C4", duration = "1m", velocity = 0.38 }, { time = 0, note = "E4", duration = "1m", velocity = 0.38 } } },
      } },
    bass = { role = "bass", instrument = { "Sampler", set = "karoryfer/growlybass", release = 0.2 }, gain_db = 2, sends = { room = -16 },
      play = {
        { "shapes", events = walk({ "Gm9", "Bbmaj7", "A7sus4" }, 0.55) },
        { "coverage", events = walk({ "Dm9", "Fmaj7", "Gm9" }, 0.58) },
        { "booleans", events = walk({ "Bbmaj7", "Gm9", "A7" }, 0.62) },
        { "outro", events = walk({ "Gm9", "A7sus4" }, 0.62) },
        { "tail", events = { { time = 0, note = "D2", duration = "2n", velocity = 0.55 } } },
      } },
    -- The kit: a cross-stick groove with the shapes, the snare's backbeat
    -- with the booleans, hats alone under the GPU, all of it in the outro.
    drums = { role = "drums", instrument = { "Sampler", set = "virtuosity/drums" }, gain_db = 2, sends = { room = -12 },
      play = {
        { "slam", velocity = 0.8, steps = { crash = "x...............", kick = "x..............." } },
        { "shapes", velocity = 0.72, humanize = 0.004, steps = { kick = { "x.....x...x.....", "x.....x...x..x.." },
          rim = "....x.......x...", hat = "x.xox.xox.xox.xo" } },
        { "coverage", velocity = 0.75, humanize = 0.004, steps = { kick = { "x.....x...x.....", "x.....x...x..x.." },
          rim = "....x..o....x..o", hat = "xoxoxoxoxoxoxoxo" } },
        { "booleans", velocity = 0.8, humanize = 0.004, steps = { crash = { "x...............", "................", "................" },
          kick = { "x.....x...x.....", "x.....x...x..x..", "x.....x...x....." }, snare = { "....X..o....X..o", "....X..o....X..o", "....X..o....X.oX" },
          hat = "xoxoxoxoxoxoxoxo", open_hat = "..............x." } },
        { "gpu", velocity = 0.6, humanize = 0.004, steps = { hat = "x.x.x.x.x.x.x.x.", kick = { "x...............", "x..........x.x.." } } },
        { "outro", velocity = 0.82, humanize = 0.004, steps = { crash = { "x...............", "................" },
          kick = { "x.....x...x.....", "x.....x...x..x.." }, snare = { "....X..o....X..o", "....X..o.o..XXXX" }, hat = "xoxoxoxoxoxoxoxo" } },
        { "tail", velocity = 0.7, steps = { crash = "x...............", kick = "x..............." } },
      } },
    strings = { role = "pad", instrument = { "Sampler", set = "vsco2/strings", attack = 0.6, release = 1.6 }, octave = 3, gain_db = -4,
      sends = { hall = -8 },
      play = {
        { "coverage..gpu", chords = { voicing = "spread" }, velocity = 0.5 },
        { "outro..", chords = { voicing = "spread" }, velocity = 0.6 },
      } },
    -- The pops (timeline.lua reads them): the coverage's three panels and
    -- its numbers, the four booleans and the divide, the GPU's numbers.
    blips = { role = "fx", instrument = "vsco/Glockenspiel.sfz", gain_db = 26.5, pan = 0.15, sends = { hall = -8 }, octave = 5,
      play = {
        { "coverage", degrees = "1 . 3 . 5 . . . | . . . . . . . . | 8 . . . . . . .", subdivision = "8n", velocity = 0.6 },
        { "booleans", degrees = "1 . 3 . | 5 . 7 . | 8 . . .", subdivision = "4n", velocity = 0.6 },
        { "gpu", degrees = ". . 5 . | 8 . . .", subdivision = "4n", velocity = 0.62 },
      } },
    -- The impacts: the wordmark and the outro.
    fx = { role = "fx", instrument = "vsco/Timpani.sfz", gain_db = 15.5, sends = { hall = -12 },
      play = {
        { "slam", events = { { time = 0, note = "F2", duration = "2n", velocity = 0.9 } } },
        { "outro", events = { { time = 0, note = "G2", duration = "2n", velocity = 0.85 } } },
      } },
  },
  automation = {
    -- The harp up in the coverage and for its last chord; the drums' hats
    -- up when they play alone, under the GPU twin.
    ["parts/harp/gain_db"] = { { "title", 0 }, { "coverage", 1.5, "step" }, { "booleans", 0, "step" }, { "tail", 6, "step" } },
    ["parts/drums/gain_db"] = { { "slam", 0 }, { "gpu", 7, "step" }, { "outro", 0, "step" } },
    ["parts/strings/gain_db"] = { { "coverage", -14 }, { "coverage@2m", 0 }, { "gpu", -4 }, { "outro", 0 } },
    ["returns/hall/Reverb/wet"] = { { "title", 0.45 }, { "shapes", 0.3, "step" }, { "gpu", 0.45, "step" }, { "outro", 0.3, "step" }, { "tail", 0.55 } },
  },
}
