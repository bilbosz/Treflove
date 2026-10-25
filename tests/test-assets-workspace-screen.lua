local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Asset = require("data.asset")
local AssetListRow = require("game.assets.workspace.asset-list-row")

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

---@param screen AssetsWorkspaceScreen
---@return string[]
local function labels(screen)
    local result = {}
    for _, row in ipairs(screen:get_list():get_rows()) do
        table.insert(result, AssetListRow.get_label(row:get_entry()))
    end
    return result
end

---@param screen AssetsWorkspaceScreen
---@param label string
---@return AssetListRow
local function row(screen, label)
    for _, candidate in ipairs(screen:get_list():get_rows()) do
        if AssetListRow.get_label(candidate:get_entry()) == label then
            return candidate
        end
    end
    error("no row " .. label)
end

---@param screen AssetsWorkspaceScreen
---@return table<AssetDetailsAction, boolean> The actions that are not read-only
local function enabled_actions(screen)
    ---@type table<AssetDetailsAction, boolean>
    local result = {}
    ---@type AssetDetailsAction[]
    local actions = {
        "upload",
        "new_folder",
        "rename",
        "delete",
        "use"
    }
    for _, action in ipairs(actions) do
        local button = screen:get_details():get_action_button(action)
        if button and not button:is_read_only() then
            result[action] = true
        end
    end
    return result
end

---@param client GameClient
---@param key string
---@return TokenPanelProperty
local function token_property(client, key)
    ---@diagnostic disable-next-line: invisible
    for _, property in ipairs(client.game_screen:get_token_panel()._properties) do
        if property.key == key then
            return property
        end
    end
    error("no property " .. key)
end

---Opens the workspace from the token panel's button of `key` and answers the listing
---@param client GameClient
---@param key string
---@return AssetsWorkspaceScreen
local function open_from_token_property(client, key)
    game_client.click(client, assert(token_property(client, key).button))
    local screen = client.app.screen_manager:get_screen() --[[@as AssetsWorkspaceScreen]]
    test.assert_eq(get_class_name_of(screen), "AssetsWorkspaceScreen")
    game_client.pop_request(client, "ListAssetsRp")
    game_client.answer(client, "ListAssetsRp", {
        success = true,
        entries = game_client.asset_entries(),
        writable = true
    })
    return screen
end

---@param screen AssetsWorkspaceScreen
---@param name string
local function type_name(screen, name)
    screen:get_details():set_name(name)
    screen:on_name_edited()
end

---@param screen AssetsWorkspaceScreen
---@return TextInput
local function type_input(screen)
    ---@diagnostic disable-next-line: invisible
    return screen:get_details()._type_input
end

---@param screen AssetsWorkspaceScreen
---@return TextButton up
---@return TextButton open
local function header_buttons(screen)
    ---@diagnostic disable-next-line: invisible
    return screen._up_button, screen._open_button
end

---@param name string
---@param content string
---@return love.DroppedFile
local function dropped_file(name, content)
    ---@class TestWorkspaceDroppedFile: love.DroppedFile
    local file = {}
    ---@return string
    function file:getFilename()
        return name
    end
    ---@return string
    function file:read()
        return content
    end
    ---@return boolean
    function file:open()
        return true
    end
    ---@return boolean
    function file:close()
        return true
    end
    return file --[[@as love.DroppedFile]]
end

test.suite("AssetsWorkspaceScreen")

test.case("opened over the game, the workspace shows the root: folders first, nothing selected, no action possible yet", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local game_screen = client.game_screen
        local screen = game_client.open_workspace(client)
        test.assert_eq(screen:get_dir(), "")
        test.assert_deep_eq(labels(screen), {
            "token/",
            "world/",
            "notes.txt"
        })
        test.assert_eq(screen:get_selected(), nil)
        test.assert_true(screen:is_writable())
        test.assert_deep_eq(enabled_actions(screen), {})
        local up, open = header_buttons(screen)
        test.assert_true(up:is_read_only(), "nowhere up from the root")
        test.assert_true(open:is_read_only(), "nothing to open")
        test.assert_eq(game_screen:get_control():get_parent(), nil, "the game screen is hidden meanwhile")

        client.app.backstack_manager:back()
        test.assert_eq(client.app.screen_manager:get_screen(), game_screen, "back shows the game again")
        test.assert_false(lifetime.alive(screen))
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(client.session._assets_workspace_screen, nil)
        client.app.backstack_manager:back()
        test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "UserMenuScreen", "the game's own way back is still there")
    end)
