local lifetime = require("lifetime")
local Consts = require("app.consts")
local AssetManager = require("data.asset-manager")
local Event = require("events.event")
local FileSystemDropEventManager = require("events.file-drop-event")
local KeyboardManager = require("events.keyboard")
local PointerEventManager = require("events.pointer-event")
local Session = require("game.session")
local Connection = require("networking.connection")
local ButtonEventManager = require("ui.button-event")
local TextEventManager = require("ui.text-event")
local Utils = require("utils.utils")

local mocks = {}

---@class TestPointerEventManager: PointerEventManager
---@field position [number, number]
local TestPointerEventManager = class("TestPointerEventManager", PointerEventManager)

function TestPointerEventManager:init()
    PointerEventManager.init(self)
    self.position = {
        0,
        0
    }
end

---@return number, number
function TestPointerEventManager:get_position()
    return self.position[1], self.position[2]
end

---@return FakeKeyboard
function mocks.make_keyboard()
    ---@class FakeKeyboard: love.keyboard
    ---@field text_input boolean
    ---@field key_repeat boolean
    ---@field down table<love.KeyConstant, boolean> Keys reported as held by `isDown`
    local keyboard = {
        text_input = false,
        key_repeat = false,
        down = {}
    }

    ---@param enable boolean
    function keyboard.setTextInput(enable)
        keyboard.text_input = enable
    end

    ---@return boolean
    function keyboard.hasTextInput()
        return keyboard.text_input
    end

    ---@param enable boolean
    function keyboard.setKeyRepeat(enable)
        keyboard.key_repeat = enable
    end

    ---@param ... love.KeyConstant
    ---@return boolean
    function keyboard.isDown(...)
        for _, key in ipairs({
            ...
        }) do
            if keyboard.down[key] then
                return true
            end
        end
        return false
    end

    return keyboard
end

---@param overrides {is_client: boolean, is_server: boolean}|nil Fields merged over the defaults
---@return AppMock
function mocks.make_app(overrides)
    ---@class AppMock: App
    ---@field logs any[][] Arguments of every `app:log` call, in order
    ---@field update_event Event Real event instance, triggerable by tests
    ---@field wheel_event Event Real event instance, triggerable by tests
    ---@field keyboard_manager KeyboardManager Real manager
    ---@field resize_manager ResizeManagerMock Only the `resized` event (no window behind it)
    ---@field pointer_event_manager TestPointerEventManager Real manager, position set by `set_pointer_position`
    ---@field file_system_drop_event_manager FileSystemDropEventManager Real manager
    ---@field private _time number
    local app_mock = {
        is_client = true,
        is_server = false,
        logs = {},
        _time = 0
    }

    ---@return number
    function app_mock:get_time()
        return self._time
    end

    ---@param dt number
    function app_mock:advance_time(dt)
        self._time = self._time + dt
    end

    ---@param ... any
    function app_mock:log(...)
        table.insert(self.logs, {
            ...
        })
    end

    ---@param x number
    ---@param y number
    function app_mock:set_pointer_position(x, y)
        self.pointer_event_manager.position[1], self.pointer_event_manager.position[2] = x, y
    end

    ---@class ResizeManagerMock: ResizeManager
    ---@field resized Event
    local resize_manager = {
        resized = Event()
    }

    app_mock.update_event = Event()
    app_mock.wheel_event = Event()
    app_mock.keyboard_manager = KeyboardManager()
    app_mock.resize_manager = resize_manager
    app_mock.pointer_event_manager = TestPointerEventManager()
    app_mock.file_system_drop_event_manager = FileSystemDropEventManager()
    app_mock.button_event_manager = ButtonEventManager()
    app_mock.text_event_manager = TextEventManager(mocks.make_keyboard())

    if overrides then
        table.merge(app_mock, overrides)
    end
    return app_mock
end

---@param overrides {is_client: boolean, is_server: boolean}|nil
---@return AppMock
function mocks.install_app(overrides)
    local app_mock = mocks.make_app(overrides)
    app = app_mock
    return app_mock
end

---@return FakeChannel
function mocks.make_channel()
    ---@class FakeChannel: love.Channel
    ---@field _queue any[]
    ---@field _released boolean|nil
    local channel = {
        _queue = {}
    }

    ---@param value any
    function channel:push(value)
        table.insert(self._queue, value)
    end

    ---@return any
    function channel:pop()
        return table.remove(self._queue, 1)
    end

    ---@return any
    function channel:demand()
        local value = self:pop()
        assert(value ~= nil, "demand() on an empty fake channel would block forever")
        return value
    end

    ---@return number
    function channel:getCount()
        return #self._queue
    end

    function channel:release()
        self._released = true
    end

    return channel
