-- Where things happen, in beats from the start of the video (4 a bar),
-- read from the song (track.lua): its sections are the scenes, its
-- glockenspiel notes the pops the picture answers to.

local score = require("track")

local T = {}

local function at(pos) return score.beat(score.time(pos)) end
-- The song's hits of `part` in section `section`, in beats into it.
local function hits(part, section)
  local out, start = {}, at(section)
  for i, t in ipairs(score.hits { part = part, range = section }) do out[i] = score.beat(t) - start end
  return out
end

T.TITLE, T.SHAPES, T.COVERAGE, T.BOOLEANS, T.GPU, T.OUTRO = at("title"), at("shapes"), at("coverage"),
  at("booleans"), at("gpu"), at("outro")
T.END = at("tail")
T.TOTAL = score.beat(score.duration)
T.TITLE_SLAM = at("slam") - T.TITLE

T.COVERAGE_POPS = hits("blips", "coverage")   -- the three panels, then the numbers
T.BOOLEAN_POPS = hits("blips", "booleans")    -- union, difference, intersection, xor, divide
T.GPU_POPS = hits("blips", "gpu")             -- the two numbers
assert(#T.COVERAGE_POPS == 4 and #T.BOOLEAN_POPS == 5 and #T.GPU_POPS == 2,
  string.format("pops: %d %d %d", #T.COVERAGE_POPS, #T.BOOLEAN_POPS, #T.GPU_POPS))

return T
