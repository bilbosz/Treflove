Token = {}

function Token:CreateAvatar(path)
    local d = self.d
    local r = self.d * 0.5
    local clip = ClippingMask(self, d, d, function()
        love.graphics.circle("fill", r, r, r)
    end)
    self.clip = clip
    clip:SetOrigin(r, r)

    local img = Image(clip, path)
    self.image = img

    local imgW, imgH = img:GetSize()
    local scaleW, scaleH = d / imgW, d / imgH
    img:SetOrigin(imgW * 0.5, imgH * 0.5)
    img:SetScale(math.max(scaleW, scaleH))
    img:SetPosition(r, r)
end

function Token:CreateLabel(label)
    self.label = Text(self, label)
    local s = 0.03
    local w, h = self.label:GetSize()
    self.label:SetOrigin(w * 0.5, h * 0.5)
    self.label:SetScale(s)
    self.label:SetPosition(0, self.d * 0.6)
end

function Token:Init(parent)
    local data = self.data
    Control.Init(self, parent)

    self.dragMouseButton = 1
    self.prevDragMouseX, self.prevDragMouseY = nil, nil

    self.d = data.diameter
    self:SetPosition(unpack(data.position))
    self:CreateAvatar(data.avatar)
    self:CreateLabel(data.name)

    app.pointerEventManager:RegisterListener(self)
end

function Token:OnPointerDown(x, y, id)
    local tx, ty = self:TransformToLocal(x, y)
    local r = self.d * 0.5
    if tx * tx + ty * ty <= r * r then
        if id == self.dragMouseButton then
            local parentX, parentY = self.parent:TransformToLocal(x, y)
            self.prevDragMouseX, self.prevDragMouseY = parentX, parentY
            self:Reattach()
        end
    end
end

function Token:OnPointerUp(x, y, id)
    if id == self.dragMouseButton and self.prevDragMouseX then
        self.prevDragMouseX, self.prevDragMouseY = nil, nil
        self.data.position = {
            self:GetPosition()
        }
        app.connection:SendRequest(app.data, function()
            return {}
        end)
    end
end

function Token:OnPointerMove(x, y)
    if self.prevDragMouseX then
        local parentX, parentY = self.parent:TransformToLocal(x, y)
        local selfX, selfY = self:GetPosition()
        self:SetPosition(selfX + (parentX - self.prevDragMouseX), selfY + (parentY - self.prevDragMouseY))
        self.prevDragMouseX, self.prevDragMouseY = parentX, parentY
    end
end

MakeModelOf(Token, Control, PointerEventListener)
