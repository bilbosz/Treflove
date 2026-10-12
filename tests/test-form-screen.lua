local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local FormScreen = require("ui.form-screen")
local Input = require("ui.input")
local lifetime = require("lifetime")

-- The input's unlinking hook (ui/input.tlt, idiom B of lua-lifetime
-- trial/treflove/README.md): `Input:init` attaches it `!@ (form_screen,
-- self)`, and `FormScreen:release` sets the flag it reads. The three orders
-- of the trial's test case 2, each log compared whole. A line starting with
-- `>` is the statement that runs next, so each death sits under the
-- statement that caused it. Expected sequences follow lua-lifetime
-- docs/02-semantics.md: a hook runs after its anchor's destructor, among
-- its dependents ("Hooks: the `!@` operator"); a cascade runs the owner's
-- destructor first, then its dependents most recently attached first, a
-- dependent already destroyed skipped ("Cascading death").

local log = {}

---@param line string
local function trace(line)
    table.insert(log, line)
end

-- The real FormScreen, its release and remove_input logged.
local TestFormScreen = class("TestFormScreen", FormScreen)

function TestFormScreen:release(reason)
    trace("TestFormScreen:release(" .. tostring(reason) .. ")")
    FormScreen.release(self, reason)
end

---@param input TestFormInput
function TestFormScreen:remove_input(input)
    trace("TestFormScreen:remove_input(" .. input.name .. ")")
    FormScreen.remove_input(self, input)
end

-- The Input mixin needs a concrete class, as TextInput and TextButton are;
-- a release of its own logs its death (Input has none).
---@class TestFormInput: Input
---@field name string
local TestFormInput = class("TestFormInput", Input)

---@param form_screen FormScreen
---@param name string
function TestFormInput:init(form_screen, name)
    self.name = name
    Input.init(self, form_screen)
end

function TestFormInput:release(reason)
    trace("TestFormInput:release(" .. tostring(reason) .. ") " .. self.name)
end

---@param inputs TestFormInput[]
---@return string
local function names(inputs)
    local out = {}
    for i, input in ipairs(inputs) do
        out[i] = lifetime.alive(input) and input.name or tostring(lifetime.alive(input))
    end
    return "{" .. table.concat(out, ", ") .. "}"
end

-- Two collections must find nothing left to run (nothing goes to
-- destroyerror either).
local function collect()
    trace("> collectgarbage twice")
    local previous = rawget(_G, "destroyerror")
    rawset(_G, "destroyerror", function(_, err)
        trace("destroyerror: " .. tostring(err))
    end)
    collectgarbage("collect")
    collectgarbage("collect")
    rawset(_G, "destroyerror", previous)
end

local function setup()
    mocks.install_app()
    mocks.ensure_love_math()
    log = {}
end

test.suite("FormScreen")

test.case("an input that dies first is unlinked by its hook, after its own release", function()
    setup()
    local form = TestFormScreen()
    local a = TestFormInput(form, "a")
    local b = TestFormInput(form, "b")
    local inputs = form._inputs
    trace("inputs: " .. names(inputs))
    trace("> lifetime.destroy(a)")
    lifetime.destroy(a)
    trace("inputs: " .. names(inputs) .. ", a alive: " .. tostring(lifetime.alive(a)) .. ", b alive: " .. tostring(lifetime.alive(b)))
    trace("> lifetime.destroy(form)")
    lifetime.destroy(form)
    trace("> lifetime.destroy(b)")
    lifetime.destroy(b)
    collect()
    test.assert_deep_eq(log, {
        "inputs: {a, b}",
        "> lifetime.destroy(a)",
        "TestFormInput:release(destroy) a",
        "TestFormScreen:remove_input(a)",
        "inputs: {b}, a alive: false, b alive: true",
        "> lifetime.destroy(form)",
        "TestFormScreen:release(destroy)",
        "> lifetime.destroy(b)",
        "TestFormInput:release(destroy) b",
        "> collectgarbage twice"
    })
end)

test.case("a form that dies first: its release sets the flag and the hooks do nothing", function()
    setup()
    local form = TestFormScreen()
    local a = TestFormInput(form, "a")
    local b = TestFormInput(form, "b")
    local inputs = form._inputs
    trace("hooks on a: " .. #lifetime.dependents(a) .. ", on b: " .. #lifetime.dependents(b))
    trace("> lifetime.destroy(form)")
    lifetime.destroy(form)
    trace("inputs: " .. names(inputs) .. ", form alive: " .. tostring(lifetime.alive(form)))
    trace("hooks on a: " .. #lifetime.dependents(a) .. ", on b: " .. #lifetime.dependents(b))
    trace("> lifetime.destroy(a)")
    lifetime.destroy(a)
    trace("> lifetime.destroy(b)")
    lifetime.destroy(b)
    collect()
    test.assert_deep_eq(log, {
        "hooks on a: 1, on b: 1",
        "> lifetime.destroy(form)",
        "TestFormScreen:release(destroy)",
        "inputs: {a, b}, form alive: false",
        "hooks on a: 0, on b: 0",
        "> lifetime.destroy(a)",
        "TestFormInput:release(destroy) a",
        "> lifetime.destroy(b)",
        "TestFormInput:release(destroy) b",
        "> collectgarbage twice"
    })
end)

-- The inputs owned by the form, the form by a period: each input is
-- anchored to the form after its init attached its hook, so the form's
-- dependents read hook a, a, hook b, b; newest first reaches b (whose hook
-- then runs as b's dependent and finds the flag), b's hook again (dead,
-- skipped), then a the same way.
test.case("form and inputs in one cascade: the form first, nothing unlinked, no error", function()
    setup()
    local period = lifetime.token("period")
    local form = lifetime.attach(TestFormScreen(), false, period)
    lifetime.attach(TestFormInput(form, "a"), false, form)
    lifetime.attach(TestFormInput(form, "b"), false, form)
    local inputs = form._inputs
    trace("> lifetime.destroy(period)")
    lifetime.destroy(period)
    trace("inputs: " .. names(inputs) .. ", form alive: " .. tostring(lifetime.alive(form)))
    collect()
    test.assert_deep_eq(log, {
        "> lifetime.destroy(period)",
        "TestFormScreen:release(anchor)",
        "TestFormInput:release(anchor) b",
        "TestFormInput:release(anchor) a",
        "inputs: {false, false}, form alive: false",
        "> collectgarbage twice"
    })
end)
