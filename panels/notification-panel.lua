NotificationPanel = {}

local function CreateAnchor(self)
    self.anchor = ClippingRectangle(app.root, 0, 0)
end

local function AddLine(self, line, y)
    local ctrl = Text(self.anchor, line, Consts.NOTIFICATION_COLOR)
    local ctrlW, ctrlH = ctrl:GetSize()
    ctrl:SetScale(Consts.NOTIFICATION_TEXT_SCALE)
    ctrl:SetOrigin(ctrlW, ctrlH)
    ctrl:SetPosition(self.width - Consts.NOTIFICATION_PADDING, y)
    return ctrl
end

local function AddNotification(self, notification, y)
    local lines = {}

    for line in string.gmatch(notification.message, "[^\n]+") do
        table.insert(lines, line)
    end

    for _, line in ripairs(lines) do
        local ctrl = AddLine(self, line, y)
        local s = ctrl:GetScale()
        local _, h = ctrl:GetSize()
        y = y - h * s
    end

    return y - Consts.NOTIFICATION_VSPACE
end

local function PositionAnchor(self)
    self.anchor:SetPosition(app.width, app.height)
    local w, h = Consts.NOTIFICATION_PANEL_WIDTH * app.width, Consts.NOTIFICATION_PANEL_HEIGHT * app.height
    self.width, self.height = w, h
    self.anchor:SetSize(w, h)
    self.anchor:SetOrigin(w, h)
end

function NotificationPanel:Init()
    CreateAnchor(self)
    PositionAnchor(self)
    app.updateEventManager:RegisterListener(self)
    app.resizeManager:RegisterListener(self)
end

function NotificationPanel:UpdateNotifications()
    for _, child in ipairs(self.anchor:GetChildren()) do
        child:SetParent(nil)
    end
    local y = self.height - Consts.NOTIFICATION_PADDING
    for _, notification in ipairs(app.notificationManager:GetNotifications()) do
        y = AddNotification(self, notification, y)
    end
end

function NotificationPanel:OnUpdate()
    self.anchor:Reattach()
end

function NotificationPanel:OnResize()
    PositionAnchor(self)
    self:UpdateNotifications()
end

MakeClassOf(NotificationPanel, UpdateEventListener, ResizeEventListener)
