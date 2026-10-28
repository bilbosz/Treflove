local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local ScreenManager = require("screens.screen-manager")
local BackstackManager = require("utils.backstack-manager")

---@class menu_client
local menu_client = {}

---@return AppMock With a root, a screen manager, a back stack and a notification manager
function menu_client.install()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500
    app_mock.screen_manager = ScreenManager()
    app_mock.backstack_manager = BackstackManager()
    app_mock.notification_manager = mocks.make_notification_manager()
    return app_mock
end

---Shows `screen`, runs `fn` and destroys the screen, by an error too
---@param screen MenuScreen
---@param fn fun()
function menu_client.with_screen(screen, fn)
    app.screen_manager:show(screen)
    ---@type boolean, any
    local ok, err = pcall(fn)
    lifetime.destroy(screen)
    if not ok then
        error(err, 0)
    end
end

---@param ctrl Control
---@param class_name string
---@param found Control[] Output, in draw order
local function _collect(ctrl, class_name, found)
    if get_class_name_of(ctrl) == class_name then
        table.insert(found, ctrl)
    end
    for _, child in ipairs(ctrl:get_children()) do
        _collect(child, class_name, found)
    end
end

---@param screen Screen
---@param class_name string The exact class name
---@return Control[] In draw order
function menu_client.find_all(screen, class_name)
    local found = {}
    _collect(screen:get_control(), class_name, found)
    return found
end

---@param screen Screen
---@return TextButton[] In draw order
function menu_client.buttons(screen)
    return menu_client.find_all(screen, "TextButton") --[[@as TextButton[] ]]
end

---@param screen Screen
---@return string[] The buttons' captions, in draw order
function menu_client.captions(screen)
    local result = {}
    for _, button in ipairs(menu_client.buttons(screen)) do
        table.insert(result, button:get_text())
    end
    return result
end

---@param ctrl Control
---@param result string[] Output, in draw order
local function _collect_texts(ctrl, result)
    local class_name = get_class_name_of(ctrl)
    if class_name == "TextInput" then
        return
    end
    if class_name == "Text" then
        table.insert(result, (ctrl --[[@as Text]] ):get_text())
    end
    for _, child in ipairs(ctrl:get_children()) do
        _collect_texts(child, result)
    end
end

---@param screen Screen
---@return string[] The texts that are neither buttons nor in a text field, in draw order
function menu_client.texts(screen)
    local result = {}
    _collect_texts(screen:get_control(), result)
    return result
end

---@param screen Screen
---@param caption string
---@return TextButton
function menu_client.button(screen, caption)
    for _, button in ipairs(menu_client.buttons(screen)) do
        if button:get_text() == caption then
            return button
        end
    end
    error("no button " .. caption)
end

---@param ctrl Control
function menu_client.click(ctrl)
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    local pointer_manager, manager = app.pointer_event_manager, app.button_event_manager
    pointer_manager:dispatch_pointer_move(x, y, nil)
    manager:dispatch_pointer_move(x, y, 1)
    pointer_manager:dispatch_pointer_down(x, y, 1)
    manager:dispatch_pointer_down(x, y, 1)
    pointer_manager:dispatch_pointer_up(x, y, 1)
    manager:dispatch_pointer_up(x, y, 1)
end

return menu_client
