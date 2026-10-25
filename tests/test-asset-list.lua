local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local AssetListRow = require("game.assets.workspace.asset-list-row")

---@param count number
---@return AssetEntry[] `count` files at the root and one folder
local function many_entries(count)
    ---@type AssetEntry[]
    local entries = {
        {
            path = "z-folder",
            type = "directory"
        }
    }
    for i = 1, count do
        table.insert(entries, {
            path = string.format("file-%03d.png", i),
            type = "file",
            size = i
        })
    end
    return entries
end

---@param list AssetList
---@return string[]
local function labels(list)
    local result = {}
    for _, row in ipairs(list:get_rows()) do
        table.insert(result, AssetListRow.get_label(row:get_entry()))
    end
    return result
end

---@param list AssetList
---@return number
local function enabled_rows(list)
    local n = 0
    for _, row in ipairs(list:get_rows()) do
        if row:is_enabled() then
            n = n + 1
        end
    end
    return n
end

---@param fn fun(client: GameClient, screen: AssetsWorkspaceScreen, list: AssetList)
local function with_list(fn)
    local client = game_client.enter({
        "read",
        "write"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local screen = game_client.open_workspace(client, many_entries(60))
        fn(client, screen, screen:get_list())
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

test.suite("AssetList")

test.case("folders come first, then the files by name; rows below the view are disabled", function()
    with_list(function(_, _, list)
        local names = labels(list)
        test.assert_eq(#names, 61)
        test.assert_eq(names[1], "z-folder/")
        test.assert_eq(names[2], "file-001.png")
        test.assert_eq(names[61], "file-060.png")
        local rows = list:get_rows()
        test.assert_true(rows[1]:is_enabled())
        test.assert_false(rows[61]:is_enabled(), "out of view, so not under the pointer either")
        test.assert_true(enabled_rows(list) < 61)
    end)
end)

test.case("the wheel scrolls the list under the pointer, within its content; another folder starts at the top", function()
    with_list(function(client, screen, list)
        local min_x, min_y, max_x, max_y = list:get_global_aabb():get_bounds()
        local rows = list:get_rows()
        local visible = enabled_rows(list)

        client.app:set_pointer_position(max_x + 10, (min_y + max_y) * 0.5)
        client.app.wheel_event:trigger(0, -1)
        test.assert_true(rows[1]:is_enabled(), "a wheel beside the list scrolls nothing")

        client.app:set_pointer_position((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
        client.app.wheel_event:trigger(0, -1)
        test.assert_false(rows[1]:is_enabled(), "scrolled down: the first rows left the view")
        test.assert_true(rows[4]:is_enabled())
        test.assert_true(enabled_rows(list) >= visible, "as many in view, with a partial row at an end")
        ---@diagnostic disable-next-line: invisible
        test.assert_true(list._scroll > 0)

        for _ = 1, 100 do
            client.app.wheel_event:trigger(0, -1)
        end
        test.assert_true(rows[61]:is_enabled(), "scrolled to the end")
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(list._scroll, list:_get_max_scroll(), "no further than the content")

        client.app.wheel_event:trigger(0, 1)
        ---@diagnostic disable-next-line: invisible
        test.assert_true(list._scroll < list:_get_max_scroll())
        for _ = 1, 100 do
            client.app.wheel_event:trigger(0, 1)
        end
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(list._scroll, 0)

        client.app.wheel_event:trigger(0, -1)
        screen:select_entry(rows[1]:get_entry())
        screen:open_selected()
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(list._scroll, 0, "the opened folder starts at the top")
        test.assert_deep_eq(labels(list), {})
    end)
end)

test.case("a hidden workspace's list ignores the wheel, and the shown game page takes it", function()
    with_list(function(client, _, list)
        local min_x, min_y, max_x, max_y = list:get_global_aabb():get_bounds()
        client.app:set_pointer_position((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
        local page = client.game_screen:get_page()
        ---@diagnostic disable-next-line: invisible
        local background = page._background
        local scale = background:get_scale()
        client.app.wheel_event:trigger(0, -1)
        test.assert_eq(background:get_scale(), scale, "a page under the workspace keeps its zoom")
        ---@diagnostic disable-next-line: invisible
        local scrolled = list._scroll
        test.assert_true(scrolled > 0, "the shown list scrolled")

        client.app.screen_manager:show(client.game_screen)
        client.app.wheel_event:trigger(0, 1)
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(list._scroll, scrolled, "the hidden list stays")
        test.assert_true(background:get_scale() > scale, "the shown page zoomed in")
    end)
end)
