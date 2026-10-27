local Consts = require("app.consts")

---@class steps
local steps = {}

steps.LOGIN = "adam"
steps.PASSWORD = "krause"
steps.GAME = "Meadow"

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
---@param game string|nil The game's name, defaults to `steps.GAME`
---@return GameScreen
function steps.join_game(driver, login, password, game)
    steps.log_in(driver, login, password)
    return steps.enter_game(driver, game)
end

---@param driver ScenarioDriver On the user menu
---@param game string|nil The game's name, defaults to `steps.GAME`
---@return GameScreen
function steps.enter_game(driver, game)
    driver:click("TextButton", "Games")
    driver:wait_screen("GamesScreen")
    driver:click("TextButton", game or steps.GAME)
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

---@param driver ScenarioDriver In the game
---@param label string The token's name, as its label shows it
---@return Token
local function _find_token(driver, label)
    return driver:find("Token", label) --[[@as Token]]
end

---@return table<Token, boolean> The selected tokens of the shown game
local function _get_select_set()
    return assert(assert(app.session):get_game_screen()):get_selection():get_select_set()
end

---@param driver ScenarioDriver In the game
---@param labels string[] The tokens' names, as their labels show them
---@return Token[] The tokens, in the order of `labels`, selected with one rectangle spanning their bounding squares, with whatever else it touches
function steps.select_tokens(driver, labels)
    ---@type Token[]
    local tokens = {}
    local from_x, from_y, to_x, to_y = math.huge, math.huge, -math.huge, -math.huge
    for _, label in ipairs(labels) do
        local token = _find_token(driver, label)
        table.insert(tokens, token)
        local r = token:get_radius()
        local x1, y1 = token:transform_to_global(-r, -r)
        local x2, y2 = token:transform_to_global(r, r)
        from_x, from_y = math.min(from_x, x1, x2), math.min(from_y, y1, y2)
        to_x, to_y = math.max(to_x, x1, x2), math.max(to_y, y1, y2)
    end
    driver:move(from_x, from_y)
    driver:press(from_x, from_y, Consts.PAGE_SELECT_BUTTON)
    driver:frames(1)
    driver:move(to_x, to_y)
    driver:frames(1)
    driver:release_button(to_x, to_y, Consts.PAGE_SELECT_BUTTON)
    driver:frames(1)
    local select_set = _get_select_set()
    for i, token in ipairs(tokens) do
        driver:expect(select_set[token], labels[i] .. " is selected")
    end
    return tokens
end

---@param driver ScenarioDriver In the game
---@param label string The token's name, as its label shows it
---@return Token The token, selected with whatever else its bounding square touches
function steps.select_token(driver, label)
    return steps.select_tokens(driver, {
        label
    })[1]
end

---@param driver ScenarioDriver In the game, the token selected
---@param label string The token's name, as its label shows it
---@param dx number Screen units
---@param dy number Screen units
---@return number x The token's position after the drag, in page meters
---@return number y
function steps.drag_token(driver, label, dx, dy)
    local token = _find_token(driver, label)
    driver:expect(_get_select_set()[token], label .. " is selected before the drag")
    local x, y = token:transform_to_global(0, 0)
    driver:move(x, y)
    driver:press(x, y, Consts.PAGE_DRAG_TOKEN_BUTTON)
    driver:frames(1)
    driver:move(x + dx, y + dy)
    driver:frames(1)
    driver:release_button(x + dx, y + dy, Consts.PAGE_DRAG_TOKEN_BUTTON)
    driver:frames(1)
    driver:log(string.format("dragged %s by (%g, %g)", label, dx, dy))
    return token:get_position()
end

---@param driver ScenarioDriver In the game, with `write` on the tokens
---@param id string The new token's id
---@param name string
---@param avatar string An image of the game's store
---@return Token The new token, shown on the page
function steps.create_token(driver, id, name, avatar)
    local session = assert(app.session)
    local page = assert(session:get_game_screen()):get_page()
    session:create_token(id, {
        name = name,
        diameter = 1,
        avatar = avatar,
        position = {
            page:get_view_center()
        }
    })
    local token = driver:wait_for(function()
        return driver:try_find("Token", name)
    end, nil, "the token " .. id) --[[@as Token]]
    driver:log("created the token " .. id)
    return token
end

---@param driver ScenarioDriver In the game, with `write` on the token
---@param label string The token's name, as its label shows it
function steps.delete_token(driver, label)
    local id = _find_token(driver, label):get_id()
    assert(app.session):delete_token(id)
    driver:wait_for(function()
        return not driver:try_find("Token", label)
    end, nil, "the token " .. id .. " gone")
    driver:log("deleted the token " .. id)
end

---@param driver ScenarioDriver On the login screen
---@param login string
---@param name string
---@param password string
---@return UserMenuScreen
function steps.sign_up(driver, login, name, password)
    driver:wait_screen("LoginScreen")
    driver:click("TextButton", "Sign Up")
    driver:wait_screen("SignUpScreen")
    for i, text in ipairs({
        login,
        name,
        password,
        password
    }) do
        driver:click("TextInput", nil, i)
        driver:type(text)
    end
    driver:click("TextButton", "Create Account")
    local screen = driver:wait_screen("UserMenuScreen") --[[@as UserMenuScreen]]
    driver:log("signed up")
    return screen
end

return steps
