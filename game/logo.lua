Logo = {}

function Logo:Init(parent)
    local image = love.graphics.newImage("icon.png")
    local imgW, imgH = image:getDimensions()

    DrawableControl.Init(self, parent, imgW, imgW, function()
        love.graphics.setColor({
            0.9,
            0.9,
            0.9,
            1
        })
        love.graphics.circle("fill", 0, 0, imgW * 0.5)
    end)
    self:SetPosition(parent.size[1] * 0.5, parent.size[2] * 0.5)

    local shader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            if (Texel(texture, texture_coords).a == 0.0) {
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
    mask:SetOrigin(imgW * 0.5, imgH * 0.5 + 3)
    mask:SetScale(0.7)
    self.mask = mask

    self.color = {
        0,
        0,
        0,
        255
    }
    local background = DrawableControl(mask, imgW, imgW, function()
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", 0, 0, imgW, imgW)
    end)
    background:SetOrigin(imgW * 0.5, imgW * 0.5)
    background:SetPosition(imgW * 0.5, imgW * 0.5)
end

MakeClassOf(Logo, DrawableControl)