end

---Delivers a request to `connection` as its peer would, runs a frame of the
---global `app` and returns the body of the response the connection sent
---@param connection Connection Over fake channels
---@param id string The remote procedure's class name
---@param body RequestBody
---@return ResponseBody
function mocks.request(connection, id, body)
    ---@type Request
    local request = {
        source = app.is_server and "c" or "s",
        id = id,
        body = body
    }
    connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(request)))
    app.update_event:trigger(0.016)
    local payload = assert(connection:get_out_channel():pop(), "the connection sent no response") --[[@as string]]
    local response = table.from_string(love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload) --[[@as string]] ) --[[@as Response]]
    assert(response.id == id)
    return response.body
end

---@param login string
---@return string What the client of `login` sends as its auth in these tests
function mocks.client_auth(login)
    return "client auth of " .. login
end

---Under the server app, whose salt it uses
---@param login string
---@return string The `PlayerData.auth` that `mocks.client_auth(login)` matches
function mocks.server_auth(login)
    return Utils.hash(login .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. mocks.client_auth(login))
end

---Logs a server's session in over its connection, as the client of `login` would
---@param connection Connection
---@param login string
---@return string|nil user The logged-in user, `nil` when the server knows no such auth
function mocks.log_in(connection, login)
    local response = mocks.request(connection, "LoginRp", {
        auth = mocks.client_auth(login)
    }) --[[@as LoginResponse]]
    return response.user
end

---@class TestNotificationManager: NotificationManager
---@field messages string[] Every notified message, in order
local TestNotificationManager = class("TestNotificationManager")

function TestNotificationManager:init()
    self.messages = {}
end

---@param message string
function TestNotificationManager:notify(message)
    table.insert(self.messages, message)
end

---@return TestNotificationManager
function mocks.make_notification_manager()
    return TestNotificationManager()
end

---@class TestServerSide
---@field server AppMock The global `app` from `make_server_session` on
---@field connection Connection Over fake channels, driven with `mocks.request`
---@field session Session Not logged in; `mocks.log_in` logs it in
---@field previous_filesystem love.filesystem|nil

---A server app with its asset manager over an in-memory file system and one
---session on a fake connection; `finish_server_session` tears it down
---@param make_data fun(): GameData Called under the server app, whose salt the auths need
---@param files table<string, string> The file system, with something under `server/` for the asset manager to mount
---@return TestServerSide
function mocks.make_server_session(make_data, files)
    local server = mocks.install_app({
        is_client = false,
        is_server = true
    })
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    local previous = mocks.install_love_filesystem(files)
    server.data = make_data()
    server.asset_manager = AssetManager()
    local connection = Connection(mocks.make_channel(), mocks.make_thread(), mocks.make_channel(), mocks.make_thread())
    local session = Session(connection):attach_lifetime(connection)
    return {
        server = server,
        connection = connection,
        session = session,
        previous_filesystem = previous
    }
end

---@param side TestServerSide
function mocks.finish_server_session(side)
    lifetime.destroy(side.connection)
    mocks.restore_love_filesystem(side.previous_filesystem)
end

---@class TestClientSide
---@field client AppMock The global `app` from `make_client_session` on
---@field connection Connection Over fake channels, nobody behind them
---@field session Session Not logged in
---@field notifications TestNotificationManager
---@field previous_filesystem love.filesystem|nil

---A client app with its asset manager over an in-memory file system and
---its session on a fake connection, for a procedure's `receive_response`;
---`finish_client_session` tears it down
---@param files table<string, string> The file system, the client's copies under `c/assets/`
---@return TestClientSide
function mocks.make_client_session(files)
    local client = mocks.install_app()
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    local previous = mocks.install_love_filesystem(files)
    local notifications = mocks.make_notification_manager()
    client.notification_manager = notifications
    client.asset_manager = AssetManager()
    local connection = Connection(mocks.make_channel(), mocks.make_thread(), mocks.make_channel(), mocks.make_thread())
    local session = Session(connection):attach_lifetime(connection)
    client.session = session
    return {
        client = client,
        connection = connection,
        session = session,
        notifications = notifications,
        previous_filesystem = previous
    }
end

---@param side TestClientSide
function mocks.finish_client_session(side)
    lifetime.destroy(side.connection)
    mocks.restore_love_filesystem(side.previous_filesystem)
end

