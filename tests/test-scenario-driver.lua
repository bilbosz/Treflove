local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local MainLoop = require("app.main-loop")
local ScenarioDriver = require("app.scenario-driver")
local ScreenManager = require("screens.screen-manager")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local TextInput = require("ui.text-input")

---@class TestScenarioBox: Control
local TestScenarioBox = class("TestScenarioBox", Control)

---@param parent Control
function TestScenarioBox:init(parent)
    Control.init(self, parent, 50, 50)
end

---@class TestScenarioScreen: FormScreen
---@field clicks string[] The caption of every button clicked, in order
---@field hello Text
---@field first_ok TextButton
---@field second_ok TextButton
---@field box TestScenarioBox Holds the text "Label"
---@field hidden_button TextButton Under an invisible control
---@field disabled_button TextButton Under a disabled control
---@field field TextInput
---@field secret TextInput Masked, holding "secret"
local TestScenarioScreen = class("TestScenarioScreen", FormScreen)

---@param self TestScenarioScreen
---@param parent Control
---@param caption string
---@param x number
---@param y number
---@return TextButton
local function _make_button(self, parent, caption, x, y)
    local button = TextButton(parent, self, caption, function()
        table.insert(self.clicks, caption)
    end)
    button:set_position(x, y)
    return button
end

function TestScenarioScreen:init()
    FormScreen.init(self)
    self.clicks = {}
    self.hello = Text(self.screen, "Hello")
    self.first_ok = _make_button(self, self.screen, "OK", 100, 100)
    self.second_ok = _make_button(self, self.screen, "OK", 300, 100)
    self.box = TestScenarioBox(self.screen)
    self.box:set_position(500, 100)
    Text(self.box, "Label")
    local hidden = Control(self.screen)
    hidden:set_visible(false)
    self.hidden_button = _make_button(self, hidden, "Hidden", 700, 100)
    local disabled = Control(self.screen)
    disabled:set_enabled(false)
    self.disabled_button = _make_button(self, disabled, "Disabled", 900, 100)
    self.field = TextInput(self.screen, self, 200, 40, false, nil, nil)
    self.field:set_position(100, 300)
    self.secret = TextInput(self.screen, self, 200, 40, true, nil, nil)
    self.secret:set_position(100, 400)
    self.secret:set_text("secret")
end

---@class TestDriverMainLoop: MainLoop
---@field skips number[] The argument of every `skip`, in order
local TestDriverMainLoop = class("TestDriverMainLoop", MainLoop)

function TestDriverMainLoop:init()
    MainLoop.init(self, true)
    self.skips = {}
end

---@param seconds number
function TestDriverMainLoop:skip(seconds)
    table.insert(self.skips, seconds)
end

---@param reply string The frames the server sends
---@return TestDriverSocket
local function make_socket(reply)
    ---@class TestDriverSocket: ConsoleSocket
    ---@field buffer string What the server answers, received in full
    ---@field sent string
    ---@field port integer|nil Connected to
    ---@field closed boolean
    local fake = {
        buffer = reply,
        sent = "",
        port = nil,
        closed = false
    }

    ---@param _ string
    ---@param port integer
    ---@return integer|nil, string|nil
    function fake:connect(_, port)
        self.port = port
        return 1, nil
    end

    function fake:settimeout()
    end

    ---@param data string
    ---@param i integer|nil
    ---@return integer|nil, string|nil, integer|nil
    function fake:send(data, i)
        self.sent = self.sent .. data:sub(i or 1)
        return #data, nil, nil
    end

    ---@param pattern "*l"|integer
    ---@return string|nil, string|nil, string|nil
    function fake:receive(pattern)
        if type(pattern) == "number" then
            local data = self.buffer:sub(1, pattern)
            self.buffer = self.buffer:sub(pattern + 1)
            return data, nil, nil
        end
        local newline = assert(self.buffer:find("\n", 1, true), "the fake has no line to give")
        local line = self.buffer:sub(1, newline - 1)
        self.buffer = self.buffer:sub(newline + 1)
        return line, nil, nil
    end

    function fake:close()
        self.closed = true
    end

    return fake
