local Consts = require("app.consts")
local MainLoop = require("app.main-loop")
local Control = require("controls.control")
local DeferManager = require("events.defer-manager")
local Event = require("events.event")
local Logger = require("utils.logger")
local Utils = require("utils.utils")
local debugger = require("app.debugger")
local lifetime = require("lifetime")

---@class App: Object
---@field public asset_manager AssetManager
---@field public backstack_manager BackstackManager
---@field public button_event_manager ButtonEventManager
---@field public connection_manager ConnectionManager
---@field public data GameData|nil On the server from `load()` on; on the client while the game data is in, until a disconnect
---@field public defer_manager DeferManager
---@field public file_system_drop_event_manager FileSystemDropEventManager
---@field public height number|nil Model height, with a window
---@field public is_client boolean
---@field public is_server boolean
---@field public keyboard_manager KeyboardManager
---@field public logger Logger
---@field public main_loop MainLoop Installed as `love.run`
---@field public notification_manager NotificationManager
---@field public options_manager OptionsManager
---@field public overlay Control|nil Drawn after the root, outside the hit-tested tree, with a window
---@field public pointer_event_manager PointerEventManager
---@field public resize_manager ResizeManager
---@field public root Control|nil With a window
---@field public screen_manager ScreenManager|nil On the client, and on a server with a window
---@field public service_event Event Triggered without arguments once per main loop iteration, before the update, paused or not
---@field public session Session|nil The client's, while connected
---@field public text_event_manager TextEventManager
---@field public update_event Event Triggered with (dt) every frame
---@field public wheel_event Event Triggered with (x, y) wheel movement (client only)
---@field public width number|nil Model width, with a window
---@field protected load fun(self:App)
---@field protected params ArgParserResult
---@field private _draw_aabbs boolean
---@field private _exit_code integer|nil Set by `quit`, honored by the next update
---@field private _start_time number The wall clock at construction, the logger's start
---@field private _time number The sum of the frame deltas so far
local App = class("App")

---@protected
function App:register_love_callbacks()
    self.main_loop:install()

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
                self:_draw_overlay()
            end
        else
            function love.draw()
                if self.root:is_visible() then
                    self.root:draw()
                end
                love.graphics.reset()
                self:_draw_overlay()
            end
        end
        ---@param key love.KeyConstant
        ---@diagnostic disable-next-line: duplicate-set-field
        function love.keypressed(key)
            if key == Consts.DRAW_AABBS_KEY then
                self._draw_aabbs = not self._draw_aabbs
            elseif key == Consts.QUIT_KEY then
                self:quit()
            end
        end
    end

    if debug then
        ---@param msg string
        function love.errorhandler(msg)
            print(string.format("%s error: \"%s\"", app.is_client and "Client" or "Server", msg))
            print(Utils.get_stack_trace(2))
            debugger.pause()
        end
    else
        function love.errorhandler()

        end
    end

    function love.quit()
        self.connection_manager:remove_all()
        lifetime.set_exiting(true)
    end

    ---@param dt number
    function love.update(dt)
        self.defer_manager:update()
        if self._exit_code then
            love.event.quit(self._exit_code)
        end
        self._time = self._time + dt
        self.update_event:trigger(dt)
        collectgarbage("step")
    end
end

---@private
function App:_draw_overlay()
    local overlay = self.overlay
    if overlay and overlay:is_visible() then
        overlay:draw()
        love.graphics.reset()
    end
end

---@return number The sum of the frame deltas so far, with what the main loop skipped
function App:get_time()
    return self._time
end

---@param exit_code integer|nil Defaults to `Consts.APP_SUCCESS_EXIT_CODE`
function App:quit(exit_code)
    self._exit_code = exit_code or Consts.APP_SUCCESS_EXIT_CODE
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
    self._time = 0
    self._exit_code = nil
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
    self.update_event = Event()
    self.service_event = Event()
    self.defer_manager = DeferManager()
    self.main_loop = MainLoop(params.headless)
    self.overlay = nil

    self:register_love_callbacks()
end

return App
