Page = {}

function Page:CreateBackground(path)
    local bg = Image(self, path)
    self.background = bg
    local bgW, bgH = bg:GetSize()

    local w, h = self:GetSize()

    bg:SetScale(self.pixelPerMeter * self.pageWidth / bgW)
    bg:SetOrigin(bgW * 0.5, bgH * 0.5)
    bg:SetPosition(w * 0.5, h * 0.5)
end

function Page:CreatePageCoordinates()
    local bg = self.background
    local bgW = bg:GetSize()
    self.pageCoordinates = Control(bg)
    self.pageCoordinates:SetScale(bgW / self.pageWidth)
end

function Page:Init(data, gameScreen, width, height, tokenPanel)
    Model.Init(self, data)
    ClippingRectangle.Init(self, gameScreen:GetControl(), width, height)
    PointerEventListener.Init(self, true)
    self.name = data.name
    self.pixelPerMeter = data.pixel_per_meter
    self.pageWidth = data.width
    self.pointerDownPos = {}
    self.gameScreen = gameScreen

    self:CreateBackground(data.image)
    self:CreatePageCoordinates()
    self.selection = Selection(self)
    self.tokenPanel = tokenPanel

    self.tokens = {}
    for _, name in ipairs(data.tokens) do
        table.insert(self.tokens, Token(app.data.tokens[name], self.pageCoordinates))
    end

    app.pointerEventManager:RegisterListener(self)
    app.wheelEventManager:RegisterListener(self)
end

function Page:GetPageCoordinates()
    return self.pageCoordinates
end

function Page:GetTokens()
    return self.tokens
end

function Page:OnPointerDown(x, y, button)
    local tx, ty = self:TransformToLocal(x, y)
    if tx < 0 or tx >= self.size[1] or ty < 0 or ty >= self.size[2] then
        return
    end
    if button == Consts.PAGE_SELECT_BUTTON and not self.pointerDownPos[Consts.PAGE_DRAG_TOKEN_BUTTON] then
        local wx, wy = self.pageCoordinates:TransformToLocal(x, y)
        self.selection:SetStartPoint(wx, wy)
        self.pointerDownPos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.PAGE_DRAG_VIEW_BUTTON then
        self.pointerDownPos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.PAGE_DRAG_TOKEN_BUTTON and not self.pointerDownPos[Consts.PAGE_SELECT_BUTTON] then
        self.pointerDownPos[button] = {
            self.pageCoordinates:TransformToLocal(x, y)
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

function Page:OnPointerUp(x, y, button)
    if self.pointerDownPos[Consts.PAGE_SELECT_BUTTON] and button == Consts.PAGE_SELECT_BUTTON then
        local wx, wy = self.pageCoordinates:TransformToLocal(x, y)
        local selection = self.selection
        selection:SetEndPoint(wx, wy)

        local shift = app.keyboardManager:IsKeyDown("lshift")
        local ctrl = app.keyboardManager:IsKeyDown("lctrl")
        if shift then
            selection:AddApply()
        elseif ctrl then
            selection:ToggleApply()
        else
            selection:Apply()
        end
        selection:Hide()
    end
    self.pointerDownPos[button] = nil
end

function Page:OnPointerMove(x, y)
    if self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON] then
        local px, py = unpack(self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON])
        local tx, ty = self:TransformToLocal(x, y)
        local bg = self.background
        local bgX, bgY = bg:GetPosition()
        bg:SetPosition(bgX + tx - px, bgY + ty - py)
        self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON][1], self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON][2] = tx, ty
    end
    if self.pointerDownPos[Consts.PAGE_SELECT_BUTTON] then
        local wx, wy = self.pageCoordinates:TransformToLocal(x, y)
        self.selection:SetEndPoint(wx, wy)
    end
    if self.pointerDownPos[Consts.PAGE_DRAG_TOKEN_BUTTON] then
        local sx, sy = unpack(self.pointerDownPos[Consts.PAGE_DRAG_TOKEN_BUTTON])
        local wx, wy = self.pageCoordinates:TransformToLocal(x, y)
        local ox, oy = wx - sx, wy - sy
        local set = self.selection:GetSelectSet()
        for token in pairs(set) do
            local startPosX, startPosY = unpack(self.selectSetStartPos[token])
            token:SetPosition(startPosX + ox, startPosY + oy)
        end
    end
end

function Page:OnWheelMoved(x, y)
    local realMouseX, realMouseY = love.mouse.getPosition()
    local selfMouseX, selfMouseY = self:TransformToLocal(realMouseX, realMouseY)
    if selfMouseX >= 0 and selfMouseX < self.size[1] and selfMouseY >= 0 and selfMouseY < self.size[2] then
        local bg = self.background
        local bgMouseX, bgMouseY = bg:TransformToLocal(realMouseX, realMouseY)

        local zoomInc = math.pow(Consts.PAGE_ZOOM_INCREASE, y)

        bg:SetOrigin(bgMouseX, bgMouseY)
        bg:SetPosition(selfMouseX, selfMouseY)

        local scale = bg:GetScale() * zoomInc
        bg:SetScale(scale)
    end
end

function Page:GetGameScreen()
    return self.gameScreen
end

function Page:GetSelection()
    return self.selection
end

MakeClassOf(Page, Model, ClippingRectangle, PointerEventListener, WheelEventListener)