end

---@class TestDriverWorld
---@field app AppMock
---@field queue any[][] What `love.event.push` queued, each event its name and arguments
---@field screen TestScenarioScreen Shown
---@field driver ScenarioDriver
---@field main_loop TestDriverMainLoop
---@field exit_codes integer[] The argument of every `app:quit`
---@field screenshots string[] The argument of every `love.graphics.captureScreenshot`
---@field previous_event love.event
---@field previous_graphics love.graphics
---@field previous_filesystem love.filesystem|nil

---@param server_console string|nil
---@param tcp ConsoleSocketFactory|nil
---@param peers table<string, string>|nil
---@return TestDriverWorld
local function setup(server_console, tcp, peers)
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local previous_event, previous_graphics = love.event, assert(love.graphics)
    local previous_filesystem = mocks.install_love_filesystem({})
    ---@type any[][], integer[], string[]
    local queue, exit_codes, screenshots = {}, {}, {}

    ---@class TestDriverFilesystem: love.filesystem
    local filesystem = setmetatable({}, {
        __index = love.filesystem
    })
    ---@return string
    function filesystem.getSaveDirectory()
        return "/save"
    end
    love.filesystem = filesystem

    ---@class TestDriverGraphics: love.graphics
    local graphics = setmetatable({}, {
        __index = previous_graphics
    })
    ---@param filename string
    function graphics.captureScreenshot(filename)
        table.insert(screenshots, filename)
    end
    love.graphics = graphics

    ---@class TestDriverEventModule: love.event
    local event_module = {}
    ---@param ... any
    function event_module.push(...)
        table.insert(queue, {
            ...
        })
    end
    love.event = event_module

    local main_loop = TestDriverMainLoop()
    app_mock.params = {
        app_type = "client",
        address = "localhost",
        port = "8080",
        server_console = server_console,
        headless = true,
        follow = false,
        peers = peers
    }
    app_mock.main_loop = main_loop
    ---@param exit_code integer|nil
    function app_mock:quit(exit_code)
        table.insert(exit_codes, exit_code)
    end
    app_mock.root = Control()
    app_mock.screen_manager = ScreenManager()
    local screen = TestScenarioScreen()
    app_mock.screen_manager:show(screen)
    return {
        app = app_mock,
        queue = queue,
        screen = screen,
        driver = ScenarioDriver(tcp),
        main_loop = main_loop,
        exit_codes = exit_codes,
        screenshots = screenshots,
        previous_event = previous_event,
        previous_graphics = previous_graphics,
        previous_filesystem = previous_filesystem
    }
end

---@param world TestDriverWorld
local function finish(world)
    lifetime.destroy(world.screen)
    lifetime.destroy(world.driver)
    love.event = world.previous_event
    love.graphics = world.previous_graphics
    mocks.restore_love_filesystem(world.previous_filesystem)
end

---@param world TestDriverWorld
local function dispatch(world)
    local app_mock = world.app
    while #world.queue > 0 do
        local event = table.remove(world.queue, 1)
        ---@type love.Event, any, any, any
        local name, a, b, c = event[1], event[2], event[3], event[4]
        if name == "mousemoved" then
            app_mock.pointer_event_manager:dispatch_pointer_move(a, b, nil)
            app_mock.button_event_manager:dispatch_pointer_move(a, b, nil)
        elseif name == "mousepressed" then
            app_mock.pointer_event_manager:dispatch_pointer_down(a, b, c)
            app_mock.button_event_manager:dispatch_pointer_down(a, b, c)
        elseif name == "mousereleased" then
            app_mock.pointer_event_manager:dispatch_pointer_up(a, b, c)
            app_mock.button_event_manager:dispatch_pointer_up(a, b, c)
        elseif name == "keypressed" then
            app_mock.keyboard_manager:dispatch_key_pressed(a)
            app_mock.text_event_manager:key_pressed(a)
        elseif name == "keyreleased" then
            app_mock.keyboard_manager:dispatch_key_released(a)
        elseif name == "textinput" then
            app_mock.text_event_manager:text_input(a)
        else
            error("no dispatch for " .. tostring(name))
        end
    end