end)

test.case("a reader gets a read-only workspace: the name cannot be typed, no action is possible", function()
    with_client({
        "read"
    }, function(client)
        local screen = game_client.open_workspace(client, nil, false)
        test.assert_false(screen:is_writable())
        ---@diagnostic disable-next-line: invisible
        test.assert_true(screen:get_details()._name_input:is_read_only())
        screen:select_entry(row(screen, "notes.txt"):get_entry())
        test.assert_deep_eq(enabled_actions(screen), {})
        game_client.pop_request(client, "DownloadAssetRp")
    end)
end)

test.case("a refused listing closes the workspace", function()
    with_client({
        "read"
    }, function(client)
        local game_screen = client.game_screen
        client.session:open_assets_workspace()
        local screen = client.app.screen_manager:get_screen()
        game_client.pop_request(client, "ListAssetsRp")
        game_client.answer(client, "ListAssetsRp", {
            success = false,
            writable = false
        })
        test.assert_false(lifetime.alive(screen))
        test.assert_eq(client.app.screen_manager:get_screen(), game_screen)
        local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
        test.assert_deep_eq(notifications.messages, {
            "Successfully logged in as piotr",
            "Not allowed to browse assets"
        })
    end)
end)

test.case("a selected folder can be opened and deleted; a second click opens it; Up goes to the parent", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        local token = row(screen, "token/")
        game_client.click(client, token)
        test.assert_eq(screen:get_selected(), token:get_entry())
        test.assert_eq(screen:get_details():get_name(), "token")
        test.assert_eq(type_input(screen):get_text(), "Folder")
        test.assert_deep_eq(enabled_actions(screen), {
            delete = true
        }, "the name is unchanged, so no rename yet")
        local up, open = header_buttons(screen)
        test.assert_false(open:is_read_only())

        game_client.click(client, token)
        test.assert_eq(screen:get_dir(), "token")
        test.assert_deep_eq(labels(screen), {
            "b.png",
            "s.png"
        })
        test.assert_eq(screen:get_selected(), nil)
        test.assert_false(up:is_read_only())
        test.assert_true(open:is_read_only())

        screen:go_up()
        test.assert_eq(screen:get_dir(), "")
        test.assert_deep_eq(labels(screen), {
            "token/",
            "world/",
            "notes.txt"
        })

        screen:select_entry(row(screen, "world/"):get_entry())
        screen:open_selected()
        test.assert_eq(screen:get_dir(), "world")
        test.assert_deep_eq(labels(screen), {
            "w.png"
        })
    end)
end)

test.case("a selected file the client has is previewed at once; one it lacks is downloaded first", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "b.png"):get_entry())
        test.assert_eq(type_input(screen):get_text(), "IMAGE", "the fake graphics make an image of any bytes")
        test.assert_eq(client.connection:get_out_channel():getCount(), 0, "no download: nothing on the wire")

        screen:go_up()
        local notes = row(screen, "notes.txt"):get_entry()
        screen:select_entry(notes)
        test.assert_eq(type_input(screen):get_text(), "")
        test.assert_deep_eq(game_client.pop_request(client, "DownloadAssetRp"), {
            path = "notes.txt"
        })
        game_client.answer(client, "DownloadAssetRp", {
            path = "notes.txt",
            content = love.data.encode("string", "base64", "hello")
        })
        test.assert_eq(Asset("notes.txt", false):read(), "hello", "mounted")
        test.assert_eq(type_input(screen):get_text(), "IMAGE")
        test.assert_deep_eq(enabled_actions(screen), {
            delete = true
        })
    end)
end)

