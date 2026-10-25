local Asset = require("data.asset")
local AssetDetails = require("game.assets.workspace.asset-details")
local AssetList = require("game.assets.workspace.asset-list")
local AssetUsageList = require("game.assets.workspace.asset-usage-list")
local Consts = require("app.consts")
local FormScreen = require("ui.form-screen")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local asset_usage = require("data.asset-usage")
local lifetime = require("lifetime")

---@class DroppedAsset A file dropped on the workspace, to upload
---@field name string The file's name, what the name field starts with
---@field data love.FileData

---The asset store as a file manager: one folder at a time on the left, the
---selected entry or the dropped file in the middle, what uses the selected
---entry on the right; the name field is what Rename, New Folder and Upload
---act with. The server answers every change; the listing is asked again
---after each one.
---@class AssetsWorkspaceScreen: FormScreen
---@field private _background Rectangle
---@field private _title Text
---@field private _path_label Text
---@field private _up_button TextButton
---@field private _open_button TextButton
---@field private _list AssetList
---@field private _details AssetDetails
---@field private _usage AssetUsageList
---@field private _entries AssetEntry[] The whole store, as the server listed it last
---@field private _writable boolean Whether the server lets this session change the store
---@field private _dir string The shown folder, `""` for the root
---@field private _selected AssetEntry|nil
---@field private _dropped DroppedAsset|nil
local AssetsWorkspaceScreen = class("AssetsWorkspaceScreen", FormScreen)

---@param self AssetsWorkspaceScreen
---@param caption string
---@param action fun()
---@return TextButton
local function _create_header_button(self, caption, action)
    local button = TextButton(self.screen, self, caption, action)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
    return button
end

function AssetsWorkspaceScreen:init()
    FormScreen.init(self)
    self._entries = {}
    self._writable = false
    self._dir = ""
    self._selected = nil
    self._dropped = nil

    local w, h = assert(app.width), assert(app.height)
    self._background = Rectangle(self.screen, w, h, Consts.BACKGROUND_COLOR)
    local title = Text(self.screen, "Assets", Consts.FOREGROUND_COLOR)
    self._title = title
    title:set_scale(Consts.MENU_BUTTON_SCALE)
    local path_label = Text(self.screen, "/", Consts.FOREGROUND_COLOR)
    self._path_label = path_label
    path_label:set_scale(Consts.PANEL_FIELD_SCALE)
    self._up_button = _create_header_button(self, "Up", function()
        self:go_up()
    end)
    self._open_button = _create_header_button(self, "Open", function()
        self:open_selected()
    end)
    self._list = AssetList(self, self.screen, 1, 1)
    local p = Consts.PADDING
    self._details = AssetDetails(self, self.screen, w * Consts.ASSETS_WORKSPACE_DETAILS_SHARE - p, h - 2 * p)
    self._usage = AssetUsageList(self, self.screen, w * (1 - Consts.ASSETS_WORKSPACE_LIST_SHARE - Consts.ASSETS_WORKSPACE_DETAILS_SHARE) - 1.5 * p, h - 2 * p)
    self:on_resize(w, h)
    self:_update_view()
end

function AssetsWorkspaceScreen:show()
    FormScreen.show(self)
    self:on_resize(app.width, app.height)
    self:refresh()
end

---@param w number
---@param h number
function AssetsWorkspaceScreen:on_resize(w, h)
    local p = Consts.PADDING
    self._background:set_size(w, h)
    self._title:set_position(p, p)
    local _, title_h = self._title:get_outer_size()
    local header_y = p + title_h + p * 0.5
    self._path_label:set_position(p, header_y)
    local _, header_h = self._path_label:get_outer_size()

    local list_w = w * Consts.ASSETS_WORKSPACE_LIST_SHARE - 1.5 * p
    local open_w = self._open_button:get_outer_size()
    self._open_button:set_position(p + list_w - open_w, header_y)
    local up_w = self._up_button:get_outer_size()
    self._up_button:set_position(p + list_w - open_w - p - up_w, header_y)

    local list_y = header_y + header_h + p * 0.5
    self._list:set_position(p, list_y)
    self._list:on_resize(list_w, h - list_y - p)

    local details_x = w * Consts.ASSETS_WORKSPACE_LIST_SHARE + 0.5 * p
    local details_w = w * Consts.ASSETS_WORKSPACE_DETAILS_SHARE - p
    self._details:set_position(details_x, p)
    self._details:on_resize(details_w, h - 2 * p)

    local usage_x = details_x + details_w + p
    self._usage:set_position(usage_x, p)
    self._usage:on_resize(w - usage_x - p, h - 2 * p)
