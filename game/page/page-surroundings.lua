local DrawableControl = require("controls.drawable-control")
local Consts = require("app.consts")

-- The level is explicit: a bias would add to the level the taps' derivatives give, which jump where sigma reaches its limit
local SHADER = [[
#pragma language glsl3
    uniform vec2 size;
    uniform float growth;
    uniform float sigma_limit;
    uniform float base_lod;

    const float weights[5] = float[5](1.0, 4.0, 6.0, 4.0, 1.0);

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
        vec2 t = uv * size;
        vec2 beyond = max(max(-t, t - size), vec2(0.0));
        float sigma = min(growth * length(beyond), sigma_limit);
        float lod = max(log2(max(sigma * 0.5, 1.0)), base_lod);
        vec2 spacing = vec2(sigma * 0.5) / size;
        vec4 sum = vec4(0.0);
        for (int j = 0; j < 5; j++) {
            for (int i = 0; i < 5; i++) {
                vec2 offset = vec2(float(i - 2), float(j - 2)) * spacing;
                sum += weights[i] * weights[j] * textureLod(tex, uv + offset, lod);
            }
        }
        return sum / 256.0 * color;
    }
]]

---@class PageSurroundings: DrawableControl
---@field private _map Image
---@field private _quad love.Quad
---@field private _shader love.Shader|nil Without GLSL 3 none, and nothing is drawn
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
    if love.graphics.getSupported().glsl3 == true then
        self._shader = love.graphics.newShader(SHADER)
    end
end

---@private
function PageSurroundings:_draw()
    local shader = self._shader
    if not shader then
        return
    end
    local map = self._map
    local image = map:get_love_image()
    local w, h = self:get_size()
    local x0, y0 = map:transform_to_local(self:transform_to_global(0, 0))
    local x1, y1 = map:transform_to_local(self:transform_to_global(w, h))
    self._quad:setViewport(x0, y0, x1 - x0, y1 - y0)

    local texels_per_unit = (x1 - x0) / w
    local pixels_per_unit = self:get_screen_placement()
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