test.case("a download that answers after another selection, or after the workspace closed, changes nothing", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        screen:select_entry(row(screen, "notes.txt"):get_entry())
        game_client.pop_request(client, "DownloadAssetRp")
        screen:select_entry(row(screen, "token/"):get_entry())
        game_client.answer(client, "DownloadAssetRp", {
            path = "notes.txt",
            content = love.data.encode("string", "base64", "hello")
        })
        test.assert_eq(type_input(screen):get_text(), "Folder")

        screen:select_entry(row(screen, "world/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "w.png"):get_entry())
        test.assert_eq(type_input(screen):get_text(), "IMAGE")
        test.assert_eq(client.connection:get_out_channel():getCount(), 0, "a copy is there: no download")
        screen:go_up()
        Asset("notes.txt", false):remove()
        screen:select_entry(row(screen, "notes.txt"):get_entry())
        game_client.pop_request(client, "DownloadAssetRp")
        client.app.backstack_manager:back()
        test.assert_false(lifetime.alive(screen))
        game_client.answer(client, "DownloadAssetRp", {
            path = "notes.txt",
            content = love.data.encode("string", "base64", "hello")
        })
        test.assert_eq(Asset("notes.txt", false):read(), "hello", "the response still mounts the asset")
    end)
end)

test.case("rename sends the new path in the shown folder, then lists again; the selection is over on success", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "s.png"):get_entry())
        type_name(screen, "smaug.png")
        test.assert_deep_eq(enabled_actions(screen), {
            rename = true,
            delete = true,
            new_folder = true
        })
        screen:run_action("rename")
        test.assert_deep_eq(game_client.pop_request(client, "RenameAssetRp"), {
            path = "token/s.png",
            new_path = "token/smaug.png"
        })
        game_client.answer(client, "RenameAssetRp", {
            success = true,
            path = "token/s.png",
            new_path = "token/smaug.png"
        })
        local entries = game_client.asset_entries()
        entries[4].path = "token/smaug.png"
        game_client.pop_request(client, "ListAssetsRp")
        game_client.answer(client, "ListAssetsRp", {
            success = true,
            entries = entries,
            writable = true
        })
        test.assert_eq(screen:get_dir(), "token")
        test.assert_deep_eq(labels(screen), {
            "b.png",
            "smaug.png"
        })
        test.assert_eq(screen:get_selected(), nil)
        test.assert_eq(screen:get_details():get_name(), "")
        test.assert_deep_eq(enabled_actions(screen), {})
    end)
end)

test.case("a refused change is notified and keeps the selection and the name to fix", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        local notes = row(screen, "notes.txt"):get_entry()
        screen:select_entry(notes)
        game_client.pop_request(client, "DownloadAssetRp")
        game_client.answer(client, "DownloadAssetRp", {
            path = "notes.txt"
        })
        test.assert_eq(type_input(screen):get_text(), "", "the server has no such file: no preview")
        type_name(screen, "token")
        test.assert_deep_eq(enabled_actions(screen), {
            delete = true
        }, "a name taken in the folder: no rename, no new folder")
        type_name(screen, "readme.txt")
        test.assert_deep_eq(enabled_actions(screen), {
            delete = true,
            rename = true,
            new_folder = true
        })
        screen:run_action("rename")
        game_client.pop_request(client, "RenameAssetRp")
        game_client.answer(client, "RenameAssetRp", {
            success = false,
            error = "Cannot rename \"notes.txt\" to \"readme.txt\": there is no such asset",
            path = "notes.txt",
            new_path = "readme.txt"
        })
        game_client.pop_request(client, "ListAssetsRp")
        game_client.answer(client, "ListAssetsRp", {
            success = true,
            entries = game_client.asset_entries(),
            writable = true
        })
        local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
        test.assert_deep_eq(notifications.messages, {
            "Successfully logged in as piotr",
            "Cannot rename \"notes.txt\" to \"readme.txt\": there is no such asset"
        })
        test.assert_deep_eq(screen:get_selected(), notes, "the same entry, as listed again")
        test.assert_eq(screen:get_details():get_name(), "readme.txt")
        test.assert_true(enabled_actions(screen).rename)
    end)
end)