end

---Asks the server for the store again
function AssetsWorkspaceScreen:refresh()
    app.asset_manager:list_assets(function(response)
        if lifetime.alive(self) then
            self:on_listing(response --[[@as ListAssetsResponse]] )
        end
    end)
end

---@private
---@param path string
---@return AssetEntry|nil
function AssetsWorkspaceScreen:_find_entry(path)
    for _, entry in ipairs(self._entries) do
        if entry.path == path then
            return entry
        end
    end
    return nil
end

---@param response ListAssetsResponse
function AssetsWorkspaceScreen:on_listing(response)
    if not response.success then -- the procedure notified; nothing to show
        assert(app.session):close_assets_workspace()
        return
    end
    self._entries = assert(response.entries)
    self._writable = response.writable
    while self._dir ~= "" and not self:_find_entry(self._dir) do -- the folder is gone meanwhile
        self._dir = Asset.get_parent(self._dir)
    end
    if self._selected then
        self._selected = self:_find_entry(self._selected.path)
    end
    self:_update_view()
end

---@return AssetEntry[] The entries of the shown folder
function AssetsWorkspaceScreen:get_shown_entries()
    ---@type AssetEntry[]
    local shown = {}
    for _, entry in ipairs(self._entries) do
        if Asset.get_parent(entry.path) == self._dir then
            table.insert(shown, entry)
        end
    end
    return shown
end

---@return string `""` at the root
function AssetsWorkspaceScreen:get_dir()
    return self._dir
end

---@return AssetEntry|nil
function AssetsWorkspaceScreen:get_selected()
    return self._selected
end

---@return boolean
function AssetsWorkspaceScreen:is_writable()
    return self._writable
end

---@return AssetList
function AssetsWorkspaceScreen:get_list()
    return self._list
end

---@return AssetDetails
function AssetsWorkspaceScreen:get_details()
    return self._details
end

---@return AssetUsageList
function AssetsWorkspaceScreen:get_usage()
    return self._usage
end

---@private
function AssetsWorkspaceScreen:_update_usage()
    local selected = self._selected
    self._usage:set_uses(selected and asset_usage.find(assert(app.data), selected.path) or {})
end

---Closes the workspace and centers the game's view on the page or the token
---@param use AssetUse
function AssetsWorkspaceScreen:go_to_use(use)
    local session = assert(app.session)
    local page = assert(session:get_game_screen()):get_page()
    session:close_assets_workspace()
    if use.kind == "page" then
        page:center_on_page()
    else
        page:center_on_token(use.name)
    end
end

---What the typed name would clash with in the shown folder, and whether an
---upload may replace it (a file: yes, a folder: no)
---@private
function AssetsWorkspaceScreen:_update_actions()
    local selected, name = self._selected, self._details:get_name()
    local writable = self._writable
    local taken = name ~= "" and self:_find_entry(Asset.join(self._dir, name)) or nil
    local free = name ~= "" and not taken
    self._details:set_actions({
        upload = writable and name ~= "" and self._dropped ~= nil and (not taken or taken.type == "file"),
        new_folder = writable and free,
        rename = writable and free and selected ~= nil,
        delete = writable and selected ~= nil
    })
    self._up_button:set_read_only(self._dir == "")
    self._open_button:set_read_only(not (selected and selected.type == "directory"))
end

