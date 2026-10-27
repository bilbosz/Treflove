local Accounts = require("data.accounts")
local MenuScreen = require("screens.menu-screen")
local MenuTextInput = require("ui.menu.menu-text-input")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class SignUpScreen: MenuScreen
---@field private _session Session
---@field private _login_input MenuTextInput
---@field private _name_input MenuTextInput
---@field private _password_input MenuTextInput
---@field private _repeat_input MenuTextInput
local SignUpScreen = class("SignUpScreen", MenuScreen)

---@param login string
---@param name string
---@param password string
---@param repeated string
---@return string|nil reason Why the account is refused, `nil` when it may be asked for
local function _check(login, name, password, repeated)
    local reason = Accounts.check_login(login) or Accounts.check_name(name) or Accounts.check_password(password)
    if reason then
        return reason
    end
    if password ~= repeated then
        return "The passwords differ"
    end
    return nil
end

---@private
function SignUpScreen:_submit()
    local login, name, password = self._login_input:get_text(), self._name_input:get_text(), self._password_input:get_text()
    local reason = _check(login, name, password, self._repeat_input:get_text())
    if reason then
        app.notification_manager:notify(reason)
        return
    end
    self._session:sign_up(login, name, password)
end

---@param session Session
function SignUpScreen:init(session)
    self._session = session
    local function submit()
        self:_submit()
    end
    self._login_input = MenuTextInput(self, "Login", false, submit)
    self._name_input = MenuTextInput(self, "Name", false, submit)
    self._password_input = MenuTextInput(self, "Password", true, submit)
    self._repeat_input = MenuTextInput(self, "Repeat", true, submit)
    MenuScreen.init(self, "Sign Up", {
        self._login_input,
        self._name_input,
        self._password_input,
        self._repeat_input,
        MenuTextButton(self, "Create Account", submit),
        MenuTextButton(self, "Back", function()
            app.backstack_manager:back()
        end)
    })
end

return SignUpScreen
