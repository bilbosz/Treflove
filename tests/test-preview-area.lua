local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local PreviewArea = require("game.assets.preview-area.preview-area")

---@class TestDropTarget: Control, FileDropTarget
---@field files love.DroppedFile[] The files handed over, in order
---@field fail boolean Raise instead of taking the file
local TestDropTarget = class("TestDropTarget", Control)

function TestDropTarget:init()
    Control.init(self, nil, 100, 100)
    self.files = {}
    self.fail = false
end

---@param file love.DroppedFile
function TestDropTarget:set_file(file)
    if self.fail then
        error("cannot read the file")
    end
    table.insert(self.files, file)
end

---@param log string[]
---@return TestDroppedFile
local function make_file(log)
    ---@class TestDroppedFile: love.DroppedFile
    local file = {}

    ---@param mode string
    ---@return boolean
    function file:open(mode)
        table.insert(log, "open " .. mode)
        return true
    end

    ---@return boolean
    function file:close()
        table.insert(log, "close")
        return true
    end

    return file
end

---@return AppMock
---@return TestDropTarget
---@return PreviewArea
local function setup()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local target = TestDropTarget()
    local area = PreviewArea(target, 100, 100, target)
    return app_mock, target, area
end

test.suite("PreviewArea")

test.case("a dropped file is closed once the drop has been handled", function()
    local _, target, area = setup()
    local log = {}
    local file = make_file(log)
    area:on_file_system_drop(0, 0, file)
    test.assert_deep_eq(log, {
        "open r",
        "close"
    })
    test.assert_deep_eq(target.files, {
        file
    })
end)

test.case("a dropped file is closed when handling it raises, before the error reaches the caller", function()
    local _, target, area = setup()
    target.fail = true
    local log = {}
    local file = make_file(log)
    local ok, err = pcall(area.on_file_system_drop, area, 0, 0, file)
    test.assert_false(ok)
    test.assert_true(string.find(tostring(err), "cannot read the file", 1, true) ~= nil, tostring(err))
    test.assert_deep_eq(log, {
        "open r",
        "close"
    })
    test.assert_deep_eq(target.files, {})
end)

test.case("destroying the area ends its file-drop registration", function()
    local app_mock, target, area = setup()
    local manager = app_mock.file_system_drop_event_manager
    test.assert_eq(manager.file_dropped:get_handler(area), PreviewArea.on_file_system_drop)
    lifetime.destroy(area)
    test.assert_eq(manager.file_dropped:get_handler(area), nil)
    test.assert_deep_eq(target:get_children(), {}, "the area left the panel")
    test.assert_false(lifetime.alive(area))
end)