test.case("New Folder takes the typed name under the shown folder, Delete the selection", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        type_name(screen, "maps")
        test.assert_deep_eq(enabled_actions(screen), {
            new_folder = true
        })
        screen:run_action("new_folder")
        test.assert_deep_eq(game_client.pop_request(client, "CreateAssetFolderRp"), {
            path = "maps"
        })
        game_client.answer(client, "CreateAssetFolderRp", {
            success = true,
            path = "maps"
        })
        game_client.pop_request(client, "ListAssetsRp")
        game_client.answer(client, "ListAssetsRp", {
            success = true,
            entries = game_client.asset_entries(),
            writable = true
        })
        test.assert_eq(screen:get_details():get_name(), "")

        screen:select_entry(row(screen, "world/"):get_entry())
        screen:open_selected()
        type_name(screen, "old")
        screen:run_action("new_folder")
        test.assert_deep_eq(game_client.pop_request(client, "CreateAssetFolderRp"), {
            path = "world/old"
        })

        screen:select_entry(row(screen, "w.png"):get_entry())
        screen:run_action("delete")
        test.assert_deep_eq(game_client.pop_request(client, "DeleteAssetRp"), {
            path = "world/w.png"
        })
    end)
end)

test.case("a read-only action does nothing: no request without a selection or a name", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        local before = client.connection:get_out_channel():getCount()
        screen:run_action("delete")
        screen:run_action("rename")
        screen:run_action("new_folder")
        screen:run_action("upload")
        test.assert_eq(client.connection:get_out_channel():getCount(), before)
    end)
end)

test.case("a dropped file replaces the selection and uploads under its name into the shown folder", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "b.png"):get_entry())
        screen:take_dropped_file(dropped_file("/home/adam/pictures/dragon.png", "D"))
        test.assert_eq(screen:get_selected(), nil)
        test.assert_eq(screen:get_details():get_name(), "dragon.png")
        test.assert_eq(type_input(screen):get_text(), "IMAGE")
        test.assert_deep_eq(enabled_actions(screen), {
            upload = true,
            new_folder = true
        })
        type_name(screen, "b.png")
        test.assert_deep_eq(enabled_actions(screen), {
            upload = true
        }, "an upload may replace a file")
        screen:go_up()
        screen:take_dropped_file(dropped_file("C:\\pictures\\dragon.png", "D"))
        test.assert_eq(screen:get_details():get_name(), "dragon.png", "a Windows path is split too")
        type_name(screen, "token")
        test.assert_deep_eq(enabled_actions(screen), {}, "an upload may not replace a folder")
        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:take_dropped_file(dropped_file("/home/adam/pictures/dragon.png", "D"))
        for _, candidate in ipairs(screen:get_list():get_rows()) do
            ---@diagnostic disable-next-line: invisible
            test.assert_false(candidate._is_selected)
        end

        type_name(screen, "smaug.png")
        screen:run_action("upload")
        test.assert_deep_eq(game_client.pop_request(client, "UploadAssetRp"), {
            path = "token/smaug.png",
            content = love.data.encode("string", "base64", "D")
        })
        game_client.answer(client, "UploadAssetRp", {
            success = true
        })
        test.assert_deep_eq(enabled_actions(screen), {
            new_folder = true
        }, "the dropped file is uploaded: no second upload, even before the new listing")
        game_client.pop_request(client, "ListAssetsRp")
        local entries = game_client.asset_entries()
        table.insert(entries, {
            path = "token/smaug.png",
            type = "file",
            size = 1
        })
        game_client.answer(client, "ListAssetsRp", {
            success = true,
            entries = entries,
            writable = true
        })
        test.assert_deep_eq(labels(screen), {
            "b.png",
            "s.png",
            "smaug.png"
        })
        test.assert_deep_eq(enabled_actions(screen), {}, "the name is taken now")
    end)
end)

test.case("a folder that is gone from a fresh listing falls back to the nearest parent", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:refresh()
        game_client.pop_request(client, "ListAssetsRp")
        game_client.answer(client, "ListAssetsRp", {
            success = true,
            entries = {
                {
                    path = "world",
                    type = "directory"
                }
            },
            writable = true
        })
        test.assert_eq(screen:get_dir(), "")
        test.assert_deep_eq(labels(screen), {
            "world/"
        })
    end)
end)

