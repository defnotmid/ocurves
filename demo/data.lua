-- The baked data (media/bake.json, written by bake/main.odin against
-- ocurves v0.0.6): a glyph's pieces and cells, a small glyph's pixels three
-- ways, the booleans' segments with their sources and the divide's faces,
-- and that small glyph drawn by ovg's CPU and GPU paths.

local fh = assert(io.open(SCRIPT_DIR .. "/media/bake.json"))
local D = json_decode(fh:read("a"))
fh:close()
return D
