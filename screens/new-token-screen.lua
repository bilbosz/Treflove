local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")
local MenuTextInput = require("ui.menu.menu-text-input")
local lifetime = require("lifetime")
local media = require("utils.media")
local token_id = require("game.token.token-id")

---@class NewTokenScreen: MenuScreen
---@field private _session Session
---@field private _id_input MenuTextInput
---@field private _name_input MenuTextInput
---@field private _avatar_input MenuTextInput A path in the game's store, typed or chosen with Browse...
local NewTokenScreen = class("NewTokenScreen", MenuScreen)

---@param session Session In the game: the token is placed at the center of its page's view
function NewTokenScreen:init(session)
    assert(session)
    self._session = session
    local create = function()
        self:create()
    end
    self._id_input = MenuTextInput(self, "Id", false, create)
    self._name_input = MenuTextInput(self, "Name", false, create)
    self._avatar_input = MenuTextInput(self, "Avatar", false, create)
    MenuScreen.init(self, "New Token", {
        self._id_input,
        self._name_input,
        self._avatar_input,
        MenuTextButton(self, "Browse...", function()
            self:browse()
        end),
        MenuTextButton(self, "Create", create),
        MenuTextButton(self, "Back", function()
            app.backstack_manager:back()
        end)
    })
end

function NewTokenScreen:browse()
    local avatar = self._avatar_input:get_text()
    self._session:open_assets_workspace({
        path = avatar ~= "" and avatar or nil,
        media_type = media.Type.IMAGE,
        on_pick = function(path)
            if lifetime.alive(self) then
                self._avatar_input:set_text(path)
            end
        end
    })
end

---@private
---@param id string
---@param name string
---@param avatar string
---@return string|nil Why the token cannot be created, for the user; `nil` when it can be asked for
function NewTokenScreen:_check(id, name, avatar)
    local reason = token_id.check(assert(app.data), id)
    if reason then
        return reason
    end
    if name == "" then
        return "A token needs a name"
    end
    if avatar == "" then
        return "A token needs an avatar"
    end
    return nil
end

function NewTokenScreen:create()
    local id, name, avatar = self._id_input:get_text(), self._name_input:get_text(), self._avatar_input:get_text()
    local reason = self:_check(id, name, avatar)
    if reason then
        app.notification_manager:notify(reason)
        return
    end
    local x, y = assert(self._session:get_game_screen()):get_page():get_view_center()
    self._session:create_token(id, {
        name = name,
        diameter = 1,
        avatar = avatar,
        position = {
            x,
            y
        }
    }, function(response)
        if response.success and lifetime.alive(self) then
            self._session:close_new_token()
        end
    end)
end

return NewTokenScreen
