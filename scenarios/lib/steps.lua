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
    steps.open_games_menu(driver)
    driver:click("TextButton", "Join")
    driver:wait_screen("JoinGameScreen")
    driver:click("TextButton", game or steps.GAME)
    local screen = driver:wait_screen("GameScreen") --[[@as GameScreen]]
    driver:log("in the game")
    return screen
end

---@param driver ScenarioDriver On the user menu
---@return GamesMenuScreen
function steps.open_games_menu(driver)
    driver:click("TextButton", "Games")
    return driver:wait_screen("GamesMenuScreen") --[[@as GamesMenuScreen]]
end

---@param driver ScenarioDriver On the user menu
---@return DeleteGameScreen The games the player may delete
function steps.open_delete_game(driver)
    steps.open_games_menu(driver)
    driver:click("TextButton", "Delete")
    return driver:wait_screen("DeleteGameScreen") --[[@as DeleteGameScreen]]
end

---@param driver ScenarioDriver On the user menu
---@param name string The game's name, picked among the games to delete and confirmed with Yes; the caller waits for the outcome
function steps.delete_game(driver, name)
    steps.open_delete_game(driver)
    driver:click("TextButton", name)
    driver:wait_screen("ConfirmDeleteGameScreen")
    driver:click("TextButton", "Yes")
    driver:log("asked to delete the game " .. name)
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
    steps.open_panel(driver, "Tokens")
    driver:click("TextButton", "New")
    driver:wait_screen("NewTokenScreen")
    for i, text in ipairs({
        id,
        name,
        avatar
    }) do
        driver:click("TextInput", nil, i)
        driver:type(text)
    end
    driver:click("TextButton", "Create")
    driver:wait_screen("GameScreen")
    local token = driver:wait_for(function()
        return driver:try_find("Token", name)
    end, nil, "the token " .. id) --[[@as Token]]
    driver:log("created the token " .. id)
    return token
end

---@param driver ScenarioDriver In the game, with `write` on the token
---@param label string The token's name, as its label shows it
function steps.delete_token(driver, label)
    local token = steps.select_token(driver, label)
    local id = token:get_id()
    local selected = 0
    for _ in pairs(_get_select_set()) do
        selected = selected + 1
    end
    driver:expect(selected == 1, string.format("%s is selected alone: %d tokens selected", label, selected))
    driver:click("TextButton", "Delete")
    driver:wait_for(function()
        return not driver:try_find("Token", label)
    end, nil, "the token " .. id .. " gone")
    driver:log("deleted the token " .. id)
end

---@param driver ScenarioDriver In the game
---@param caption string The quick access entry of a side panel: "Tokens", "Game", "Pages", "Groups", "Permissions" or "Token Properties"
---@return SidePanel The panel, shown; an entry whose panel is shown already is not clicked again, which would hide it
function steps.open_panel(driver, caption)
    local screen = assert(assert(app.session):get_game_screen())
    local button = driver:find("TextButton", caption) --[[@as TextButton]]
    if not button:is_active() then
        driver:click(button)
    end
    local panel = driver:wait_for(function()
        local shown = screen:get_panel()
        return button:is_active() and shown and shown:is_enabled() and shown
    end, nil, "the panel " .. caption) --[[@as SidePanel]]
    driver:log("opened the panel " .. caption)
    return panel
end

---@param driver ScenarioDriver In the game, the panel shown
---@param panel EntriesPanel
---@param id string An entry the panel lists
function steps.select_entry(driver, panel, id)
    ---@type TextButton|nil
    local found
    for _, button in ipairs(panel:get_list_buttons()) do
        if button:get_text() == id then
            found = button
        end
    end
    driver:expect(found, string.format("%s lists %q", get_class_name_of(panel), id))
    driver:click(assert(found))
    driver:wait_for(function()
        return panel:get_selected() == id
    end, nil, "the entry " .. id .. " selected")
end

---@param driver ScenarioDriver
---@param input TextInput|NumberInput A field shown, not read-only
---@param text string Replaces what the field holds, all of it selected with Ctrl+A and typed over character by character as a player does
function steps.set_text(driver, input, text)
    driver:click(input)
    driver:expect(input:is_focused(), "the field took the focus")
    driver:key_down("lctrl")
    driver:key("a")
    driver:key_up("lctrl")
    driver:type(text)
    driver:expect(input:get_text() == text, string.format("the field holds %q: %q", text, input:get_text()))
end

---@param driver ScenarioDriver
---@param box SelectionBox Shown, not read-only
---@param key string One of the box's options: its row is clicked in the list a click on the box opens, as a player picks it
function steps.select_option(driver, box, key)
    driver:click(box)
    driver:wait_for(function()
        return box:is_open()
    end, nil, "the selection box's list open")
    ---@type string|nil
    local title
    for _, option in ipairs(box:get_options()) do
        if option.key == key then
            title = option.title
        end
    end
    driver:expect(title, string.format("the selection box offers %q", key))
    driver:click("SelectionBoxRow", assert(title))
    driver:wait_for(function()
        return box:get_selected() == key
    end, nil, "the option " .. key .. " selected")
    driver:log(string.format("selected the option %s (%s)", key, title))
end

---@param driver ScenarioDriver In the assets workspace, opened with a pick of an image (a panel's Browse...)
---@param path string An image of the game's store, in a folder of the store's root
function steps.pick_image(driver, path)
    driver:wait_for(function()
        return driver:try_find("AssetListRow", "token/")
    end, nil, "the listing")
    local folder, name = string.match(path, "^([^/]+)/([^/]+)$")
    driver:expect(folder and name, "a file in a folder of the root: " .. path)
    driver:click("AssetListRow", folder .. "/")
    driver:click("AssetListRow", folder .. "/")
    local row = driver:wait_for(function()
        return driver:try_find("AssetListRow", name)
    end, nil, "the row " .. name) --[[@as Control]]
    driver:click(row)
    local use = driver:wait_for(function()
        local button = driver:try_find("TextButton", "Use") --[[@as TextButton|nil]]
        return button and not button:is_read_only() and button
    end, nil, "Use enabled for " .. path) --[[@as TextButton]]
    driver:click(use)
    driver:wait_screen("GameScreen")
    driver:log("picked the image " .. path)
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
