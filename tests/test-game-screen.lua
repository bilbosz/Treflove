local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")
local lifetime = require("lifetime")
local SidePanel = require("game.side-panel")

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

---@param client GameClient
---@param caption string
---@return TextButton
local function quick_access_button(client, caption)
    ---@diagnostic disable-next-line: invisible
    return assert(client.game_screen._quick_access_panel._buttons[caption])
end

---@param client GameClient
---@return string[] The captions of the quick access entries, left to right
local function quick_access_captions(client)
    ---@diagnostic disable-next-line: invisible
    local buttons = client.game_screen._quick_access_panel._buttons
    ---@type TextButton[]
    local ordered = {}
    for _, button in pairs(buttons) do
        table.insert(ordered, button)
    end
    table.sort(ordered, function(a, b)
        return a:get_position() < b:get_position()
    end)
    ---@type string[]
    local captions = {}
    for _, button in ipairs(ordered) do
        table.insert(captions, button:get_text())
    end
    return captions
end

test.case("the quick access entries are Tokens, Assets, Game, Pages, Groups, Permissions and Token Properties, left to right", function()
    with_client(function(client)
        test.assert_deep_eq(quick_access_captions(client), {
            "Tokens",
            "Assets",
            "Game",
            "Pages",
            "Groups",
            "Permissions",
            "Token Properties"
        })
    end)
end)

test.case("each entries panel's entry shows its panel alone, of the kind it names", function()
    with_client(function(client)
        local screen = client.game_screen
        ---@type table<string, string>
        local shown = {}
        for _, caption in ipairs({
            "Pages",
            "Groups",
            "Permissions",
            "Token Properties"
        }) do
            local button = quick_access_button(client, caption)
            game_client.click(client, button)
            local panel = assert(screen:get_panel(), caption .. " shows a panel") --[[@as EntriesPanel]]
            test.assert_true(panel:is_enabled())
            test.assert_true(button:is_active())
            test.assert_false(screen:get_token_panel():is_enabled())
            shown[caption] = get_class_name_of(panel) .. " " .. panel:get_kind()
        end
        test.assert_deep_eq(shown, {
            Pages = "PagesPanel pages",
            Groups = "GroupsPanel groups",
            Permissions = "PermissionsPanel players",
            ["Token Properties"] = "TokenPropertiesPanel token_properties"
        })
    end)
end)

test.case("the Game entry shows the game panel in place of the token panel, and a second click hides the side bar", function()
    with_client(function(client)
        local screen = client.game_screen
        local game_panel, token_panel = screen:get_game_panel(), screen:get_token_panel()
        local game_button = quick_access_button(client, "Game")
        test.assert_false(game_panel:is_enabled(), "hidden at first")
        game_client.click(client, game_button)
        test.assert_eq(screen:get_panel(), game_panel)
        test.assert_true(game_panel:is_enabled())
        test.assert_true(game_button:is_active())
        test.assert_false(token_panel:is_enabled())
        test.assert_false(tokens_button(client):is_active())
        local w, h = assert(client.app.width), assert(client.app.height)
        local x, y, panel_w, panel_h = game_panel:get_position_and_size()
        test.assert_eq(x, w * (1 - Consts.GAME_SIDE_PANEL_SHARE))
        test.assert_eq(y, 0)
        test.assert_eq(panel_w, w * Consts.GAME_SIDE_PANEL_SHARE)
        test.assert_eq(panel_h, h)
        game_client.click(client, game_button)
        test.assert_eq(screen:get_panel(), nil)
        test.assert_false(game_panel:is_enabled())
    end)
end)