end

---@param world TestDriverWorld
---@param fn fun(driver: ScenarioDriver)
---@return thread
local function start(world, fn)
    return coroutine.create(function()
        fn(world.driver)
    end)
end

---@param world TestDriverWorld
---@param co thread
---@return "suspended"|"dead"
local function frame(world, co)
    dispatch(world)
    ---@type boolean, any
    local ok, err = coroutine.resume(co)
    assert(ok, err)
    return coroutine.status(co) == "dead" and "dead" or "suspended"
end

---@param world TestDriverWorld
---@param co thread
---@return string The error the scenario raised at its next resume
local function failure(world, co)
    dispatch(world)
    ---@type boolean, any
    local ok, err = coroutine.resume(co)
    assert(not ok, "the scenario raised no error")
    return tostring(err)
end

---@param ctrl Control
---@return number, number
local function center(ctrl)
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    return (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
end

test.suite("ScenarioDriver")

test.case("find gives the controls of a class name in draw order, the index-th of them", function()
    local world = setup()
    local driver = world.driver
    test.assert_eq(driver:find("TextButton"), world.screen.first_ok)
    test.assert_eq(driver:find("TextButton", nil, 2), world.screen.second_ok)
    test.assert_eq(driver:find("TextInput", nil, 2), world.screen.secret)
    test.assert_eq(driver:find("Control"), world.app.root, "the root is the first control drawn")
    test.assert_eq(driver:try_find("TextButton", nil, 3), nil, "the hidden and the disabled buttons are not counted")
    test.assert_eq(driver:try_find("Input"), nil, "the class name itself, not a base")
    finish(world)
end)

test.case("find matches a control's own text, or a descendant Text's when it has none", function()
    local world = setup()
    local driver = world.driver
    test.assert_eq(driver:find("Text", "Hello"), world.screen.hello)
    test.assert_eq(driver:find("TextButton", "OK", 2), world.screen.second_ok)
    test.assert_eq(driver:find("TestScenarioBox", "Label"), world.screen.box)
    test.assert_eq(driver:find("TextInput", "secret"), world.screen.secret, "a text field's own text, not its masked view")
    test.assert_eq(driver:try_find("TextInput", "******"), nil)
    test.assert_eq(driver:try_find("TextButton", "Hidden"), nil, "under an invisible control")
    test.assert_eq(driver:try_find("TextButton", "Disabled"), nil, "under a disabled control")
    test.assert_eq(driver:try_find("TestScenarioBox", "Hello"), nil)
    finish(world)
end)

test.case("a find that fails raises at the caller's line with the shown screen and the control dump", function()
    local world = setup()
    ---@type boolean, any
    local ok, err = pcall(function()
        world.driver:find("TextButton", "Cancel")
    end)
    test.assert_false(ok)
    local message = tostring(err)
    test.assert_true(message:find("test%-scenario%-driver%.lua:%d+: no TextButton with the text \"Cancel\" on TestScenarioScreen\n") ~= nil, message)
    test.assert_true(message:find("TestScenarioBox[eva]", 1, true) ~= nil, "the dump: " .. message)
    finish(world)
end)

test.case("wait_for yields frames until the predicate holds and returns its value", function()
    local world = setup()
    local checks = 0
    ---@type string|nil
    local value
    local co = start(world, function(driver)
        value = driver:wait_for(function()
            checks = checks + 1
            return checks == 3 and "ready" or nil
        end)
    end)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_eq(frame(world, co), "suspended")
    test.assert_eq(frame(world, co), "dead")
    test.assert_eq(checks, 3)
    test.assert_eq(value, "ready")
    finish(world)
end)

test.case("wait_for raises at the caller's line once its wall-clock timeout passed", function()
    local world = setup()
    local co = start(world, function(driver)
        driver:wait_for(function()
            return false
        end, 0, "the moon")
    end)
    local err = failure(world, co)
    test.assert_true(err:find("test%-scenario%-driver%.lua:%d+: timed out waiting for the moon$") ~= nil, err)
    finish(world)
end)

test.case("wait_screen returns the shown screen of that class, or times out naming it", function()
    local world = setup()
    ---@type Screen|nil
    local screen
    local co = start(world, function(driver)
        screen = driver:wait_screen("TestScenarioScreen")
    end)
    test.assert_eq(frame(world, co), "dead")
    test.assert_eq(screen, world.screen)
    test.assert_eq(world.driver:screen(), world.screen)
    co = start(world, function(driver)
        driver:wait_screen("GameScreen", 0)
    end)
    test.assert_true(failure(world, co):find("timed out waiting for GameScreen", 1, true) ~= nil)
    finish(world)
end)

test.case("click queues a move, a press and a release of button 1 at the control's center, then yields one frame", function()
    local world = setup()
    local x, y = center(world.screen.second_ok)
    local co = start(world, function(driver)
        driver:click("TextButton", "OK", 2)
    end)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.queue, {
        {
            "mousemoved",
            x,
            y,
            0,
            0,
            false
        },
        {
            "mousepressed",
            x,
            y,
            1,
            false,
            1
        },
        {
            "mousereleased",
            x,
            y,
            1,
            false,
            1
        }
    })
    test.assert_deep_eq(world.screen.clicks, {}, "nothing is dispatched before the frame ends")
    test.assert_eq(frame(world, co), "dead")
    test.assert_deep_eq(world.screen.clicks, {
        "OK"
    })
    finish(world)
end)