---@private
function AssetsWorkspaceScreen:_update_view()
    self._path_label:set_text("/" .. self._dir)
    self._list:set_entries(self:get_shown_entries(), self._selected and self._selected.path)
    self._details:set_name_editable(self._writable)
    if not self._selected and not self._dropped then
        self._details:set_name("")
        self._details:set_type_text("")
        self._details:clear_preview()
    end
    self:_update_usage()
    self:_update_actions()
end

---@private
---@param path string A file of the store, present locally
function AssetsWorkspaceScreen:_show_local_content(path)
    local data = love.filesystem.newFileData(Asset.get_asset_path(path))
    if data then
        self._details:show_content(data)
    else
        self._details:clear_preview()
        self._details:set_type_text("Unknown")
    end
end

---The entry's name and type, and a file's content, downloaded when the
---client has no copy
---@param entry AssetEntry
function AssetsWorkspaceScreen:select_entry(entry)
    self._dropped = nil
    self._selected = entry
    self._list:set_selected(entry.path)
    self._details:set_name(Asset.get_name(entry.path))
    if entry.type == "directory" then
        self._details:clear_preview()
        self._details:set_type_text("Folder")
    elseif Asset(entry.path, false):get_type() == "file" then
        self:_show_local_content(entry.path)
    else
        self._details:clear_preview()
        self._details:set_type_text("")
        app.asset_manager:download_asset(entry.path, function()
            if lifetime.alive(self) and self._selected == entry and Asset(entry.path, false):get_type() == "file" then
                self:_show_local_content(entry.path)
            end
        end)
    end
    self:_update_usage()
    self:_update_actions()
end

---A click on the selected folder opens it; any other click selects
---@param entry AssetEntry
function AssetsWorkspaceScreen:on_entry_clicked(entry)
    if self._selected == entry and entry.type == "directory" then
        self:open_selected()
    else
        self:select_entry(entry)
    end
end

---@private
---@param dir string
function AssetsWorkspaceScreen:_show_dir(dir)
    self._dir = dir
    self._selected = nil
    self._dropped = nil
    self._list:scroll_to_top()
    self:_update_view()
end

function AssetsWorkspaceScreen:open_selected()
    local selected = self._selected
    if selected and selected.type == "directory" then
        self:_show_dir(selected.path)
    end
end

function AssetsWorkspaceScreen:go_up()
    if self._dir ~= "" then
        self:_show_dir(Asset.get_parent(self._dir))
    end
end

---A dropped file replaces the selection: its name in the field, its content
---previewed, Upload puts it into the shown folder
---@param file love.DroppedFile
function AssetsWorkspaceScreen:take_dropped_file(file)
    local data = file:read("data") --[[@as love.FileData]]
    local split = {}
    for component in string.gmatch(file:getFilename(), "[^/\\]+") do
        table.insert(split, component)
    end
    self._dropped = {
        name = split[#split] or "",
        data = data
    }
    self._selected = nil
    self._list:set_selected(nil)
    self._details:set_name(self._dropped.name)
    self._details:show_content(data)
    self:_update_usage()
    self:_update_actions()
end

function AssetsWorkspaceScreen:on_name_edited()
    self:_update_actions()
end

---@private
---@return RemoteProcedureCallback
function AssetsWorkspaceScreen:_after_change()
    return function(response)
        if not lifetime.alive(self) then
            return
        end
        if (response --[[@as {success: boolean}]] ).success then
            self._selected = nil
            self._dropped = nil
            self:_update_actions()
        end
        self:refresh()
    end
end

---@param action AssetDetailsAction
function AssetsWorkspaceScreen:run_action(action)
    local details = self._details
    if details:get_action_button(action):is_read_only() then
        return
    end
    local target = Asset.join(self._dir, details:get_name())
    if action == "upload" then
        app.asset_manager:upload_asset(target, assert(self._dropped).data, self:_after_change())
    elseif action == "new_folder" then
        app.asset_manager:create_folder(target, self:_after_change())
    elseif action == "rename" then
        app.asset_manager:rename_asset(assert(self._selected).path, target, self:_after_change())
    elseif action == "delete" then
        app.asset_manager:delete_asset(assert(self._selected).path, self:_after_change())
    else
        assert_unreachable()
    end
end

return AssetsWorkspaceScreen
