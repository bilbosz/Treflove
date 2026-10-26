local Consts = require("app.consts")

---@class steps
local steps = {}

steps.LOGIN = "adam"
steps.PASSWORD = "krause"

local SERVER_SESSIONS = [[
    local connections = 0
    for _ in pairs(app.connection_manager:get_connections()) do
        connections = connections + 1
    end
    local users = {}
    for _, session in pairs(app._sessions) do
        if session:is_logged_in() then
            table.insert(users, session:get_user())
        end
    end
    table.sort(users)
    return connections, table.concat(users, " ")
]]

---@param driver ScenarioDriver
---@param login string|nil Defaults to `steps.LOGIN`
---@param password string|nil Defaults to `steps.PASSWORD`
---@return UserMenuScreen
function steps.log_in(driver, login, password)
    driver:wait_screen("LoginScreen")
    driver:click("TextInput", nil, 1)
    driver:type(login or steps.LOGIN)
    driver:click("TextInput", nil, 2)
    driver:type(password or steps.PASSWORD)
    driver:click("TextButton", "Sign In")
    local screen = driver:wait_screen("UserMenuScreen") --[[@as UserMenuScreen]]
    driver:log("logged in")
    return screen
end

---@param driver ScenarioDriver
---@param login string|nil Defaults to `steps.LOGIN`
---@param password string|nil Defaults to `steps.PASSWORD`
---@return GameScreen
function steps.join_game(driver, login, password)
    steps.log_in(driver, login, password)
    driver:click("TextButton", "Join Game")
    local screen = driver:wait_screen("GameScreen") --[[@as GameScreen]]
    driver:log("in the game")
    return screen
end

---@param driver ScenarioDriver In the game
function steps.log_out(driver)
    driver:key(Consts.BACKSTACK_KEY)
    driver:wait_screen("UserMenuScreen")
    driver:click("TextButton", "Log Out")
    driver:wait_screen("LoginScreen")
    driver:expect(not assert(app.session):is_logged_in(), "the session logged out")
    driver:log("logged out")
end

---@param driver ScenarioDriver In the game
---@return AssetsWorkspaceScreen With the server's listing shown
function steps.open_assets_workspace(driver)
    driver:click("TextButton", "Assets")
    local screen = driver:wait_screen("AssetsWorkspaceScreen") --[[@as AssetsWorkspaceScreen]]
    driver:wait_for(function()
        return driver:try_find("AssetListRow", "token/")
    end, nil, "the listing")
    driver:log("in the assets workspace")
    return screen
end

---@param driver ScenarioDriver
---@return number connections The server's
---@return string users The users of the server's logged-in sessions, sorted, joined by spaces
function steps.server_sessions(driver)
    local body = driver:server(SERVER_SESSIONS)
    local connections, users = string.match(body, "^(%d+)\t(.*)$")
    driver:expect(connections and users, "the server's sessions: " .. body)
    return assert(tonumber(connections)), assert(users)
end

return steps