test.case("click takes a control too", function()
    local world = setup()
    local co = start(world, function(driver)
        driver:click(world.screen.first_ok)
    end)
    frame(world, co)
    test.assert_eq(frame(world, co), "dead")
    test.assert_deep_eq(world.screen.clicks, {
        "OK"
    })
    finish(world)
end)

test.case("type queues one textinput per UTF-8 character into the focused field", function()
    local world = setup()
    local co = start(world, function(driver)
        driver:click("TextInput")
        driver:type("zaż ół")
    end)
    frame(world, co)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.queue, {
        {
            "textinput",
            "z"
        },
        {
            "textinput",
            "a"
        },
        {
            "textinput",
            "ż"
        },
        {
            "textinput",
            " "
        },
        {
            "textinput",
            "ó"
        },
        {
            "textinput",
            "ł"
        }
    })
    test.assert_eq(frame(world, co), "dead")
    test.assert_eq(world.screen.field:get_text(), "zaż ół")
    finish(world)
end)

test.case("key queues the press and the release of the key, then yields one frame", function()
    local world = setup()
    ---@type love.KeyConstant[]
    local pressed, released = {}, {}
    local owner = Control()
    ---@param _ Control
    ---@param key love.KeyConstant
    world.app.keyboard_manager.key_pressed:register(owner, function(_, key)
        table.insert(pressed, key)
    end)
    ---@param _ Control
    ---@param key love.KeyConstant
    world.app.keyboard_manager.key_released:register(owner, function(_, key)
        table.insert(released, key)
    end)
    local co = start(world, function(driver)
        driver:key("f5")
    end)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.queue, {
        {
            "keypressed",
            "f5",
            "f5",
            false
        },
        {
            "keyreleased",
            "f5",
            "f5"
        }
    })
    test.assert_eq(frame(world, co), "dead")
    test.assert_deep_eq(pressed, {
        "f5"
    })
    test.assert_deep_eq(released, {
        "f5"
    })
    finish(world)
end)

