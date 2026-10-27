local steps = require("scenarios.lib.steps")

local SERVER_GAMES = [[
    local games = {}
    for _, session in pairs(app._sessions) do
        if session:is_logged_in() then
            table.insert(games, session:get_user() .. ":" .. session:get_game():get_id())
        end
    end
    table.sort(games)
    return table.concat(games, " ")
]]

return {
    peers = {
        "bob"
    },
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", [[
            steps.join_game(driver, "piotr", "secret")
        ]])
        steps.join_game(driver)
        driver:find("Token", "Bilbo Baggins")
        driver:find("Token", "Smaug")
        bob:wait()

        driver:client("bob", [[
            driver:find("Token", "Bilbo Baggins")
            driver:expect(not driver:try_find("Token", "Smaug"), "piotr reads only the tokens he owns")
        ]]):wait()
        local tokens = driver:client("bob", [[
            return #assert(app.session:get_game_screen()):get_page():get_tokens()
        ]]):wait()
        driver:expect(tokens == "1", "bob's page holds one token: " .. tokens)

        local connections, users = steps.server_sessions(driver)
        driver:expect(connections == 2, "the server has two connections: " .. connections)
        driver:expect(users == "adam piotr", "both players are logged in on the server: " .. users)
        local games = driver:server(SERVER_GAMES)
        driver:expect(games == "adam:meadow piotr:meadow", "both sessions are in the fixture's game: " .. games)
    end
}
