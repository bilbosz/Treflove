local App = require("app.app")
local Consts = require("app.consts")
local AssetManager = require("data.asset-manager")
local FileSystemDropEventManager = require("events.file-drop-event").Manager
local KeyboardManager = require("events.keyboard").Manager
local PointerEventManager = require("events.pointer-event").Manager
local ResizeManager = require("events.resize").Manager
local WheelEventListener = require("events.wheel-event").Listener
local WheelEventManager = require("events.wheel-event").Manager
local NotificationManager = require("game.notification-manager")
local OptionsManager = require("game.options-manager")
local Session = require("game.session")
local ConnectionManager = require("networking.connection-manager")
local ConnectingScreen = require("screens.connecting-screen")
local ScreenManager = require("screens.screen-manager")
local BackstackManager = require("utils.backstack-manager")
local ButtonEventManager = require("ui.button-event").Manager
local TextEventManager = require("ui.text-event").Manager

---@class Client: App
local Client = class("Client", App)

---@param params ArgParserResult
function Client:init(params)
    App.init(self, params)
    self.logger:set_name("client-main")
    self.is_client = true
    self.connection_manager = ConnectionManager(params.address, params.port)
    self.resize_manager = ResizeManager()
    self.screen_manager = ScreenManager()
    self.pointer_event_manager = PointerEventManager()
    self.wheel_event_manager = WheelEventManager()
    self.button_event_manager = ButtonEventManager()
    self.keyboard_manager = KeyboardManager()
    self.text_event_manager = TextEventManager()
    self.notification_manager = NotificationManager()
    self.options_manager = OptionsManager()
    self.asset_manager = AssetManager()
    self.backstack_manager = BackstackManager()
    self.file_system_drop_event_manager = FileSystemDropEventManager()
    self.session = nil
end

function Client:load()
    self.backstack_manager:push(function()
        app:quit()
    end)
    local connecting_screen = ConnectingScreen()
    self.screen_manager:show(connecting_screen)
    self.connection_manager:start(function(connection)
        self.session = Session(connection)
    end, function()
        self.screen_manager:show(connecting_screen)
        self.session:release()
        self.session = nil
        self.data = nil
    end)
end

---@private
function Client:register_love_callbacks()
    App.register_love_callbacks(self)
    local app_key_pressed = love.keypressed
    ---@param key love.KeyConstant
    ---@diagnostic disable-next-line: duplicate-set-field
    function love.keypressed(key)
        app_key_pressed(key)
        if key == Consts.TOGGLE_FULLSCREEN_KEY then
            self.resize_manager:toggle_fullscreen()
            return
        end
        self.keyboard_manager:key_pressed(key)
        self.text_event_manager:key_pressed(key)
    end
    ---@param key love.KeyConstant
    function love.keyreleased(key)
        self.keyboard_manager:key_released(key)
    end
    ---@param x number
    ---@param y number
    function love.wheelmoved(x, y)
        self.wheel_event_manager:invoke_event(WheelEventListener.on_wheel_moved, x, y)
    end
    ---@param x number
    ---@param y number
    ---@param button number
    function love.mousepressed(x, y, button)
        self.pointer_event_manager:pointer_down(x, y, button)
        self.button_event_manager:pointer_down(x, y, button)
    end
    ---@param x number
    ---@param y number
    ---@param button number
    function love.mousereleased(x, y, button)
        self.pointer_event_manager:pointer_up(x, y, button)
        self.button_event_manager:pointer_up(x, y, button)
    end
    ---@param x number
    ---@param y number
    function love.mousemoved(x, y)
        self.pointer_event_manager:pointer_move(x, y, nil)
        self.button_event_manager:pointer_move(x, y, nil)
    end
    ---@param id lightuserdata
    ---@param x number
    ---@param y number
    function love.touchpressed(id, x, y)
        self.pointer_event_manager:pointer_down(x, y, id)
        self.button_event_manager:pointer_down(x, y, id)
    end
    ---@param id lightuserdata
    ---@param x number
    ---@param y number
    function love.touchreleased(id, x, y)
        self.pointer_event_manager:pointer_up(x, y, id)
        self.button_event_manager:pointer_up(x, y, id)
    end
    ---@param id lightuserdata
    ---@param x number
    ---@param y number
    function love.touchmoved(id, x, y)
        self.pointer_event_manager:pointer_move(x, y, id)
        self.button_event_manager:pointer_move(x, y, id)
    end
    ---@param dropped_file love.DroppedFile
    function love.filedropped(dropped_file)
        self.file_system_drop_event_manager:file_drop(dropped_file)
    end
    ---@param text string
    function love.textinput(text)
        self.text_event_manager:text_input(text)
    end
    function love.resize()
        self.resize_manager:resize()
    end
end

return Client