test.case("the Assets entry of the game's quick access panel opens it", function()
    with_client({
        "read",
        "write:assets"
    }, function(client)
        ---@diagnostic disable-next-line: invisible
        local button = client.game_screen._quick_access_panel._buttons.Assets
        game_client.click(client, button)
        test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "AssetsWorkspaceScreen")
        game_client.pop_request(client, "ListAssetsRp")
    end)
end)

---@param screen AssetsWorkspaceScreen
---@return string[] captions
---@return boolean[] read_only
local function usage_buttons(screen)
    ---@type string[], boolean[]
    local captions, read_only = {}, {}
    for _, button in ipairs(screen:get_usage():get_buttons()) do
        table.insert(captions, button:get_text())
        table.insert(read_only, button:is_read_only())
    end
    return captions, read_only
end

---@param client GameClient
---@param x number The rectangle, in page meters
---@param y number
---@param w number
---@param h number
local function assert_fitted(client, x, y, w, h)
    local page = client.game_screen:get_page()
    local view_w, view_h = page:get_size()
    local cx, cy = page:transform_to_global(view_w * 0.5, view_h * 0.5)
    local coordinates = page:get_page_coordinates()
    local gx, gy = coordinates:transform_to_global(x + w * 0.5, y + h * 0.5)
    test.assert_near(gx, cx, 1e-2, "centered")
    test.assert_near(gy, cy, 1e-2)
    local x0, y0 = coordinates:transform_to_global(x, y)
    local x1, y1 = coordinates:transform_to_global(x + w, y + h)
    local scale = math.min((view_w - 2 * Consts.PADDING) / w, (view_h - 2 * Consts.PADDING) / h)
    test.assert_near(x1 - x0, w * scale, 1e-2, "scaled to fit")
    test.assert_near(y1 - y0, h * scale, 1e-2)
end

---@param client GameClient
---@return string[] The keys of the selected tokens, sorted
local function selected_keys(client)
    ---@type string[]
    local keys = {}
    for token in pairs(client.game_screen:get_selection():get_select_set()) do
        table.insert(keys, token:get_id())
    end
    table.sort(keys)
    return keys
end

test.case("the usage list names what uses the selected entry, dimmed off the shown page; a click returns to the game fitted to it, a token selected", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        test.assert_deep_eq({
            usage_buttons(screen)
        }, {
            {},
            {}
        }, "nothing selected")

        screen:select_entry(row(screen, "token/"):get_entry())
        local captions, read_only = usage_buttons(screen)
        test.assert_deep_eq(captions, {
            "token \"Bilbosza\" (avatar)",
            "token \"Gollum\" (avatar)",
            "token \"Smaug\" (avatar)"
        })
        test.assert_deep_eq(read_only, {
            false,
            true,
            false
        }, "Gollum is on no page")

        screen:select_entry(row(screen, "world/"):get_entry())
        captions, read_only = usage_buttons(screen)
        test.assert_deep_eq(captions, {
            "page \"P\"",
            "page \"Q\""
        })
        test.assert_deep_eq(read_only, {
            false,
            true
        }, "Q is not the shown page")

        screen:take_dropped_file(dropped_file("/home/adam/pictures/dragon.png", "D"))
        test.assert_deep_eq({
            usage_buttons(screen)
        }, {
            {},
            {}
        }, "a dropped file is used by nothing")

        screen:select_entry(row(screen, "world/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "w.png"):get_entry())
        test.assert_deep_eq((usage_buttons(screen)), {
            "page \"P\""
        })
        game_client.select(client, {
            "Smaug"
        })
        game_client.click(client, screen:get_usage():get_buttons()[1])
        test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
        test.assert_false(lifetime.alive(screen))
        assert_fitted(client, 0, 0, 10, 10)
        test.assert_deep_eq(selected_keys(client), {
            "Smaug"
        }, "a page is not selectable: the selection stays")

        screen = game_client.open_workspace(client)
        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "b.png"):get_entry())
        test.assert_deep_eq((usage_buttons(screen)), {
            "token \"Bilbosza\" (avatar)"
        })
        game_client.click(client, screen:get_usage():get_buttons()[1])
        test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
        assert_fitted(client, 1.5, 1.5, 1, 1)
        test.assert_deep_eq(selected_keys(client), {
            "Bilbosza"
        }, "the token alone is selected")
    end)
