local DrawableControl = require("controls.drawable-control")
local Consts = require("app.consts")

-- GLSL 1.20 and ES 1.00: no array constructors and no indexing by a variable, so the kernel is unrolled
-- Every fetch runs in uniform control flow: the implicit derivatives behind the bias are undefined in a branch
local SHADER = [[
    uniform vec2 size;
    uniform float growth;
    uniform float sigma_limit;
    uniform float base_lod;

    vec4 kernel_row(Image tex, vec2 uv, float dx, float bias) {
        return Texel(tex, uv - vec2(2.0 * dx, 0.0), bias)
            + 4.0 * Texel(tex, uv - vec2(dx, 0.0), bias)
            + 6.0 * Texel(tex, uv, bias)
            + 4.0 * Texel(tex, uv + vec2(dx, 0.0), bias)
            + Texel(tex, uv + vec2(2.0 * dx, 0.0), bias);
    }

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        vec2 t = uv * size;
        vec2 beyond = max(max(-t, t - size), vec2(0.0));
        float sigma = min(growth * length(beyond), sigma_limit);
        float bias = max(log2(max(sigma * 0.5, 1.0)) - base_lod, 0.0);
        vec2 spacing = vec2(sigma * 0.5) / size;
        vec4 sum = kernel_row(tex, uv - vec2(0.0, 2.0 * spacing.y), spacing.x, bias)
            + 4.0 * kernel_row(tex, uv - vec2(0.0, spacing.y), spacing.x, bias)
            + 6.0 * kernel_row(tex, uv, spacing.x, bias)
            + 4.0 * kernel_row(tex, uv + vec2(0.0, spacing.y), spacing.x, bias)
            + kernel_row(tex, uv + vec2(0.0, 2.0 * spacing.y), spacing.x, bias);
        return sum / 256.0 * color;
    }
]]

---@class PageSurroundings: DrawableControl
---@field private _map Image
---@field private _quad love.Quad
---@field private _shader love.Shader
local PageSurroundings = class("PageSurroundings", DrawableControl)

---@param parent Control The page: the control takes its size
---@param map Image The map, a sibling the parent adds after this control: its `love.Image` and its transform are read at every draw
function PageSurroundings:init(parent, map)
    local w, h = parent:get_size()
    DrawableControl.init(self, parent, w, h, function()
        self:_draw()
    end)
    self._map = map
    self._quad = love.graphics.newQuad(0, 0, 1, 1, map:get_love_image():getDimensions())
    self._shader = love.graphics.newShader(SHADER)
end

---@private
function PageSurroundings:_draw()
    local map = self._map
    local image = map:get_love_image()
    local w, h = self:get_size()
    local x0, y0 = map:transform_to_local(self:transform_to_global(0, 0))
    local x1, y1 = map:transform_to_local(self:transform_to_global(w, h))
    self._quad:setViewport(x0, y0, x1 - x0, y1 - y0)

    local texels_per_unit = (x1 - x0) / w
    local pixels_per_unit = self:get_screen_placement()
    local shader = self._shader
    love.graphics.setShader(shader)
    shader:send("size", {
        image:getDimensions()
    })
    shader:send("growth", Consts.PAGE_SURROUNDINGS_BLUR_GROWTH)
    shader:send("sigma_limit", Consts.PAGE_SURROUNDINGS_BLUR_LIMIT * texels_per_unit)
    shader:send("base_lod", math.log(texels_per_unit / pixels_per_unit) / math.log(2))
    love.graphics.draw(image, self._quad, 0, 0, 0, w / (x1 - x0), h / (y1 - y0))
    love.graphics.setShader()
end

return PageSurroundings
