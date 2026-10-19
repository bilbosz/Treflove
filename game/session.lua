local GameDataRp = require("game.game-data-rp")
local Login = require("login.login")
local LoginScreen = require("login.login-screen")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")
local lifetime = require("lifetime")

---@class Session: Object
---@field _user string|nil Logged-in user name
---@field _connection Connection|nil
---@field _login Login|nil
---@field _game_data_rp GameDataRp
---@field _user_menu_screen UserMenuScreen|nil
---@field _period lifetime.Token|nil The "logged in" span (client only): the menu screen, the game screen and their back entries die with it
local Session = class("Session")

---@param self Session
---@param user string
local function _on_login(self, user)
    assert(not self._user)
    self._user = user
    if app.is_client then
        app.text_event_manager:set_text_input(false)
        -- lua-lifetime: being logged in is a token. What belongs to the
        -- logged-in user (the menu screen, its back entry, later the game
        -- screen) is anchored to it and dies with it, newest first
        -- (lib/lua-lifetime/docs/02-semantics.md, "Tokens").
        local period = lifetime.attach(lifetime.token("logged in"), self)
        self._period = period
        self._user_menu_screen = UserMenuScreen(self):attach_lifetime(period)
        app.screen_manager:show(self._user_menu_screen)
        app.backstack_manager:push(function()
            self:logout()
        end):attach_lifetime(period)
    end
end

---@param self Session
local function _on_logout(self)
    assert(self._user)
    self._user = nil
    if app.is_client then
        -- lua-lifetime: ending the period destroys the back entry (it leaves
        -- the stack) and the menu screen (it hides itself and the screen
        -- manager forgets it). The login screen lives as long as the session.
        lifetime.destroy(self._period)
        self._period = nil
        self._user_menu_screen = nil
        app.screen_manager:show(LoginScreen(self._login):attach_lifetime(self))
    end
end

---@param connection Connection
function Session:init(connection)
    self._connection = connection
    self._user = nil
    self._period = nil
    -- lua-lifetime: what the session owns is anchored where it is made and
    -- dies with the session, newest first; Session:release is gone.
    local login = Login(self, function(user)
        _on_login(self, user)
        if app.is_client then
            self._user_menu_screen:join_game()
        end
    end, function()
        _on_logout(self)
    end):attach_lifetime(self)
    self._login = login
    self._game_data_rp = GameDataRp(self._connection):attach_lifetime(self)
    app.asset_manager:register_session(self)

    if app.is_client then
        login:login("adam", "krause")
    end
end

---@return string|nil
function Session:get_user()
    return self._user
end

---@return Connection
function Session:get_connection()
    return self._connection
end

---The "logged in" span, to anchor what must not outlive the login (client only).
---@return lifetime.Token
function Session:get_period()
    assert(app.is_client and self._period)
    return self._period
end

---@param user string
---@param password string
function Session:login(user, password)
    self._login:login(user, password)
end

function Session:logout()
    self._login:logout()
end

---@return boolean
function Session:is_logged_in()
    return not not self._user
end

function Session:join_game()
    assert(app.is_client)
    app.screen_manager:show(WaitingScreen("Loading..."))
    self._game_data_rp:send_request({})
end

return Session