end)

test.case("the details keep the preview and the fields in a scroll view above the buttons, where a drop lands", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local screen = game_client.open_workspace(client)
        local details = screen:get_details()
        local view = details._scroll_view
        local content = view:get_content()
        test.assert_eq(details._preview_area:get_parent(), content)
        test.assert_eq(details._name_input:get_parent(), content)
        test.assert_eq(details._type_input:get_parent(), content)

        ---@param w number
        local function assert_layout(w)
            local view_w, view_h = view:get_size()
            local _, top_y = details:get_action_button("new_folder"):get_position()
            local _, back_y = details._back_button:get_position()
            test.assert_true(top_y < back_y)
            test.assert_eq(view_w, w)
            test.assert_eq(view_h, math.max(0, top_y - Consts.PADDING))
            local _, input_y, _, input_h = details._type_input:get_position_and_size()
            test.assert_eq(select(2, view:get_content_size()), input_y + input_h + Consts.PADDING)
        end
        local w = details:get_size()
        assert_layout(w)

        local min_x, min_y, max_x, max_y = details._preview_area:get_global_aabb():get_bounds()
        client.app:set_pointer_position((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
        client.app.file_system_drop_event_manager:file_drop(dropped_file("/home/adam/pictures/dragon.png", "D"))
        test.assert_eq(details:get_name(), "dragon.png", "dropped on the preview, in the view")

        details:on_resize(w, 200)
        assert_layout(w)
        local _, max_scroll = view:get_max_scroll()
        test.assert_true(max_scroll > 0, "the preview and the fields overflow a short panel")
        view:set_scroll(0, max_scroll)
        min_x, min_y, max_x, max_y = details._preview_area:get_global_aabb():get_bounds()
        test.assert_true(max_y < view:get_global_aabb():get_min_y(), "the preview is scrolled out")
        details:set_name("")
        client.app:set_pointer_position((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
        client.app.file_system_drop_event_manager:file_drop(dropped_file("/home/adam/pictures/other.png", "D"))
        test.assert_eq(details:get_name(), "", "dropped where the scrolled-out preview is, outside the view")
    end)
end)

test.case("opened from a token's image property, the workspace starts at the asset; Use on an image file sets it and returns to the game", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local screen = open_from_token_property(client, "avatar")
        test.assert_eq(screen:get_dir(), "token")
        test.assert_eq(assert(screen:get_selected()).path, "token/b.png")
        test.assert_deep_eq(enabled_actions(screen), {
            delete = true,
            use = true
        })

        screen:go_up()
        screen:select_entry(row(screen, "token/"):get_entry())
        test.assert_eq(enabled_actions(screen).use, nil, "a folder cannot be used")
        screen:select_entry(row(screen, "notes.txt"):get_entry())
        test.assert_eq(enabled_actions(screen).use, nil, "not downloaded yet, its type unknown")

        screen:select_entry(row(screen, "token/"):get_entry())
        screen:open_selected()
        screen:select_entry(row(screen, "s.png"):get_entry())
        test.assert_true(enabled_actions(screen).use)
        screen:run_action("use")
        test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
        test.assert_false(lifetime.alive(screen))
        test.assert_eq(game_client.find_token(client, "Bilbosza"):get_data().avatar, "token/s.png")
        test.assert_eq(assert(token_property(client, "avatar").input):get_text(), "token/s.png", "the panel shows the chosen one")
    end)
end)

test.case("for a token the player may not write, the workspace shows the asset without Use; from the quick access there is neither", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Smaug"
        })
        local screen = open_from_token_property(client, "avatar")
        test.assert_eq(assert(screen:get_selected()).path, "token/s.png")
        test.assert_eq(screen:get_details():get_action_button("use"), nil)
        client.app.backstack_manager:back()
        test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)

        screen = game_client.open_workspace(client)
        test.assert_eq(screen:get_details():get_action_button("use"), nil)
        test.assert_eq(screen:get_selected(), nil)
        test.assert_eq(screen:get_dir(), "")
    end)
end)
