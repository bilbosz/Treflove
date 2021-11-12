ScreenSaver = {}

local function CreateLogo(self)
    local logo = Control(self.screen)
    self.logo = logo
    logo:SetPosition(self.size[1] * 0.5, self.size[2] * 0.5)

    local image = love.graphics.newImage("icon.png")
    local imgW, imgH = image:getDimensions()

    local circle = DrawableControl(logo, imgW, imgH, function()
        love.graphics.setColor({
            0.9,
            0.9,
            0.9,
            1
        })
        love.graphics.circle("fill", 0, 0, imgW * 0.5)
    end)

    local shader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            if (Texel(texture, texture_coords).a == 0.0) {
                discard;
            }
            return vec4(1.0);
        }
    ]])
    local mask = ClippingMask(logo, imgW, imgH, function()
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

function ScreenSaver:Draw()
    self.screen:Draw()
end

function ScreenSaver:Update(dt)
    self.logo:SetRotation(self.logo:GetRotation() + dt * self.dirRot)

    local x, y = self.logo:GetPosition()
    local r = self.mask:GetSize() * 0.5
    local w, h = self:GetSize()
    local move = 60 * dt

    local newX, newY = x + self.dirX * move, y + self.dirY * move

    local collided = false
    if newX - r < 0 then
        collided = true
        self.dirX = -self.dirX
        newX = -(newX - r) + r
    end
    if newX + r >= w then
        collided = true
        self.dirX = -self.dirX
        newX = w - ((newX + r) - w) - r
    end
    if newY - r < 0 then
        collided = true
        self.dirY = -self.dirY
        newY = -(newY - r) + r
    end
    if newY + r >= h then
        collided = true
        self.dirY = -self.dirY
        newY = h - ((newY + r) - h) - r
    end
    if collided then
        for k = 1, 3 do
            self.color[k] = math.random()
        end
        self.dirRot = -self.dirRot
    end

    self.logo:SetPosition(newX, newY)
end

function ScreenSaver:Init()
    local w, h = love.graphics.getDimensions()
    Control.Init(self, nil, w, h)
    UpdateObserver.Init(self)

    self.screen = Rectangle(self, w, h, {
        255,
        255,
        255,
        255
    })
    CreateLogo(self)

    self.dirRot = 1
    self.dirX, self.dirY = 1, 1
end

Loader.LoadFile("controls/control.lua")
Loader.LoadFile("events/update-observer.lua")
MakeClassOf(ScreenSaver, Control, UpdateObserver)
