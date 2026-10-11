local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Aabb = require("utils.aabb")
local PointerEventManager = require("events.pointer-event")

-- Minimal stand-in for a Control (the real one needs `love.math`): only what
-- the hit-tested dispatch looks at. Handlers record calls into a shared log and
-- return `result` (truthy passes the event through to controls below).
---@class TestHitControl
---@field name string
---@field visible boolean
---@field result boolean|nil Value returned by the handlers
---@field log string[] Shared call log, entries are "name:x,y,arg"
---@field private _aabb Aabb
---@field private _children TestHitControl[]
local TestHitControl = class("TestHitControl")

---@param name string
---@param log string[]
---@param x number
---@param y number
---@param w number
---@param h number
---@param children TestHitControl[]|nil
function TestHitControl:init(name, log, x, y, w, h, children)
    self.name = name
    self.log = log
    self.visible = true
    self.result = nil
    self._aabb = Aabb()
    self._aabb:set_position_and_size(x, y, w, h)
    self._children = children or {}
end

---@return boolean
function TestHitControl:is_visible()
    return self.visible
end

---@return Aabb
function TestHitControl:get_global_recursive_aabb()
    return self._aabb
end

---@return TestHitControl[]
function TestHitControl:get_children()
    return self._children
end

---@param x number
---@param y number
---@param arg any Pointer id or dropped file
---@return boolean|nil
function TestHitControl:on_event(x, y, arg)
    table.insert(self.log, string.format("%s:%s,%s,%s", self.name, tostring(x), tostring(y), tostring(arg)))
    return self.result
end

---@class TestHitTree
---@field log string[]
---@field root TestHitControl 0..100 square
---@field page TestHitControl 0..100 square, child of root
---@field token TestHitControl 10..30 square, child of page
---@field popup TestHitControl 0..50 square, last child of root (drawn on top)

-- root
--   page   (0..100)
--     token  (10..30)
--   popup  (0..50)
---@return TestHitTree
local function _make_tree()
    local log = {}
    local token = TestHitControl("token", log, 10, 10, 20, 20)
    local page = TestHitControl("page", log, 0, 0, 100, 100, {
        token
    })
    local popup = TestHitControl("popup", log, 0, 0, 50, 50)
    local root = TestHitControl("root", log, 0, 0, 100, 100, {
        page,
        popup
    })
    return {
        log = log,
        root = root,
        page = page,
        token = token,
        popup = popup
    }
end

---Install the app mock with `tree.root` as `app.root`.
---@param tree TestHitTree
---@return AppMock
local function _install(tree)
    local app_mock = mocks.install_app()
    app_mock.root = tree.root --[[@as Control]]
    return app_mock
end

---@param manager PointerEventManager
---@param ctrls TestHitControl[]
local function _register_down(manager, ctrls)
    for _, ctrl in ipairs(ctrls) do
        manager.pointer_down:register(ctrl, ctrl.on_event)
    end
end

test.suite("PointerEventManager")

test.case("top-most hit control is called first and passes through on truthy return", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    _register_down(manager, {
        tree.page,
        tree.token,
        tree.popup
    })
    tree.popup.result = true
    tree.token.result = true

    manager:dispatch_pointer_down(20, 20, 1)

    test.assert_deep_eq(tree.log, {
        "popup:20,20,1",
        "token:20,20,1",
        "page:20,20,1"
    })
end)

test.case("falsy return stops the event for lower controls", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    _register_down(manager, {
        tree.page,
        tree.token,
        tree.popup
    })
    tree.popup.result = true
    tree.token.result = false

    manager:dispatch_pointer_down(20, 20, 1)

    test.assert_deep_eq(tree.log, {
        "popup:20,20,1",
        "token:20,20,1"
    })
end)

