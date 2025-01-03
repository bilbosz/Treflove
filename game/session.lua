local GameDataRp = require("game.game-data-rp")
local Login = require("login.login")
local LoginScreen = require("login.login-screen")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")

---@class Session
local Session = class("Session")

---@param self Session
---@param user string
local function _on_login(self, user)
    assert(not self.user)
    self.user = user
    if app.is_client then
        app.text_event_manager:set_text_input(false)
        self._user_menu_screen = UserMenuScreen(self)
        app.screen_manager:show(self._user_menu_screen)
        self._backstack_cb = function()
            self:logout()
        end

        app.backstack_manager:push(self._backstack_cb)
    end
end

---@param self Session
local function _on_logout(self)
    assert(self.user)
    self.user = nil
    if app.is_client then
        app.backstack_manager:pop(self._backstack_cb)
        self._backstack_cb = nil
        self._user_menu_screen = nil
        app.screen_manager:show(LoginScreen(self.login))
    end
end

---@param connection Connection
function Session:init(connection)
    self.connection = connection
    self.user = nil
    local login = Login(self, function(user)
        _on_login(self, user)
        if app.is_client then
            self._user_menu_screen:join_game()
        end
    end, function()
        _on_logout(self)
    end)
    self.login = login
    self.game_data_rp = GameDataRp(self.connection)
    app.asset_manager:register_session(self)

    if app.is_client then
        login:login("adam", "krause")
    end
end

---@return string
function Session:get_user()
    return self.user
end

---@return Connection
function Session:get_connection()
    return self.connection
end

---@param user string
---@param password string
function Session:login(user, password)
    self.login:login(user, password)
end

function Session:logout()
    self.login:logout()
end

---@return boolean
function Session:is_logged_in()
    return not not self.user
end

function Session:join_game()
    assert(app.is_client)
    app.screen_manager:show(WaitingScreen("Loading..."))
    self.game_data_rp:send_request({})
end

function Session:release()
    app.asset_manager:unregister_session(self)
    if app.is_client then
        app.backstack_manager:pop(self._backstack_cb)
        self._backstack_cb = nil
    end
    self.login:release()
    self.login = nil
    self.connection = nil
end

return Session
