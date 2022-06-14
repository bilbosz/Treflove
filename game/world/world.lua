World = {}

function World:CreateBackground(path)
    local bg = Image(self, path)
    self.background = bg
    local bgW, bgH = bg:GetSize()

    local w, h = self:GetSize()

    bg:SetScale(Consts.WORLD_PIXEL_PER_METER * self.worldWidth / bgW)
    bg:SetOrigin(bgW * 0.5, bgH * 0.5)
    bg:SetPosition(w * 0.5, h * 0.5)
end

function World:CreateWorldCoordinates()
    local bg = self.background
    local bgW = bg:GetSize()
    self.worldCoordinates = Control(bg)
    self.worldCoordinates:SetScale(bgW / self.worldWidth)
end

function World:Init(data, parent, width, height)
    Model.Init(self, data)
    ClippingRectangle.Init(self, parent, width, height)
    PointerEventListener.Init(self, true)
    self.name = data.name
    self.worldDef = app.data.worlds[self.name]
    self.worldWidth = self.worldDef.width
    self.pointerDownPos = {}

    self:CreateBackground(self.worldDef.image)
    self:CreateWorldCoordinates()
    self.selection = Selection(self)

    self.tokens = {}
    for _, name in ipairs(self.worldDef.tokens) do
        table.insert(self.tokens, Token(app.data.tokens[name], self.worldCoordinates))
    end

    app.pointerEventManager:RegisterListener(self)
    app.wheelEventManager:RegisterListener(self)
end

function World:GetWorldCoordinates()
    return self.worldCoordinates
end

function World:GetTokens()
    return self.tokens
end

function World:OnPointerDown(x, y, button)
    local tx, ty = self:TransformToLocal(x, y)
    if tx < 0 or tx >= self.size[1] or ty < 0 or ty >= self.size[2] then
        return
    end
    if button == Consts.WORLD_SELECT_BUTTON and not self.pointerDownPos[Consts.WORLD_DRAG_OBJECT_BUTTON] then
        local wx, wy = self.worldCoordinates:TransformToLocal(x, y)
        self.selection:SetStartPoint(wx, wy)
        self.pointerDownPos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.WORLD_DRAG_VIEW_BUTTON then
        self.pointerDownPos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.WORLD_DRAG_OBJECT_BUTTON and not self.pointerDownPos[Consts.WORLD_SELECT_BUTTON] then
        self.pointerDownPos[button] = {
            self.worldCoordinates:TransformToLocal(x, y)
        }
        self.selectSetStartPos = {}
        local set = self.selection:GetSelectSet()
        for token in pairs(set) do
            self.selectSetStartPos[token] = {
                token:GetPosition()
            }
        end
    end
end

function World:OnPointerUp(x, y, button)
    if self.pointerDownPos[Consts.WORLD_SELECT_BUTTON] and button == Consts.WORLD_SELECT_BUTTON then
        local wx, wy = self.worldCoordinates:TransformToLocal(x, y)
        self.selection:SetEndPoint(wx, wy)

        local shift = app.keyboardManager:IsKeyDown("lshift")
        local ctrl = app.keyboardManager:IsKeyDown("lctrl")
        if shift then
            self.selection:AddApply()
        elseif ctrl then
            self.selection:ToggleApply()
        else
            self.selection:Apply()
        end
        self.selection:Hide()
    end
    self.pointerDownPos[button] = nil
end

function World:OnPointerMove(x, y)
    if self.pointerDownPos[Consts.WORLD_DRAG_VIEW_BUTTON] then
        local px, py = unpack(self.pointerDownPos[Consts.WORLD_DRAG_VIEW_BUTTON])
        local tx, ty = self:TransformToLocal(x, y)
        local bg = self.background
        local bgX, bgY = bg:GetPosition()
        bg:SetPosition(bgX + tx - px, bgY + ty - py)
        self.pointerDownPos[Consts.WORLD_DRAG_VIEW_BUTTON][1], self.pointerDownPos[Consts.WORLD_DRAG_VIEW_BUTTON][2] = tx, ty
    end
    if self.pointerDownPos[Consts.WORLD_SELECT_BUTTON] then
        local wx, wy = self.worldCoordinates:TransformToLocal(x, y)
        self.selection:SetEndPoint(wx, wy)
    end
    if self.pointerDownPos[Consts.WORLD_DRAG_OBJECT_BUTTON] then
        local sx, sy = unpack(self.pointerDownPos[Consts.WORLD_DRAG_OBJECT_BUTTON])
        local wx, wy = self.worldCoordinates:TransformToLocal(x, y)
        local ox, oy = wx - sx, wy - sy
        local set = self.selection:GetSelectSet()
        for token in pairs(set) do
            local startPosX, startPosY = unpack(self.selectSetStartPos[token])
            token:SetPosition(startPosX + ox, startPosY + oy)
        end
    end
end

function World:OnWheelMoved(x, y)
    local realMouseX, realMouseY = love.mouse.getPosition()
    local selfMouseX, selfMouseY = self:TransformToLocal(realMouseX, realMouseY)
    if selfMouseX >= 0 and selfMouseX < self.size[1] and selfMouseY >= 0 and selfMouseY < self.size[2] then
        local bg = self.background
        local bgMouseX, bgMouseY = bg:TransformToLocal(realMouseX, realMouseY)

        local zoomInc = math.pow(Consts.WORLD_ZOOM_INCREASE, y)

        bg:SetOrigin(bgMouseX, bgMouseY)
        bg:SetPosition(selfMouseX, selfMouseY)

        local scale = bg:GetScale() * zoomInc
        bg:SetScale(scale)
    end
end

MakeClassOf(World, Model, ClippingRectangle, PointerEventListener, WheelEventListener)
