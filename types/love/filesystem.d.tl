-- `require("love.filesystem")`: a LÖVE thread starts with no LÖVE modules
-- loaded and requires what it uses (networking/detail/*). The module is the
-- record of the global `love` (types/love.d.tl).
local filesystem = love.filesystem

return filesystem