test.case("key_down queues the press of the key and key_up its release, each yielding one frame; the key is down between", function()
    local world = setup()
    local keyboard_manager = world.app.keyboard_manager
    ---@type boolean[]
    local ctrl = {}
    local co = start(world, function(driver)
        driver:key_down("lctrl")
        table.insert(ctrl, keyboard_manager:is_ctrl_down())
        driver:key("a")
        table.insert(ctrl, keyboard_manager:is_ctrl_down())
        driver:key_up("lctrl")
        table.insert(ctrl, keyboard_manager:is_ctrl_down())
    end)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.queue, {
        {
            "keypressed",
            "lctrl",
            "lctrl",
            false
        }
    })
    test.assert_eq(frame(world, co), "suspended")
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.queue, {
        {
            "keyreleased",
            "lctrl",
            "lctrl"
        }
    })
    test.assert_eq(frame(world, co), "dead")
    test.assert_deep_eq(ctrl, {
        true,
        true,
        false
    })
    finish(world)
end)

test.case("move, press and release_button only queue their events", function()
    local world = setup()
    local driver = world.driver
    driver:move(1, 2)
    driver:press(3, 4, 2)
    driver:release_button(5, 6)
    test.assert_deep_eq(world.queue, {
        {
            "mousemoved",
            1,
            2,
            0,
            0,
            false
        },
        {
            "mousepressed",
            3,
            4,
            2,
            false,
            1
        },
        {
            "mousereleased",
            5,
            6,
            1,
            false,
            1
        }
    })
    finish(world)
end)

test.case("advance skips the main loop's clock and yields one frame; frames yields n", function()
    local world = setup()
    local co = start(world, function(driver)
        driver:advance(5)
        driver:frames(2)
    end)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.main_loop.skips, {
        5
    })
    test.assert_eq(frame(world, co), "suspended")
    test.assert_eq(frame(world, co), "suspended")
    test.assert_eq(frame(world, co), "dead")
    finish(world)
end)

test.case("expect raises its message at the caller's line when the condition is falsy", function()
    local world = setup()
    world.driver:expect(1, "never raised")
    ---@type boolean, any
    local ok, err = pcall(function()
        world.driver:expect(nil, "the door is open")
    end)
    test.assert_false(ok)
    test.assert_true(tostring(err):find("test%-scenario%-driver%.lua:%d+: the door is open$") ~= nil, tostring(err))
    finish(world)
end)

test.case("log prefixes the app's log; headless follows the command line", function()
    local world = setup()
    world.driver:log("hello")
    test.assert_deep_eq(world.app.logs, {
        {
            "scenario: hello"
        }
    })
    test.assert_true(world.driver.headless)
    finish(world)
end)

test.case("server evaluates a chunk through the server console, connected once, and returns the ok body", function()
    local fake = make_socket("ok 3\none" .. "ok 3\ntwo")
    local connects = 0
    local world = setup("9191", function()
        connects = connects + 1
        return fake
    end)
    test.assert_eq(world.driver:server("return 'one'"), "one")
    test.assert_eq(world.driver:server("return 'two'"), "two")
    test.assert_eq(connects, 1)
    test.assert_eq(fake.sent, "eval 12\nreturn 'one'" .. "eval 12\nreturn 'two'")
    finish(world)
    test.assert_true(fake.closed, "the driver's death closes the console connection")
end)

test.case("server raises with the error body, and without a server console", function()
    local fake = make_socket("error 4\nboom")
    local world = setup("9191", function()
        return fake
    end)
    ---@type boolean, any
    local ok, err = pcall(function()
        world.driver:server("error('boom')")
    end)
    test.assert_false(ok)
    test.assert_true(tostring(err):find("the server console raised: boom", 1, true) ~= nil, tostring(err))
    finish(world)

    world = setup()
    ok, err = pcall(function()
        world.driver:server("return 1")
    end)
    test.assert_false(ok)
    test.assert_true(tostring(err):find("no server console", 1, true) ~= nil, tostring(err))
    finish(world)
end)

