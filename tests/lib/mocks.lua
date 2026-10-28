local lifetime = require("lifetime")
local Consts = require("app.consts")
local Accounts = require("data.accounts")
local Asset = require("data.asset")
local AssetManager = require("data.asset-manager")
local AssetStore = require("data.asset-store")
local Games = require("data.games")
local Event = require("events.event")
local FileSystemDropEventManager = require("events.file-drop-event")
local KeyboardManager = require("events.keyboard")
local PointerEventManager = require("events.pointer-event")
local Session = require("game.session")
local Control = require("controls.control")
local ScreenManager = require("screens.screen-manager")
local BackstackManager = require("utils.backstack-manager")
local Connection = require("networking.connection")
local ButtonEventManager = require("ui.button-event")
local TextEventManager = require("ui.text-event")
local Utils = require("utils.utils")

local mocks = {}

mocks.GAME_ID = "g"

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

---@return FakeSystem
function mocks.make_system()
    ---@class FakeSystem: love.system
    ---@field clipboard string What `getClipboardText` answers and `setClipboardText` sets
    ---@field os string What `getOS` answers, "Linux" at first
    local system = {
        clipboard = "",
        os = "Linux"
    }

    ---@return string
    function system.getClipboardText()
        return system.clipboard
    end

    ---@param text string
    function system.setClipboardText(text)
        system.clipboard = text
    end

    ---@return string
    function system.getOS()
        return system.os
    end

    return system
end

---@param overrides {is_client: boolean, is_server: boolean}|nil Fields merged over the defaults
---@return AppMock
function mocks.make_app(overrides)
    ---@class AppMock: App
    ---@field logs any[][] Arguments of every `app:log` call, in order
    ---@field update_event Event Real event instance, triggerable by tests
    ---@field wheel_event Event Real event instance, triggerable by tests
    ---@field keyboard FakeKeyboard The backend of `keyboard_manager` and `text_event_manager`
    ---@field system FakeSystem The backend of `keyboard_manager` and `text_event_manager`
    ---@field keyboard_manager KeyboardManager Real manager over `keyboard` and `system`
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
    app_mock.keyboard = mocks.make_keyboard()
    app_mock.system = mocks.make_system()
    app_mock.keyboard_manager = KeyboardManager(app_mock.keyboard, app_mock.system)
    app_mock.resize_manager = resize_manager
    app_mock.pointer_event_manager = TestPointerEventManager()
    app_mock.file_system_drop_event_manager = FileSystemDropEventManager()
    app_mock.button_event_manager = ButtonEventManager()
    app_mock.text_event_manager = TextEventManager(app_mock.keyboard, app_mock.system)
    app_mock.asset_manager = AssetManager()

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

---Delivers a request to `connection` as its peer would and runs a frame of
---the global `app`, leaving what the connection sends on its out channel
---@param connection Connection Over fake channels
---@param id string The remote procedure's class name
---@param body RequestBody
function mocks.deliver(connection, id, body)
    ---@type Request
    local request = {
        source = app.is_server and "c" or "s",
        id = id,
        body = body
    }
    connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(request)))
    app.update_event:trigger(0.016)
end

---Delivers a request to `connection` as its peer would, runs a frame of the
---global `app` and returns the body of the response the connection sent
---@param connection Connection Over fake channels
---@param id string The remote procedure's class name
---@param body RequestBody
---@return ResponseBody
function mocks.request(connection, id, body)
    mocks.deliver(connection, id, body)
    local payload = assert(connection:get_out_channel():pop(), "the connection sent no response") --[[@as string]]
    local response = table.from_string(love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload) --[[@as string]] ) --[[@as Response]]
    assert(response.id == id)
    return response.body
end

---Delivers to `connection` the peer's response to a request it sent, as its
---peer would, and runs a frame of the global `app`
---@param connection Connection Over fake channels
---@param id string The remote procedure's class name
---@param body ResponseBody
function mocks.answer(connection, id, body)
    ---@type Response
    local response = {
        source = app.is_client and "c" or "s",
        id = id,
        body = body
    }
    connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(response)))
    app.update_event:trigger(0.016)
end

---@param payload string What a connection pushed on its out channel
---@return Request
function mocks.decode_request(payload)
    return table.from_string(love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload) --[[@as string]] ) --[[@as Request]]
end

---@param login string
---@return string What the client of `login` sends as its auth in these tests
function mocks.client_auth(login)
    return "client auth of " .. login
end

---Under the server app, whose salt it uses
---@param login string
---@return string The `AccountData.auth` that `mocks.client_auth(login)` matches
function mocks.server_auth(login)
    return Utils.hash(login .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. mocks.client_auth(login))
