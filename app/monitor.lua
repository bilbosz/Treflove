local Console = require("app.console")
local MonitorTarget = require("app.monitor-target")
local UiApp = require("app.ui-app")
local MonitorScreen = require("screens.monitor-screen")
local lifetime = require("lifetime")

---@class Monitor: UiApp
---@field private _targets MonitorTarget[] Sorted by name
---@field private _screen MonitorScreen|nil From `load` on
local Monitor = class("Monitor", UiApp)

---@param params ArgParserResult
function Monitor:init(params)
    UiApp.init(self, params)
    self.logger:set_name("monitor-main")
    local ports = assert(params.targets, "a monitor has targets")
    ---@type string[]
    local names = {}
    for name in pairs(ports) do
        table.insert(names, name)
    end
    table.sort(names)
    self._targets = {}
    for _, name in ipairs(names) do
        table.insert(self._targets, MonitorTarget(name, params.address, ports[name]))
    end
    self._screen = nil
    self.update_event:register(self, self.on_update)
    if params.console then
        self.console = Console(params.console)
    end
end

---@protected
function Monitor:load()
    self.backstack_manager:push(function()
        app:quit()
    end)
    local screen = MonitorScreen(self._targets)
    self._screen = screen
    self.screen_manager:show(screen)
end

---@return MonitorTarget[] Sorted by name
function Monitor:get_targets()
    return table.copy(self._targets)
end

---@param dt number
function Monitor:on_update(dt)
    for _, target in ipairs(self._targets) do
        target:update(dt)
    end
end

---@protected
function Monitor:on_quit()
    for _, target in ipairs(self._targets) do
        lifetime.destroy(target)
    end
end

return Monitor
