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
    local s = 0.007
    local w, h = self.label:GetSize()
    self.label:SetOrigin(w * 0.5, h * 0.5)
    self.label:SetScale(s)
    self.label:SetPosition(0, self.d * 0.6)
end

local function CreateSelectionEffect(self)
    local rect = Rectangle(self, 0.5, 0.5, {
        1,
        0,
        0,
        0.5
    })
    self.selection = rect
    self.selection:SetEnable(false)
end

function Token:Init(data, parent)
    Model.Init(self, data)
    Control.Init(self, parent)
    PointerEventListener.Init(self)

    self.dragMouseButton = 1
    self.prevDragMouseX, self.prevDragMouseY = nil, nil

    self.d = data.diameter
    self:SetPosition(unpack(data.position))
    self:CreateAvatar(data.avatar)
    self:CreateLabel(data.name)
    CreateSelectionEffect(self)

    self.isSelected = false

    app.pointerEventManager:RegisterListener(self)
end

function Token:GetRadius()
    return self.data.diameter * 0.5
end

function Token:SetSelect(value)
    self.isSelected = value
    self.selection:SetEnable(value)
end

function Token:GetSelect()
    return self.isSelected
end

MakeClassOf(Token, Model, Control, PointerEventListener)
