local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")

---@param client GameClient
---@return TextButton
local function tokens_button(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen._quick_access_panel._buttons.Tokens
end

---@param client GameClient
---@return number
local function quick_access_width(client)
    ---@diagnostic disable-next-line: invisible
    return (client.game_screen._quick_access_panel:get_size())
end

---@param fn fun(client: GameClient)
local function with_client(fn)
    local client = game_client.enter({
        "read",
        "write"
    })
    ---@type boolean, any
    local ok, err = pcall(fn, client)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

test.suite("GameScreen")

test.case("the token panel is shown beside the page at first, its Tokens entry in the active color", function()
    with_client(function(client)
        local screen = client.game_screen
        local panel = screen:get_token_panel()
        local button = tokens_button(client)
        test.assert_eq(screen:get_panel(), panel)
        test.assert_true(panel:is_enabled())
        test.assert_true(button:is_active())
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_ACTIVE_COLOR)

        local w, h = assert(client.app.width), assert(client.app.height)
        local panel_w = w * Consts.GAME_SIDE_PANEL_SHARE
        local page_w, page_h = screen:get_page():get_size()
        test.assert_eq(page_w, w - panel_w)
        test.assert_eq(page_h, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)
        test.assert_eq(quick_access_width(client), w - panel_w)
        local panel_x, panel_y, actual_panel_w, panel_h = panel:get_position_and_size()
        test.assert_eq(panel_x, w - panel_w)
        test.assert_eq(panel_y, 0)
        test.assert_eq(actual_panel_w, panel_w)
        test.assert_eq(panel_h, h)
    end)
end)

---@param page Page
---@return number[] The page's rectangle on screen
local function map_rect(page)
    local coordinates = page:get_page_coordinates()
    local width = page:get_data().width
    local x0, y0 = coordinates:transform_to_global(0, 0)
    local x1, y1 = coordinates:transform_to_global(width, width)
    return {
        x0,
        y0,
        x1,
        y1
    }
end

test.case("a second click on Tokens hides the side bar and the view fills its strip, the map staying put; a third shows it again", function()
    with_client(function(client)
        local screen = client.game_screen
        local page = screen:get_page()
        local panel = screen:get_token_panel()
        local button = tokens_button(client)
        local w = assert(client.app.width)
        local page_w = w * (1 - Consts.GAME_SIDE_PANEL_SHARE)
        local map = map_rect(page)

        game_client.click(client, button)
        test.assert_eq(screen:get_panel(), nil)
        test.assert_false(panel:is_enabled())
        test.assert_false(button:is_active())
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_HOVER_COLOR, "plain, under the pointer")
        test.assert_eq((page:get_size()), w)
        test.assert_eq((page:get_fit_size()), page_w, "fitted as with the panel shown")
        test.assert_eq(quick_access_width(client), w)
        test.assert_deep_eq(map_rect(page), map, "the map neither scaled nor moved")

        game_client.click(client, button)
        test.assert_eq(screen:get_panel(), panel)
        test.assert_true(panel:is_enabled())
        test.assert_true(button:is_active())
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_ACTIVE_HOVER_COLOR, "active, under the pointer")
        test.assert_eq((page:get_size()), page_w)
        test.assert_eq((page:get_fit_size()), page_w)
        test.assert_eq(quick_access_width(client), page_w)
        test.assert_eq((panel:get_position()), page_w)
        test.assert_deep_eq(map_rect(page), map)
    end)
end)

test.case("the active entry loses the pointer's colors with the pointer", function()
    with_client(function(client)
        local button = tokens_button(client)
        local manager = client.app.button_event_manager
        local min_x, min_y, max_x, max_y = button:get_global_aabb():get_bounds()
        manager:dispatch_pointer_move((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, 1)
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_ACTIVE_HOVER_COLOR)
        manager:dispatch_pointer_down((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, 1)
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_ACTIVE_SELECT_COLOR)
        manager:dispatch_pointer_up((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, 1)
        manager:dispatch_pointer_move(0, 0, 1)
        test.assert_false(button:is_active(), "the click hid the panel")
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_NORMAL_COLOR)
        game_client.click(client, button)
        manager:dispatch_pointer_move(0, 0, 1)
        test.assert_deep_eq(button:get_color(), Consts.BUTTON_ACTIVE_COLOR)
    end)
end)

test.case("a window resize while the side bar is hidden keeps the page at the whole width and lays the hidden panel out too", function()
    with_client(function(client)
        local screen = client.game_screen
        local panel = screen:get_token_panel()
        screen:disable_panel()
        local w = assert(client.app.width)
        screen:on_resize(w, 800)
        local page_w, page_h = screen:get_page():get_size()
        test.assert_eq(page_w, w)
        test.assert_eq(page_h, 800 - Consts.QUICK_ACCESS_PANEL_HEIGHT)
        test.assert_eq((screen:get_page():get_fit_size()), w * (1 - Consts.GAME_SIDE_PANEL_SHARE))
        test.assert_eq(quick_access_width(client), w)
        local panel_x, _, panel_w, panel_h = panel:get_position_and_size()
        test.assert_eq(panel_x, w * (1 - Consts.GAME_SIDE_PANEL_SHARE))
        test.assert_eq(panel_w, w * Consts.GAME_SIDE_PANEL_SHARE)
        test.assert_eq(panel_h, 800)

        screen:select_panel(panel)
        test.assert_eq((screen:get_page():get_size()), w * (1 - Consts.GAME_SIDE_PANEL_SHARE), "the view shrinks to the fit area")
    end)
end)

test.case("Tab skips the hidden panel's inputs", function()
    with_client(function(client)
        local screen = client.game_screen
        game_client.select(client, {
            "Bilbosza"
        })
        ---@diagnostic disable-next-line: invisible
        local id_input = assert(screen:get_token_panel()._id_input)
        screen:focus(id_input)
        test.assert_true(id_input:is_focused())
        screen:disable_panel()
        for _ = 1, 8 do
            ---@diagnostic disable-next-line: invisible
            screen:_advance_focus(1)
            ---@diagnostic disable-next-line: invisible
            screen:_notify_listeners()
            ---@diagnostic disable-next-line: invisible
            local focused = screen._inputs[screen._focus]
            test.assert_true(focused:are_all_predecessors_enabled(), "the focus stays on a shown input")
        end
        test.assert_false(id_input:is_focused())
    end)
end)
