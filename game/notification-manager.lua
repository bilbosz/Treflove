NotificationManager = {}

function NotificationManager:Init()
    self.panel = NotificationPanel(self)
    self.notifications = {}
    app.updateEventManager:RegisterListener(self)
end

function NotificationManager:Notify(message, duration)
    table.insert(self.notifications, {
        message = message,
        startTime = app:GetTime(),
        duration = duration or Consts.NOTIFICATION_DURATION
    })
    self.panel:UpdateNotifications()
end

function NotificationManager:GetNotifications()
    return self.notifications
end

function NotificationManager:ClearNotifications()
    self.notifications = {}
    self.panel:UpdateNotifications()
end

function NotificationManager:OnUpdate()
    local time = app:GetTime()
    local toRemove
    for i, notification in ipairs(self.notifications) do
        if time > notification.startTime + notification.duration then
            toRemove = toRemove or {}
            table.insert(toRemove, i)
        end
    end
    if toRemove then
        for _, i in ripairs(toRemove) do
            table.remove(self.notifications, i)
        end
        self.panel:UpdateNotifications()
    end
end

MakeClassOf(NotificationManager, UpdateEventListener)