---@return FakeThread
function mocks.make_thread()
    ---@class FakeThread: love.Thread
    ---@field _released boolean|nil
    local thread = {}

    function thread:release()
        self._released = true
    end

    return thread
end

function mocks.ensure_love_thread()
    if love and love.thread then
        return
    end
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.thread = {
        newChannel = mocks.make_channel
    }
end

local function _no_op()
end

---Fakes under both runners: plain LuaJIT has no `love`, and `love . test`
---has no window, so the real module refuses every call.
function mocks.ensure_love_graphics()
    local function new_font(_, size)
        return {
            getHeight = function()
                return size
            end
        }
    end
    if love and love.graphics and love.window and love.window.isOpen() then
        return
    end
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        newFont = new_font,
        newText = function(_, text)
            return {
                getDimensions = function()
                    return 10 * #text, 20
                end,
                setFont = _no_op
            }
        end,
        newImage = function()
            return {
                getDimensions = function()
                    return 64, 64
                end,
                setFilter = _no_op,
                setMipmapFilter = _no_op
            }
        end,
        newShader = function()
            return {}
        end,
        getDimensions = function()
            return 800, 600
        end,
        setColor = _no_op,
        draw = _no_op,
        circle = _no_op,
        rectangle = _no_op,
        setShader = _no_op,
        reset = _no_op,
        push = _no_op,
        pop = _no_op,
        replaceTransform = _no_op,
        origin = _no_op,
        translate = _no_op,
        scale = _no_op,
        setScissor = _no_op,
        stencil = _no_op,
        setStencilTest = _no_op,
        setLineWidth = _no_op
    }
end