end

---Under the server app, whose salt it uses
---@param logins string[]
---@return string The content of an accounts file where each login, named after itself, has the auth `mocks.client_auth(login)` matches
function mocks.accounts_file(logins)
    ---@type table<string, AccountData>
    local accounts = {}
    for _, login in ipairs(logins) do
        accounts[login] = {
            name = login,
            auth = mocks.server_auth(login)
        }
    end
    return table.to_string(accounts)
end

---@param id string|nil Defaults to `mocks.GAME_ID`
---@return AssetStore The server's store of the game
function mocks.server_store(id)
    return AssetStore(Consts.SERVER_ROOT .. "/games/" .. (id or mocks.GAME_ID))
end

---@param id string|nil Defaults to `mocks.GAME_ID`
---@return AssetStore The client's copies of the game's assets
function mocks.client_store(id)
    return AssetStore(Consts.CLIENT_ROOT .. "/games/" .. (id or mocks.GAME_ID))
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

---Logs a server's session in and joins a game, as the client of `login` would
---@param connection Connection
---@param login string
---@return GameDataResponse The game `mocks.GAME_ID`'s
function mocks.join_game(connection, login)
    assert(mocks.log_in(connection, login) == login, "the server knows " .. login)
    return mocks.request(connection, "GameDataRp", {
        game = mocks.GAME_ID
    }) --[[@as GameDataResponse]]
end

---Another server session over a connection of its own, logged in as `login`
---and in the game `mocks.GAME_ID`; destroying the connection ends it
---@param login string
---@return Connection
---@return Session
function mocks.join_another(login)
    local connection = Connection(mocks.make_channel(), mocks.make_channel())
    local session = Session(connection):attach_lifetime(connection)
    mocks.join_game(connection, login)
    return connection, session
end

---@param connection Connection Over fake channels
---@return Request[] What the connection sent since the last call, decoded
function mocks.sent(connection)
    ---@type Request[]
    local requests = {}
    local out_channel = connection:get_out_channel()
    while out_channel:getCount() > 0 do
        local payload = out_channel:pop()
        if payload then
            table.insert(requests, mocks.decode_request(payload --[[@as string]] ))
        end
    end
    return requests
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

---A server app with its accounts, its games and its asset manager over an
---in-memory file system and one session on a fake connection;
---`finish_server_session` tears it down
---@param make_data fun(): GameData The game `mocks.GAME_ID`, written to its `save.lua`; every player in it gets an account unless `files` has an accounts file
---@param files table<string, string> The file system, the game's assets under `s/games/<mocks.GAME_ID>/assets/`
---@return TestServerSide
function mocks.make_server_session(make_data, files)
    local server = mocks.install_app({
        is_client = false,
        is_server = true
    })
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    local data = make_data()
    local root = Consts.SERVER_ROOT
    files[root .. "/games/" .. mocks.GAME_ID .. "/save.lua"] = table.to_string(data)
    if not files[root .. "/accounts.lua"] then
        ---@type string[]
        local logins = {}
        for login in pairs(data.players) do
            table.insert(logins, login)
        end
        files[root .. "/accounts.lua"] = mocks.accounts_file(logins)
    end
    local previous = mocks.install_love_filesystem(files)
    server.accounts = Accounts(Asset(root .. "/accounts.lua"))
    server.games = Games(root .. "/games")
    server.asset_manager = AssetManager()
    local connection = Connection(mocks.make_channel(), mocks.make_channel())
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

---@param files table<string, string> The file system, the client's copies under `c/games/<mocks.GAME_ID>/assets/`, the store of the joined game
---@return TestClientSide
function mocks.make_client_session(files)
    local client = mocks.install_app()
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    local previous = mocks.install_love_filesystem(files)
    local notifications = mocks.make_notification_manager()
    client.notification_manager = notifications
    client.asset_manager = AssetManager()
    client.asset_manager:set_store(mocks.client_store())
    local connection = Connection(mocks.make_channel(), mocks.make_channel())
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

