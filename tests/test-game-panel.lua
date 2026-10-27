local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")
local lifetime = require("lifetime")

---@class TestEntryUpdate
---@field kind EntryKind
---@field id string
---@field changes table<string, EntryValue>
---@field new_id string|nil

---@param client GameClient
---@return TestEntryUpdate[] What the panel sends, filled in as it does
local function record_updates(client)
    ---@type TestEntryUpdate[]
    local sent = {}
    ---@param self Session
    ---@param kind EntryKind
    ---@param id string
    ---@param changes table<string, EntryValue>
    ---@param new_id string|nil
    client.session.update_entry = function(self, kind, id, changes, new_id)
        table.insert(sent, {
            kind = kind,
            id = id,
            changes = changes,
            new_id = new_id
        })
    end
    return sent
end

---@param client GameClient
---@return GamePanel
local function show_game_panel(client)
    local screen = client.game_screen
    local panel = screen:get_game_panel()
    screen:select_panel(panel)
    return panel
end

---@param panel GamePanel
---@param id string
---@return TextButton
local function page_button(panel, id)
    for _, button in ipairs(panel:get_buttons()) do
        if button:get_text() == id then
            return button
        end
    end
    error("no button " .. id)
end

---@param panel GamePanel
---@return string[]
local function captions(panel)
    ---@type string[]
    local result = {}
    for _, button in ipairs(panel:get_buttons()) do
        table.insert(result, button:get_text())
    end
    return result
end

---@param grants string[]
---@param fn fun(client: GameClient)
local function with_client(grants, fn)
    local client = game_client.enter(grants)
    ---@type boolean, any
    local ok, err = pcall(fn, client)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

test.suite("GamePanel")

test.case("the panel names the shown page and lists the pages by id in a scroll view, the shown one active", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local panel = show_game_panel(client)
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(panel._title:get_text(), "Shown page")
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(panel._page_label:get_text(), "P")
        test.assert_deep_eq(captions(panel), {
            "P",
            "Q"
        })
        test.assert_true(page_button(panel, "P"):is_active())
        test.assert_false(page_button(panel, "Q"):is_active())
        ---@diagnostic disable-next-line: invisible
        local view = panel._scroll_view
        local _, p_y = page_button(panel, "P"):get_position()
        local _, q_y = page_button(panel, "Q"):get_position()
        test.assert_true(p_y < q_y, "one under the other")
        for _, button in ipairs(panel:get_buttons()) do
            test.assert_eq(button:get_parent(), view:get_content())
            test.assert_false(button:is_read_only())
        end
        ---@diagnostic disable-next-line: invisible
        local _, label_y, _, label_h = panel._page_label:get_position_and_outer_size()
        local _, view_y = view:get_position()
        test.assert_true(view_y >= label_y + label_h, "the list under the shown page's id")

        local w = panel:get_size()
        panel:on_resize(w, view_y + 10)
        local _, max_y = view:get_max_scroll()
        test.assert_true(max_y > 0, "the list scrolls in a short panel")
    end)
end)

test.case("a click on a page sends the game entry's change and applies nothing; the shown page sends nothing", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local sent = record_updates(client)
        local panel = show_game_panel(client)
        local data = assert(client.app.data)
        game_client.click(client, page_button(panel, "Q"))
        test.assert_deep_eq(sent, {
            {
                kind = "game",
                id = "game",
                changes = {
                    page = "Q"
                }
            }
        })
        test.assert_eq(data.game.page, "P", "nothing applied before the server answers")
        test.assert_eq(client.game_screen:get_page():get_data(), data.pages.P)
        test.assert_false(page_button(panel, "Q"):is_active())
        game_client.click(client, page_button(panel, "P"))
        test.assert_eq(#sent, 1, "the page shown already")
    end)
end)

test.case("without write on game the page buttons are read-only and a click sends nothing", function()
    with_client({
        "read",
        "write:tokens"
    }, function(client)
        local sent = record_updates(client)
        local panel = show_game_panel(client)
        for _, button in ipairs(panel:get_buttons()) do
            test.assert_true(button:is_read_only())
            test.assert_deep_eq(button:get_color(), Consts.BUTTON_READ_ONLY_COLOR)
        end
        game_client.click(client, page_button(panel, "Q"))
        test.assert_deep_eq(sent, {})
    end)
end)

test.case("write on the game entry alone makes the buttons clickable", function()
    with_client({
        "read",
        "write:game"
    }, function(client)
        local panel = show_game_panel(client)
        test.assert_false(page_button(panel, "Q"):is_read_only())
    end)
end)

test.case("a change of the pages or the game entry, or of the grants, rebuilds the list; another kind does not", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = client.game_screen
        local panel = show_game_panel(client)
        local data = assert(client.app.data)
        local first = page_button(panel, "P")
        screen:on_entries_change("token_properties", "name")
        test.assert_eq(page_button(panel, "P"), first, "not the game panel's kind")

        data.pages.A = {
            name = "A",
            width = 10,
            pixel_per_meter = 50,
            image = "world/q.png",
            tokens = {}
        }
        screen:on_entries_change("pages", "A")
        test.assert_deep_eq(captions(panel), {
            "A",
            "P",
            "Q"
        })
        test.assert_false(lifetime.alive(first), "the old buttons destroyed")

        data.game.page = "Q"
        screen:on_entries_change("game", "game")
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(panel._page_label:get_text(), "Q")
        test.assert_true(page_button(panel, "Q"):is_active())
        test.assert_false(page_button(panel, "P"):is_active())

        client.session:set_grants({
            "read"
        })
        screen:on_grants_change()
        test.assert_true(page_button(panel, "A"):is_read_only())
    end)
end)