---Files by path; a directory exists with a file under it or once
---`createDirectory` made it, and `remove` takes only an empty one, as LÖVE's
---@param files table<string, string>
---@return love.filesystem|nil previous What `love.filesystem` was
function mocks.install_love_filesystem(files)
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    local previous = love.filesystem

    ---@type table<string, boolean> Every directory: made explicitly, or a file's parent, until removed
    local directories = {}

    ---@param path string
    local function add_directory(path)
        ---@type string|nil
        local made
        for component in string.gmatch(path, "[^/]+") do
            made = made and made .. "/" .. component or component
            directories[made] = true
        end
    end

    for k in pairs(files) do
        local parent = string.match(k, "^(.*)/[^/]*$")
        if parent then
            add_directory(parent)
        end
    end

    ---@param path string
    ---@return boolean
    local function is_directory(path)
        return directories[path] == true
    end

    ---@param path string
    ---@return string[]
    local function directory_items(path)
        local prefix = path .. "/"
        ---@type table<string, boolean>, string[]
        local seen, items = {}, {}
        ---@param k string
        local function add(k)
            if string.sub(k, 1, #prefix) == prefix then
                local rest = string.sub(k, #prefix + 1)
                local item = string.match(rest, "^[^/]+")
                if item and not seen[item] then
                    seen[item] = true
                    table.insert(items, item)
                end
            end
        end
        for k in pairs(files) do
            add(k)
        end
        for k in pairs(directories) do
            add(k)
        end
        table.sort(items)
        return items
    end

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.filesystem = {
        ---@param path string
        ---@return {type: love.FileType, size: number|nil}|nil
        getInfo = function(path)
            local content = files[path]
            if content then
                return {
                    type = "file",
                    size = #content
                }
            end
            if is_directory(path) then
                return {
                    type = "directory"
                }
            end
            return nil
        end,
        ---@param path string
        ---@return string|nil contents
        ---@return number|nil size
        read = function(path)
            local content = files[path]
            return content, content and #content
        end,
        ---@param path string
        ---@return string|nil The bytes: what the fake constructors take
        newFileData = function(path)
            return files[path]
        end,
        ---@param path string
        ---@param content string
        ---@return boolean
        write = function(path, content)
            files[path] = content
            local parent = string.match(path, "^(.*)/[^/]*$")
            if parent then
                add_directory(parent)
            end
            return true
        end,
        ---@param path string
        ---@return boolean
        createDirectory = function(path)
            add_directory(path)
            return true
        end,
        getDirectoryItems = directory_items,
        ---@param path string
        ---@return boolean
        remove = function(path)
            if files[path] then
                files[path] = nil
                return true
            end
            if is_directory(path) and #directory_items(path) == 0 then
                directories[path] = nil
                return true
            end
            return false
        end
    }
    return previous
end

---@param previous love.filesystem|nil
function mocks.restore_love_filesystem(previous)
    love.filesystem = previous
end

function mocks.ensure_love_data()
    if love and love.data then
        return
    end
    local PREFIX = "fake-compressed:"
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.data = {
        compress = function(_, _, str)
            return PREFIX .. str
        end,
        decompress = function(_, _, payload)
            return string.sub(payload, #PREFIX + 1)
        end,
        encode = function(_, _, str)
            return (string.gsub(str, ".", function(c)
                return string.format("%02x", string.byte(c))
            end))
        end,
        decode = function(_, _, str)
            return (string.gsub(str, "%x%x", function(hex)
                return string.char(tonumber(hex, 16))
            end))
        end,
        hash = function(_, str)
            local h = 5381
            for i = 1, #str do
                h = (h * 33 + string.byte(str, i)) % 4294967296
            end
            return string.format("%08x", h)
        end
    }
end

---Column-major, as LÖVE's `getMatrix`.
---@class FakeTransform: love.Transform
---@field a number
---@field b number
---@field c number
---@field d number
---@field tx number
---@field ty number
local FakeTransform = {}
FakeTransform.__index = FakeTransform

---@return FakeTransform
local function _new_transform()
    return setmetatable({
        a = 1,
        b = 0,
        c = 0,
        d = 1,
        tx = 0,
        ty = 0
    }, FakeTransform)
end

---@param x number
---@param y number
---@param angle number
---@param sx number
---@param sy number
---@param ox number
---@param oy number
---@return FakeTransform
function FakeTransform:setTransformation(x, y, angle, sx, sy, ox, oy)
    local cos, sin = math.cos(angle), math.sin(angle)
    self.a, self.b = cos * sx, sin * sx
    self.c, self.d = -sin * sy, cos * sy
    self.tx = x - (self.a * ox + self.c * oy)
    self.ty = y - (self.b * ox + self.d * oy)
    return self
end

---@param ... number The 16 elements of a row-major 4x4 matrix, as `getMatrix` returns them
---@return FakeTransform
function FakeTransform:setMatrix(...)
    local e1, e2, _, e4, e5, e6, _, e8 = ...
    self.a, self.c, self.tx = e1, e2, e4
    self.b, self.d, self.ty = e5, e6, e8
    return self
end

---@return number e1_1
---@return number e1_2
---@return number e1_3
---@return number e1_4
---@return number e2_1
---@return number e2_2
---@return number e2_3
---@return number e2_4
---@return number e3_1
---@return number e3_2
---@return number e3_3
---@return number e3_4
---@return number e4_1
---@return number e4_2
---@return number e4_3
---@return number e4_4
function FakeTransform:getMatrix()
    return self.a, self.c, 0, self.tx, self.b, self.d, 0, self.ty, 0, 0, 1, 0, 0, 0, 0, 1
end

---@param other FakeTransform
---@return FakeTransform
function FakeTransform:apply(other)
    local a, b, c, d, tx, ty = self.a, self.b, self.c, self.d, self.tx, self.ty
    self.a = a * other.a + c * other.b
    self.b = b * other.a + d * other.b
    self.c = a * other.c + c * other.d
    self.d = b * other.c + d * other.d
    self.tx = a * other.tx + c * other.ty + tx
    self.ty = b * other.tx + d * other.ty + ty
    return self
end

---@return FakeTransform
function FakeTransform:inverse()
    local det = self.a * self.d - self.b * self.c
    local inv = _new_transform()
    inv.a, inv.b, inv.c, inv.d = self.d / det, -self.b / det, -self.c / det, self.a / det
    inv.tx = -(inv.a * self.tx + inv.c * self.ty)
    inv.ty = -(inv.b * self.tx + inv.d * self.ty)
    return inv
end

---@param x number
---@param y number
---@return number, number
function FakeTransform:transformPoint(x, y)
    return self.a * x + self.c * y + self.tx, self.b * x + self.d * y + self.ty
end

---@param x number
---@param y number
---@return number, number
function FakeTransform:inverseTransformPoint(x, y)
    return self:inverse():transformPoint(x, y)
end

function mocks.ensure_love_math()
    if love and love.math then
        return
    end
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.math = {
        newTransform = _new_transform,
        newRandomGenerator = function()
            local state = 1
            return {
                ---@param _ love.RandomGenerator
                ---@param seed number
                setSeed = function(_, seed)
                    state = seed % 2147483647
                end,
                ---@param _ love.RandomGenerator
                ---@param lo number
                ---@param hi number
                ---@return number
                random = function(_, lo, hi)
                    state = (state * 16807) % 2147483647
                    return lo + state % (hi - lo + 1)
                end
            }
        end
    }
end

return mocks
