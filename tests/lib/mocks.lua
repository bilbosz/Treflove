local Event = require("events.event")
local FileSystemDropEventManager = require("events.file-drop-event")
local KeyboardManager = require("events.keyboard")
local PointerEventManager = require("events.pointer-event")

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
    ---@class FakeKeyboard
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

---@param overrides table|nil Fields merged over the defaults
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

    ---@class ResizeManagerMock
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

    if overrides then
        table.merge(app_mock, overrides)
    end
    return app_mock
end

---@param overrides table|nil
---@return AppMock
function mocks.install_app(overrides)
    local app_mock = mocks.make_app(overrides)
    app = app_mock
    return app_mock
end

---@return FakeChannel
function mocks.make_channel()
    ---@class FakeChannel
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

---@return table
function mocks.make_thread()
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
    local Consts = require("app.consts")
    local function new_font()
        return {
            getHeight = function()
                return 80
            end
        }
    end
    -- Consts loads the fonts only with a window
    Consts.DISPLAY_FONT = Consts.DISPLAY_FONT or new_font()
    Consts.USER_INPUT_FONT = Consts.USER_INPUT_FONT or new_font()
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
                end
            }
        end,
        newImage = function()
            return {
                getDimensions = function()
                    return 64, 64
                end
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
        setScissor = _no_op,
        stencil = _no_op,
        setStencilTest = _no_op,
        setLineWidth = _no_op
    }
end

---@param files table<string, string>
---@return table|nil previous What `love.filesystem` was
function mocks.install_love_filesystem(files)
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    local previous = love.filesystem

    ---@param path string
    ---@return boolean
    local function is_directory(path)
        local prefix = path .. "/"
        for k in pairs(files) do
            if string.sub(k, 1, #prefix) == prefix then
                return true
            end
        end
        return false
    end

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.filesystem = {
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
        read = function(path)
            local content = files[path]
            return content, content and #content
        end,
        write = function(path, content)
            files[path] = content
            return true
        end,
        createDirectory = function()
            return true
        end,
        getDirectoryItems = function(path)
            local prefix = path .. "/"
            local seen, items = {}, {}
            for k in pairs(files) do
                if string.sub(k, 1, #prefix) == prefix then
                    local rest = string.sub(k, #prefix + 1)
                    local item = string.match(rest, "^[^/]+")
                    if item and not seen[item] then
                        seen[item] = true
                        table.insert(items, item)
                    end
                end
            end
            table.sort(items)
            return items
        end,
        remove = function(path)
            files[path] = nil
            return true
        end
    }
    return previous
end

---@param previous table|nil
function mocks.restore_love_filesystem(previous)
    ---@diagnostic disable-next-line: assign-type-mismatch
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
---@class FakeTransform
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

---@return number ...
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
                setSeed = function(_, seed)
                    state = seed % 2147483647
                end,
                random = function(_, lo, hi)
                    state = (state * 16807) % 2147483647
                    return lo + state % (hi - lo + 1)
                end
            }
        end
    }
end

return mocks
