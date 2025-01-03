local Consts = require("app.consts")
local Control = require("controls.control")
local DeferManager = require("events.defer-manager")
local UpdateEventListener = require("events.update-event").Listener
local UpdateEventManager = require("events.update-event").Manager
local Logger = require("utils.logger")
local Utils = require("utils.utils")

---@class App
---@field public asset_manager AssetManager
---@field public backstack_manager BackstackManager
---@field public button_event_manager ButtonEventManager
---@field public connection_manager ConnectionManager
---@field public data table
---@field public defer_manager DeferManager
---@field public file_system_drop_event_manager FileSystemDropEventManager
---@field public height number
---@field public is_client boolean
---@field public is_server boolean
---@field public keyboard_manager KeyboardManager
---@field public logger Logger
---@field public notification_manager NotificationManager
---@field public options_manager OptionsManager
---@field public pointer_event_manager PointerEventManager
---@field public resize_manager ResizeManager
---@field public root Control
---@field public screen_manager ScreenManager
---@field public session Session
---@field public text_event_manager TextEventManager
---@field public update_event_manager UpdateEventManager
---@field public wheel_event_manager WheelEventManager
---@field public width number
---@field protected load fun(self:App):void
---@field protected params string[]
---@field private _draw_aabbs boolean
---@field private _mark_for_quit boolean
---@field private _start_time number
---@field private _time number
local App = class("App")

---@protected
function App:register_love_callbacks()
    if self.load then
        function love.load()
            self:load()
        end
    end

    if config.window then
        self.root = Control()
        self:rescale_root()
        if debug then
            function love.draw()
                if self.root:is_visible() then
                    self.root:draw()
                    love.graphics.reset()
                    if self._draw_aabbs then
                        Utils.draw_aabbs(self.root)
                    end
                end
                love.graphics.reset()
            end
        else
            function love.draw()
                if self.root:is_visible() then
                    self.root:draw()
                end
                love.graphics.reset()
            end
        end
        function love.keypressed(key)
            if key == Consts.DRAW_AABBS_KEY then
                self._draw_aabbs = not self._draw_aabbs
            elseif key == Consts.QUIT_KEY then
                self:quit()
            end
        end
    end

    if debug then
        function love.errorhandler(msg)
            print(string.format("%s error: \"%s\"", app.is_client and "Client" or "Server", msg))
            print(Utils.get_stack_trace(2))
        end
    else
        function love.errorhandler()

        end
    end

    function love.update(dt)
        self.defer_manager:update()
        if self._mark_for_quit then
            love.event.quit(Consts.APP_SUCCESS_EXIT_CODE)
        end
        self._time = Utils.get_time() - self._start_time
        self.update_event_manager:invoke_event(UpdateEventListener.on_update, dt)
        collectgarbage("step")
    end
end

---@return number
function App:get_time()
    return self._time
end

function App:quit()
    self._mark_for_quit = true
end

---@param ... any
function App:log(...)
    local format = string.rep("%s", select("#", ...), " ")
    self.logger:log_up(format, 1, ...)
end

---@param ... any
function App:log_fun(...)
    local format = ""
    if debug then
        local info = debug.getinfo(2, "n")
        format = string.format("%s ", info.name)
    end
    format = format .. string.rep("%s ", select("#", ...), " ")
    self.logger:log_up(format, 1, ...)
end

function App:rescale_root()
    local real_w, real_h = love.graphics.getDimensions()
    local scale = real_w / Consts.MODEL_WIDTH
    self.width, self.height = Consts.MODEL_WIDTH, real_h / scale
    self.root:set_scale(scale)
end

---@param params ArgParserResult
function App:init(params)
    app = self
    self._start_time = Utils.get_time()
    self._time = nil
    self.logger = Logger({
        start_time = self._start_time
    }, "main")
    self.params = params
    self.is_server = false
    self.is_client = false
    self.data = nil
    self.width = nil
    self.height = nil
    self.root = nil
    self.update_event_manager = UpdateEventManager()
    self.defer_manager = DeferManager()

    self:register_love_callbacks()
end

return App
