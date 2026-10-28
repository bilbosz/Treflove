local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

local NAME = "The Shire"

local SERVER_GAME = [[
    local game = assert(app.games:get("the-shire"))
    local data = game:get_data()
    return table.concat(app.games:list(), " "), data.name, data.players.adam.group, table.concat(data.tokens.Hero.owners, " ")
]]

---@param driver ScenarioDriver
---@param index integer
---@return string
local function game_button(driver, index)
    return (driver:find("TextButton", nil, index) --[[@as TextButton]] ):get_text()
end

---@param driver ScenarioDriver
return function(driver)
    steps.log_in(driver)
    steps.open_games_menu(driver)
    driver:click("TextButton", "New Game")
    driver:wait_screen("NewGameScreen")
    driver:click("TextInput", nil, 1)
    driver:type(NAME)
    driver:click("TextButton", "Create")
    local game = driver:wait_screen("GameScreen") --[[@as GameScreen]]
    local page = game:get_page():get_data().name
    driver:expect(page == "Table", "the template's page is shown: " .. page)
    driver:find("Token", "Hero")
    driver:log("in the new game")

    driver:key(Consts.BACKSTACK_KEY)
    driver:wait_screen("UserMenuScreen")
    steps.open_games_menu(driver)
    driver:click("TextButton", "Join Game")
    driver:wait_screen("JoinGameScreen")
    local first, second = game_button(driver, 1), game_button(driver, 2)
    driver:expect(first == "Meadow" and second == NAME, "the games are listed by name: " .. first .. ", " .. second)

    local body = driver:server(SERVER_GAME)
    driver:expect(body == "meadow the-shire\tThe Shire\tmaster\tadam", "the server holds the new game, its creator its master and the owner of Hero: " .. body)
end