---The game the entry procedures' suites play: adam the master, piotr a
---player who reads the game, the page P, the groups and the players and
---writes P, ewa a watcher who reads everything and Q by a grant of her own,
---olga in a group the game does not have
---@return GameData
function mocks.entries_game_data()
    return {
        name = "G",
        game = {
            page = "P"
        },
        groups = {
            master = {
                title = "Game master",
                permissions = {
                    "read",
                    "write"
                }
            },
            player = {
                title = "Player",
                permissions = {
                    "read:game",
                    "read:pages/P",
                    "read:groups",
                    "read:players"
                }
            },
            watcher = {
                title = "Watcher",
                permissions = {
                    "read"
                }
            }
        },
        players = {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player",
                permissions = {
                    "write:pages/P"
                }
            },
            ewa = {
                group = "watcher",
                permissions = {
                    "view:pages/Q"
                }
            },
            olga = {
                group = "guests"
            }
        },
        pages = {
            P = {
                name = "Plains",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "T"
                }
            },
            Q = {
                name = "Quarry",
                width = 5,
                pixel_per_meter = 20,
                image = "world/w.png",
                tokens = {}
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            },
            diameter = {
                title = "Diameter",
                type = "number"
            },
            avatar = {
                title = "Avatar",
                type = "image"
            },
            position = {
                title = "Position",
                type = "array"
            },
            hp = {
                title = "HP",
                type = "number"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 1,
                avatar = "token/t.png",
                position = {
                    1,
                    2
                },
                hp = 3
            }
        }
    }
end

---Logs the client's session in as `login`, which shows the menu, and gives
---it the game data and the grants a join would, with no game screen
---@param side TestClientSide
---@param login string
---@param data GameData
---@param grants string[]
function mocks.join_client_game(side, login, data, grants)
    local client = side.client
    mocks.ensure_love_graphics()
    client.root = Control()
    client.width, client.height = 2000, 1500
    client.screen_manager = ScreenManager()
    client.backstack_manager = BackstackManager()
    ---@diagnostic disable-next-line: invisible
    side.session._login._login_rp.on_login(login)
    client.data = data
    side.session:set_grants(grants)
end

---@class TestGameScreen: GameScreen
---@field calls string[] Every call the session made, in order: `show_page <id>`, `on_entries_change <kind> <id>`, `on_grants_change`
local TestGameScreen = class("TestGameScreen")

function TestGameScreen:init()
    self.calls = {}
end

---@param id string
function TestGameScreen:show_page(id)
    table.insert(self.calls, "show_page " .. id)
end

---@param kind EntryKind
---@param id string
function TestGameScreen:on_entries_change(kind, id)
    table.insert(self.calls, "on_entries_change " .. kind .. " " .. id)
end

function TestGameScreen:on_grants_change()
    table.insert(self.calls, "on_grants_change")
end

---A stand-in for the game screen that records what the session tells it;
---the session's `_game_screen` takes it
---@return TestGameScreen
function mocks.make_game_screen()
    return TestGameScreen()
end

---@param side TestClientSide
function mocks.finish_client_session(side)
    lifetime.destroy(side.connection)
    mocks.restore_love_filesystem(side.previous_filesystem)
end

---A thread that never runs: `start` records its arguments and marks it
---running until `finish`
---@return FakeThread
function mocks.make_thread()
    ---@class FakeThread: love.Thread
    ---@field starts any[][] The arguments of every `start`, in order
    ---@field _running boolean
    ---@field _error string|nil
    ---@field _released boolean|nil
    local thread = {
        starts = {},
        _running = false,
        _error = nil
    }

    ---@param ... any
    function thread:start(...)
        table.insert(self.starts, {
            ...
        })
        self._running = true
        self._error = nil
    end

    ---Ends the fake run, with `err` as what `getError` reports
    ---@param err string|nil
    function thread:finish(err)
        self._running = false
        self._error = err
    end

    ---@return boolean
    function thread:isRunning()
        return self._running
    end

    ---@return string|nil
    function thread:getError()
        return self._error
    end

    ---Blocks until the thread ends: the fake ends it
    function thread:wait()
        self._running = false
    end

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
        getSupported = function()
            return {
                glsl3 = true
            }
        end,
        newShader = function()
            return {
                send = _no_op
            }
        end,
        newQuad = function()
            return {
                setViewport = _no_op
            }
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
        getScissor = _no_op,
        intersectScissor = _no_op,
        stencil = _no_op,
        setStencilTest = _no_op,
        setLineWidth = _no_op,
        getLineWidth = function()
            return 1
        end
    }
end

---@param files table<string, string> By path; a directory exists with a file under it or once `createDirectory` made it, and `remove` takes only an empty one, as LÖVE's
---@return love.filesystem|nil previous What `love.filesystem` was
function mocks.install_love_filesystem(files)
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    local previous = love.filesystem

    ---@type table<string, boolean> Every directory made explicitly or the parent of a file given at the start, until removed; a write into a missing one fails as it does under LÖVE
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
            local parent = string.match(path, "^(.*)/[^/]*$")
            if parent and not directories[parent] then
                return false
            end
            files[path] = content
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
