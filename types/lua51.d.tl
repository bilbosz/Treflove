-- Lua 5.1 / LuaJIT globals that Teal's standard library (written for Lua
-- 5.4, with compatibility code for 5.1) does not declare.

-- loadstring(chunk [, chunkname]): the compiled chunk, or nil and the
-- error. any: the chunk returns whatever its code returns.
global loadstring: function(chunk: string, chunkname?: string): (function(...: any): any..., string)