test.case("receive_through controls below a consumer are still called", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    _register_down(manager, {
        tree.root,
        tree.page,
        tree.token
    })
    manager:set_receive_through(tree.page --[[@as Control]] , true)

    manager:dispatch_pointer_down(20, 20, 1)

    -- token consumes; page receives through; root does not
    test.assert_deep_eq(tree.log, {
        "token:20,20,1",
        "page:20,20,1"
    })

    manager:set_receive_through(tree.page --[[@as Control]] , false)
    tree.log[1], tree.log[2] = nil, nil
    manager:dispatch_pointer_down(20, 20, 1)
    test.assert_deep_eq(tree.log, {
        "token:20,20,1"
    })
end)

test.case("invisible and non-hit controls are skipped, including their subtrees", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    _register_down(manager, {
        tree.root,
        tree.page,
        tree.token,
        tree.popup
    })
    tree.popup.visible = false
    tree.page.visible = true
    tree.page.result = true

    -- (70, 70) misses token and popup; popup is invisible anyway
    manager:dispatch_pointer_down(70, 70, 1)
    test.assert_deep_eq(tree.log, {
        "page:70,70,1",
        "root:70,70,1"
    })

    -- an invisible page hides the token inside it as well
    tree.log[1], tree.log[2] = nil, nil
    tree.page.visible = false
    manager:dispatch_pointer_down(20, 20, 1)
    test.assert_deep_eq(tree.log, {
        "root:20,20,1"
    })
end)

test.case("controls without a handler on the event are not called", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    manager.pointer_up:register(tree.token, tree.token.on_event)
    _register_down(manager, {
        tree.page
    })

    manager:dispatch_pointer_up(20, 20, 2)

    test.assert_deep_eq(tree.log, {
        "token:20,20,2"
    })
end)

test.case("pointer_move with nil id reuses the pressed id until release", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    manager.pointer_move:register(tree.token, tree.token.on_event)

    manager:dispatch_pointer_move(15, 15, nil)
    manager:dispatch_pointer_down(15, 15, 3)
    manager:dispatch_pointer_move(16, 16, nil)
    manager:dispatch_pointer_move(17, 17, 7)
    manager:dispatch_pointer_up(17, 17, 3)
    manager:dispatch_pointer_move(18, 18, nil)

    test.assert_deep_eq(tree.log, {
        "token:15,15,nil",
        "token:16,16,3",
        "token:17,17,7",
        "token:18,18,nil"
    })
end)

test.case("controls unregistered during a dispatch are skipped, new ones are not called", function()
    local tree = _make_tree()
    _install(tree)
    local manager = PointerEventManager()
    _register_down(manager, {
        tree.page
    })
    ---@param ctrl TestHitControl
    ---@param x number
    ---@param y number
    ---@param id PointerId
    ---@return boolean
    local function _on_token_down(ctrl, x, y, id)
        ctrl:on_event(x, y, id)
        manager.pointer_down:unregister(tree.page)
        manager.pointer_down:register(tree.popup, tree.popup.on_event)
        return true
    end
    manager.pointer_down:register(tree.token, _on_token_down)

    manager:dispatch_pointer_down(20, 20, 1)

    test.assert_deep_eq(tree.log, {
        "token:20,20,1"
    })
end)

test.suite("FileSystemDropEventManager")

test.case("file drops use the same hit-tested order at the pointer position", function()
    local tree = _make_tree()
    local app_mock = _install(tree)
    local manager = app_mock.file_system_drop_event_manager
    for _, ctrl in ipairs({
        tree.root,
        tree.page,
        tree.token,
        tree.popup
    }) do
        manager.file_dropped:register(ctrl, ctrl.on_event)
    end
    tree.popup.result = true
    manager:set_receive_through(tree.root --[[@as Control]] , true)
    app_mock:set_pointer_position(20, 25)

    manager:file_drop("file" --[[@as love.DroppedFile]] )

    -- popup passes, token consumes, page is skipped, root receives through
    test.assert_deep_eq(tree.log, {
        "popup:20,25,file",
        "token:20,25,file",
        "root:20,25,file"
    })
end)
