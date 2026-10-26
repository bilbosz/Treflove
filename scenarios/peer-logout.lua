local steps = require("scenarios.lib.steps")

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
        bob:wait()

        driver:client("bob", [[
            steps.log_out(driver)
        ]]):wait()
        driver:expect(get_class_name_of(driver:screen()) == "GameScreen", "the lead is still in the game")

        local connections, users = steps.server_sessions(driver)
        driver:expect(connections == 2, "the server still has two connections: " .. connections)
        driver:expect(users == "adam", "only the lead is logged in on the server: " .. users)
    end
}
