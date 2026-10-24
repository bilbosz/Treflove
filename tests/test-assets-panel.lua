local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")

---@param name string
---@param data string
---@return love.DroppedFile
local function make_file(name, data)
    ---@class TestPanelDroppedFile: love.DroppedFile
    local file = {}

    ---@return boolean
    function file:open()
        return true
    end

    ---@return boolean
    function file:close()
        return true
    end

    ---@return string
    function file:read()
        return data
    end

    ---@return number
    function file:getSize()
        return #data
    end

    ---@return string
    function file:getFilename()
        return name
    end

    return file
end

---@param client GameClient
---@return AssetsPanel
local function assets_panel(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen._assets_panel
end

---@param grants string[]
---@param fn fun(panel: AssetsPanel)
local function with_panel(grants, fn)
    local client = game_client.enter(grants)
    ---@type boolean, any
    local ok, err = pcall(fn, assets_panel(client))
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

test.suite("AssetsPanel")

test.case("without write on the assets there is no Upload button, and a resize does without it", function()
    with_panel({
        "read",
        "write:tokens"
    }, function(panel)
        test.assert_eq(panel._upload_button, nil)
        test.assert_true(panel._cancel_button ~= nil, "a Cancel button")
        panel:on_resize(300, 900)
    end)
end)

test.case("with write on the assets there is an Upload button", function()
    with_panel({
        "read",
        "write:assets"
    }, function(panel)
        test.assert_true(panel._upload_button ~= nil)
        test.assert_true(panel._cancel_button ~= nil)
    end)
end)

test.case("the preview and the fields sit in a scroll view that ends a padding above the buttons, through a resize", function()
    with_panel({
        "read",
        "write:assets"
    }, function(panel)
        local view = panel._scroll_view
        local content = view:get_content()
        test.assert_eq(panel._preview_area:get_parent(), content)
        test.assert_eq(panel._location_input:get_parent(), content)
        test.assert_eq(panel._file_type_input:get_parent(), content)
        test.assert_eq(panel._remote_location_input:get_parent(), content)

        ---@param w number
        ---@param h number
        local function assert_layout(w, h)
            local view_w, view_h = view:get_size()
            local _, cancel_y = panel._cancel_button:get_position()
            local _, upload_y = assert(panel._upload_button):get_position()
            test.assert_eq(view_w, w)
            test.assert_eq(cancel_y, upload_y)
            test.assert_eq(view_h, math.max(0, cancel_y - Consts.PADDING), tostring(h))
            local _, input_y, _, input_h = panel._remote_location_input:get_position_and_size()
            test.assert_eq(select(2, view:get_content_size()), input_y + input_h + Consts.PADDING)
        end
        local w, h = panel:get_size()
        assert_layout(w, h)
        panel:on_resize(w, 300)
        assert_layout(w, 300)
        local _, max_y = view:get_max_scroll()
        test.assert_true(max_y > 0, "the fields overflow a short panel")
        view:set_scroll(0, max_y)
        panel:on_resize(w, 5000)
        assert_layout(w, 5000)
        test.assert_deep_eq({
            view:get_scroll()
        }, {
            0,
            0
        }, "everything fits again")
    end)
end)

test.case("a file dropped over the preview, in the scroll view, reaches the panel", function()
    local client = game_client.enter({
        "read",
        "write:assets"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local panel = assets_panel(client)
        local min_x, min_y, max_x, max_y = panel._preview_area:get_global_aabb():get_bounds()
        client.app:set_pointer_position((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
        client.app.file_system_drop_event_manager:file_drop(make_file("/home/adam/map.txt", "hello"))
        test.assert_eq(panel._location_input:get_text(), "/home/adam/map.txt")
        test.assert_eq(panel._remote_location_input:get_text(), "map.txt")
        test.assert_false(panel._remote_location_input:is_read_only())

        panel:reset()
        client.app:set_pointer_position((min_x + max_x) * 0.5, max_y + 10)
        client.app.file_system_drop_event_manager:file_drop(make_file("/home/adam/other.txt", "hello"))
        test.assert_eq(panel._location_input:get_text(), "", "dropped just under the preview")

        local w = panel:get_size()
        panel:on_resize(w, 300)
        local view = panel._scroll_view
        local _, max_scroll = view:get_max_scroll()
        view:set_scroll(0, max_scroll)
        local view_min_x, view_min_y, view_max_x, view_max_y = view:get_global_aabb():get_bounds()
        min_x, min_y, max_x, max_y = panel._preview_area:get_global_aabb():get_bounds()
        test.assert_true(max_y < view_min_y, "the preview is scrolled out of the short view")
        client.app:set_pointer_position((view_min_x + view_max_x) * 0.5, (view_min_y + view_max_y) * 0.5)
        client.app.file_system_drop_event_manager:file_drop(make_file("/home/adam/other.txt", "hello"))
        test.assert_eq(panel._location_input:get_text(), "", "dropped on the fields, where the preview was before the scroll")
        client.app:set_pointer_position((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
        client.app.file_system_drop_event_manager:file_drop(make_file("/home/adam/other.txt", "hello"))
        test.assert_eq(panel._location_input:get_text(), "", "dropped where the scrolled-out preview is, outside the view")
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)
