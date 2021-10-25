Token = {}

function Token:CreateAvatar(path)
    local width, height = self:GetSize()
    local clip = ClippingMask(self, width, height, function()
        love.graphics.circle("fill", 0, 0, width * 0.5)
    end)
    self.clip = clip

    local img = Image(clip, path)
    self.image = img

    local imgW, imgH = img:GetSize()
    local selfW, selfH = clip:GetSize()
    local scaleW, scaleH = selfW / imgW, selfH / imgH
    img:SetScale(math.max(scaleW, scaleH))
    img:SetOrigin(imgW * 0.5, imgH * 0.5)
end

function Token:CreateLabel(label)
    self.label = Text(self, label)
    local scale = 0.03
    local width, height = self.label:GetSize()
    self.label:SetOrigin(width * 0.5, height * 0.5)
    self.label:SetScale(scale)
    local _, selfH = self:GetSize()
    self.label:SetPosition(0, selfH * 0.6)
end

function Token:Init(parent)
    local data = self.data
    Control.Init(self, parent, data.radius, data.radius)
    UpdateObserver.Init(self)
    self.dragMouseButton = 1
    self.prevDragMouseX, self.prevDragMouseY = nil, nil

    self:SetPosition(unpack(data.position))
    self:CreateAvatar(data.avatar)
    self:CreateLabel(data.name)
end

function Token:MousePressed(x, y, button)
    local tx, ty = self:TransformToLocal(x, y)
    local size = self.size
    if tx >= -size[1] * 0.5 and tx < size[1] * 0.5 and ty >= -size[2] * 0.5 and ty < size[2] * 0.5 then
        if button == self.dragMouseButton then
            local parentX, parentY = self.parent:TransformToLocal(x, y)
            self.prevDragMouseX, self.prevDragMouseY = parentX, parentY
            self:Reattach()
        end
    end
    Control.MousePressed(self, x, y, button)
end

function Token:MouseReleased(x, y, button)
    if button == self.dragMouseButton and self.prevDragMouseX then
        self.prevDragMouseX, self.prevDragMouseY = nil, nil
        self.data.position = {self:GetPosition()}
        app.connection:SendRequest(app.data, function(response)
            return {}
        end)
    end
    Control.MouseReleased(self, x, y, button)
end

function Token:MouseMoved(x, y)
    if self.prevDragMouseX then
        local parentX, parentY = self.parent:TransformToLocal(x, y)
        local selfX, selfY = self:GetPosition()
        self:SetPosition(selfX + (parentX - self.prevDragMouseX), selfY + (parentY - self.prevDragMouseY))
        self.prevDragMouseX, self.prevDragMouseY = parentX, parentY
    end
    Control.MouseMoved(self, x, y)
end

function Token:Update(dt)
    self.total = (self.total or 0) + dt
    self.image:SetRotation(self.total)
end

Loader.LoadFile("controls/control.lua")
Loader.LoadFile("events/update-observer.lua")
MakeModelOf(Token, Control, UpdateObserver)
