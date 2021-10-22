World = {}

function World:CreateBackground(path)
    local bg = Image(self, path)
    self.background = bg
    local bgW, bgH = bg:GetSize()

    local w, h = self:GetSize()

    bg:SetScale(self.scaleToPixelsPerMeter * self.worldWidth / bgW)
    bg:SetOrigin(bgW * 0.5, bgH * 0.5)
    bg:SetPosition(w * 0.5, h * 0.5)
end

function World:CreateWorldCoordinates()
    local bg = self.background
    local bgW = bg:GetSize()
    self.worldCoordinates = Control(bg)
    self.worldCoordinates:SetScale(bgW / self.worldWidth)
end

function World:Init(parent, width, height)
    ClippingRectangle.Init(self, parent, width, height)
    self.name = self.data.name
    self.worldDef = app.data.worlds[self.name]
    self.worldWidth = self.worldDef.width
    self.scaleToPixelsPerMeter = 100
    self.prevDragMouseX, self.prevDragMouseY = nil, nil
    self.dragMouseButton = 2
    self.mouseZoomInc = 1.3

    self:CreateBackground(self.worldDef.image)
    self:CreateWorldCoordinates()

    self.tokens = {}
    for _, name in ipairs(self.worldDef.tokens) do
        local data = app.data.tokens[name]
        table.insert(self.tokens, Token(data, self.worldCoordinates))
    end
end

function World:MousePressed(x, y, button)
    local tx, ty = self:TransformToLocal(x, y)
    if tx >= 0 and tx < self.size[1] and ty >= 0 and ty < self.size[2] then
        if button == self.dragMouseButton then
            self.prevDragMouseX, self.prevDragMouseY = tx, ty
        end
    end
    Control.MousePressed(self, x, y, button)
end

function World:MouseReleased(x, y, button)
    if button == self.dragMouseButton then
        self.prevDragMouseX, self.prevDragMouseY = nil, nil
    end
    Control.MouseReleased(self, x, y, button)
end

function World:MouseMoved(x, y)
    if self.prevDragMouseX then
        local tx, ty = self:TransformToLocal(x, y)
        local bg = self.background
        local bgX, bgY = bg:GetPosition()
        bg:SetPosition(bgX + tx - self.prevDragMouseX, bgY + ty - self.prevDragMouseY)
        self.prevDragMouseX, self.prevDragMouseY = tx, ty
    end
    Control.MouseMoved(self, x, y)
end

function World:WheelMoved(x, y)
    local realMouseX, realMouseY = love.mouse.getPosition()
    local selfMouseX, selfMouseY = self:TransformToLocal(realMouseX, realMouseY)
    if selfMouseX >= 0 and selfMouseX < self.size[1] and selfMouseY >= 0 and selfMouseY < self.size[2] then
        local bg = self.background
        local bgMouseX, bgMouseY = bg:TransformToLocal(realMouseX, realMouseY)

        local zoomInc = math.pow(self.mouseZoomInc, y)

        bg:SetOrigin(bgMouseX, bgMouseY)
        bg:SetPosition(selfMouseX, selfMouseY)

        local scale = bg:GetScale() * zoomInc
        bg:SetScale(scale)
    end
    Control.WheelMoved(self, x, y)
end

Loader.LoadFile("controls/clipping-rectangle.lua")
MakeModelOf(World, ClippingRectangle)