test.case("screenshot captures the frame, yields it and returns the path in the save directory", function()
    local world = setup()
    ---@type string|nil
    local path
    local co = start(world, function(driver)
        path = driver:screenshot("shot.png")
    end)
    test.assert_eq(frame(world, co), "suspended")
    test.assert_deep_eq(world.screenshots, {
        "shot.png"
    })
    test.assert_eq(frame(world, co), "dead")
    test.assert_eq(path, "/save/shot.png")
    finish(world)
end)

test.case("quit asks the app to quit with its code and remembers it", function()
    local world = setup()
    test.assert_eq(world.driver:get_exit_code(), nil)
    world.driver:quit(3)
    world.driver:quit()
    test.assert_deep_eq(world.exit_codes, {
        3,
        0
    })
    test.assert_eq(world.driver:get_exit_code(), 0)
    finish(world)
end)

test.case("peers names the command line's peers, sorted, and none without the option", function()
    local world = setup(nil, nil, {
        eve = "9101",
        bob = "9100",
        carol = "9102"
    })
    test.assert_deep_eq(world.driver:peers(), {
        "bob",
        "carol",
        "eve"
    })
    finish(world)
    world = setup()
    test.assert_deep_eq(world.driver:peers(), {})
    finish(world)
end)

test.case("client sends the chunk quoted in a run to the peer's console and returns at once with the handle", function()
    local fake = make_socket("")
    local world = setup(nil, function()
        return fake
    end, {
        bob = "9100"
    })
    local chunk = "steps.log_in(driver, \"piotr\", \"secret\")\nreturn 'in'"
    local run = world.driver:client("bob", chunk)
    test.assert_eq(get_class_name_of(run), "ScenarioPeerRun")
    test.assert_eq(fake.port, 9100)
    local request = string.format("run(%q)", chunk)
    test.assert_eq(fake.sent, string.format("eval %d\n", #request) .. request)
    test.assert_eq(assert(loadstring("return " .. request:sub(5, -2)))(), chunk, "the quoted chunk reads back as the chunk")
    finish(world)
end)

test.case("client connects once per peer, keeps the connections and the driver's death closes them all", function()
    ---@type TestDriverSocket[]
    local sockets = {}
    local world = setup(nil, function()
        local fake = make_socket("")
        table.insert(sockets, fake)
        return fake
    end, {
        bob = "9100",
        eve = "9101"
    })
    world.driver:client("bob", "return 1")
    world.driver:client("eve", "return 2")
    world.driver:client("bob", "return 3")
    test.assert_eq(#sockets, 2)
    test.assert_eq(sockets[1].port, 9100)
    test.assert_eq(sockets[2].port, 9101)
    test.assert_eq(sockets[1].sent, "eval 15\nrun(\"return 1\")" .. "eval 15\nrun(\"return 3\")")
    test.assert_eq(sockets[2].sent, "eval 15\nrun(\"return 2\")")
    test.assert_false(sockets[1].closed)
    finish(world)
    test.assert_true(sockets[1].closed and sockets[2].closed, "the driver's death closes every peer connection")
end)

test.case("client raises at the caller's line for a peer the command line did not give", function()
    local connects = 0
    local world = setup(nil, function()
        connects = connects + 1
        return make_socket("")
    end, {
        bob = "9100"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        world.driver:client("eve", "return 1")
    end)
    test.assert_false(ok)
    test.assert_true(tostring(err):find("test%-scenario%-driver%.lua:%d+: no peer eve$") ~= nil, tostring(err))
    test.assert_eq(connects, 0)
    finish(world)
    world = setup()
    ok, err = pcall(function()
        world.driver:client("bob", "return 1")
    end)
    test.assert_false(ok)
    test.assert_true(tostring(err):find("no peer bob", 1, true) ~= nil, "without the option: " .. tostring(err))
    finish(world)
end)
