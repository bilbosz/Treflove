local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

local LOGIN = "frodo"
local NAME = "Bag End"

local SERVER_GAME = [[
    local data = assert(app.games:get("bag-end")):get_data()
    return data.name, data.players.frodo.group, table.concat(data.tokens.Hero.owners, " ")
]]

---@param driver ScenarioDriver
return function(driver)
    steps.sign_up(driver, LOGIN, "Frodo", "ring")
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
    driver:click("TextButton", "Join Game")
    driver:wait_screen("GamesScreen")
    driver:find("TextButton", NAME)

    local body = driver:server(SERVER_GAME)
    driver:expect(body == "Bag End\tmaster\tfrodo", "the server holds the new game, its creator its master and the owner of Hero: " .. body)
end
