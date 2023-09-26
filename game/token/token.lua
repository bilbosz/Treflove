Token = {}

local function CreateAvatar(self, path)
    local d = self.d
    local r = d * 0.5
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

local function CenterLabel(self)
    local label = self.label
    local s = 0.007
    local w, h = label:GetSize()
    label:SetOrigin(w * 0.5, h * 0.5)
    label:SetScale(s)
    label:SetPosition(0, self.d * 0.5 + Consts.TOKEN_SELECTION_THICKNESS + h * s * 0.5)
end

local function CreateLabel(self, label)
    self.label = Text(self, label)
    CenterLabel(self)
end

local function CreateSelectionEffect(self)
    local r = self.d * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
    local circle = Circle(self, r, Consts.TOKEN_SELECTION_COLOR, Consts.TOKEN_SELECTION_THICKNESS)
    circle:SetPosition(-r, -r)

    self.selection = circle
    self.selection:SetEnabled(false)
end

function Token:Init(data, parent)
    Model.Init(self, data)
    Control.Init(self, parent)
    PointerEventListener.Init(self)

    self.dragMouseButton = 1
    self.prevDragMouseX, self.prevDragMouseY = nil, nil

    self.d = data.diameter
    self:SetPosition(unpack(data.position))
    CreateAvatar(self, data.avatar)
    CreateLabel(self, data.name)
    CreateSelectionEffect(self)

    self.isSelected = false

    app.pointerEventManager:RegisterListener(self)
end

function Token:GetRadius()
    return self.data.diameter * 0.5
end

function Token:SetSelect(value)
    self.isSelected = value
    self.selection:SetEnabled(value)
    if value then
        self:Reattach()
    end
end

function Token:GetSelect()
    return self.isSelected
end

function Token:SetPosition(x, y)
    local pos = self.data.position
    pos[1], pos[2] = x, y
    Control.SetPosition(self, x, y)
end

function Token:SetData(key, value)
    Model.SetData(self, key, value)
    if key == "name" then
        self.label:SetText(self.data.name)
        CenterLabel(self)
    elseif key == "diameter" then
        self.d = self.data.diameter
        local d = self.d
        local r = d * 0.5

        local clip = self.clip
        clip:SetSize(d, d)
        clip:SetOrigin(r, r)
        clip:SetDrawMaskCb(function()
            love.graphics.circle("fill", r, r, r)
        end)

        local img = self.image
        local imgW, imgH = img:GetSize()
        local scaleW, scaleH = d / imgW, d / imgH
        img:SetOrigin(imgW * 0.5, imgH * 0.5)
        img:SetScale(math.max(scaleW, scaleH))
        img:SetPosition(r, r)

        local selectionR = self.d * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
        local selection = self.selection
        selection:SetRadius(selectionR, selectionR)
        selection:SetPosition(-selectionR, -selectionR)

        CenterLabel(self)
    end
end

MakeClassOf(Token, Model, Control, PointerEventListener)
