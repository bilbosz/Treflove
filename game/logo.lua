Logo = {}

function Logo:Init(parent)
    local image = love.graphics.newImage("icon.png")
    local imgW, imgH = image:getDimensions()
    local r = imgW * 0.5

    DrawableControl.Init(self, parent, imgW, imgW, function()
        love.graphics.setColor(Consts.LOGO_COLOR_BG)
        love.graphics.circle("fill", r, r, r)
    end)
    self:SetOrigin(r, r)
    self:SetPosition(parent.size[1] * 0.5, parent.size[2] * 0.5)

    local shader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            if (Texel(texture, texture_coords).a <= 0.35) {
                discard;
            }
            return vec4(1.0);
        }
    ]])
    local mask = ClippingMask(self, imgW, imgH, function()
        love.graphics.setShader(shader)
        love.graphics.draw(image)
        love.graphics.setShader()
    end)
    mask:SetOrigin(r, imgH * 0.5 - 11)
    mask:SetPosition(r, r)
    mask:SetScale(0.94)
    self.mask = mask

    self.color = Consts.LOGO_COLOR_FG
    local background = DrawableControl(mask, imgW, imgW, function()
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", 0, 0, imgW, imgW)
    end)
    background:SetOrigin(r, r)
    background:SetPosition(r, r)
end

MakeClassOf(Logo, DrawableControl)