test.case("show_page replaces the page with one over the page named, at the same place, size and extension and under the panels, with nothing selected", function()
    with_client(function(client)
        local screen = client.game_screen
        local data = assert(client.app.data)
        game_client.select(client, {
            "Bilbosza"
        })
        screen:disable_panel()
        local old = screen:get_page()
        local x, y = old:get_position()
        local view_w, view_h = old:get_size()
        local fit_w, fit_h = old:get_fit_size()
        local extension = old:get_extension()
        test.assert_true(extension > 0, "the strip of the hidden side bar")
        local control = screen:get_control()
        local index = table.find_array_idx(control:get_children(), old)

        data.game.page = "Q"
        screen:show_page("Q")

        local page = screen:get_page()
        test.assert_false(lifetime.alive(old), "the old page destroyed")
        test.assert_eq(page:get_data(), data.pages.Q)
        test.assert_eq(page:get_game_screen(), screen)
        test.assert_deep_eq({
            page:get_position()
        }, {
            x,
            y
        })
        test.assert_deep_eq({
            page:get_size()
        }, {
            view_w,
            view_h
        })
        test.assert_deep_eq({
            page:get_fit_size()
        }, {
            fit_w,
            fit_h
        })
        test.assert_eq(page:get_extension(), extension)
        test.assert_eq(table.find_array_idx(control:get_children(), page), index, "drawn where the old one was")
        test.assert_deep_eq(page:get_tokens(), {})
        test.assert_eq(next(screen:get_selection():get_select_set()), nil)
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(screen:get_token_panel()._id_input, nil, "the token panel shows the empty selection")
        ---@type table<string, boolean>
        local shown = {}
        for _, button in ipairs(screen:get_game_panel():get_buttons()) do
            shown[button:get_text()] = button:is_active()
        end
        test.assert_deep_eq(shown, {
            P = false,
            Q = true
        }, "the game panel marks the page shown")

        screen:select_panel(screen:get_token_panel())
        test.assert_eq((page:get_size()), fit_w, "the new page follows the side bar")
        data.game.page = "P"
        screen:show_page("P")
        test.assert_eq(#screen:get_page():get_tokens(), 2, "the tokens of the page shown again")
    end)
end)

---@class TestSidePanel: SidePanel
---@field calls string[]
local TestSidePanel = class("TestSidePanel", SidePanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function TestSidePanel:init(game_screen, width, height)
    SidePanel.init(self, game_screen, width, height)
    self.calls = {}
end

---@param kind EntryKind
---@param id string
function TestSidePanel:on_entries_change(kind, id)
    table.insert(self.calls, "entries " .. kind .. " " .. id)
end

function TestSidePanel:on_grants_change()
    table.insert(self.calls, "grants")
end

function TestSidePanel:on_selection_change()
    table.insert(self.calls, "selection")
end

test.case("a side panel added gets a quick access entry at the end that toggles it, and hears of the entries, the grants and the selection", function()
    with_client(function(client)
        local screen = client.game_screen
        local w, h = assert(client.app.width), assert(client.app.height)
        local panel = TestSidePanel(screen, w * Consts.GAME_SIDE_PANEL_SHARE, h)
        test.assert_eq(panel:get_game_screen(), screen)
        local button = screen:add_side_panel(panel, "Test")
        test.assert_eq(button, quick_access_button(client, "Test"))
        local captions = quick_access_captions(client)
        test.assert_eq(captions[#captions], "Test")
        test.assert_false(panel:is_enabled(), "hidden until its entry is clicked")
        screen:on_resize(w, h)
        game_client.click(client, button)
        test.assert_eq(screen:get_panel(), panel)
        test.assert_true(button:is_active())
        test.assert_false(screen:get_token_panel():is_enabled())

        panel.calls = {}
        screen:on_entries_change("pages", "P")
        screen:on_grants_change()
        game_client.select(client, {})
        test.assert_deep_eq(panel.calls, {
            "entries pages P",
            "grants",
            "selection"
        })

        panel.calls = {}
        assert(client.app.data).game.page = "Q"
        screen:show_page("Q")
        test.assert_deep_eq(panel.calls, {
            "selection",
            "entries game game",
            "entries pages Q"
        }, "a page shown is a change of the game entry and of that page")
        test.assert_eq(screen:get_panel(), panel, "the side bar keeps the panel shown")
    end)
end)
