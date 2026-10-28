local steps = require("scenarios.lib.steps")

local REFUSAL = "You may not delete the game \"Meadow\""
local DELETED = "The game \"Meadow\" was deleted"

local BOB_IS_REFUSED = [[
    steps.log_in(driver, "piotr", "secret")
    steps.delete_game(driver, "Meadow")
    driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the refusal")
    driver:click("TextButton", "Back")
    driver:wait_screen("ManageGamesScreen")
    driver:click("TextButton", "Back")
    driver:wait_screen("UserMenuScreen")
    steps.enter_game(driver)
]]

local BOB_IS_OUT = [[
    driver:wait_screen("UserMenuScreen")
    local told = driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the notification")
    return tostring(told ~= nil) .. " " .. tostring(app.data == nil) .. " " .. tostring(app.asset_manager:get_store() == nil)
]]

local SERVER_GAMES = [[
    local in_game = 0
    for _, session in pairs(app._sessions) do
        if session:is_in_game() then
            in_game = in_game + 1
        end
    end
    return table.concat(app.games:list(), " "), tostring(love.filesystem.getInfo("s/games/meadow") ~= nil), in_game
]]

return {
    peers = {
        "bob"
    },
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", string.format(BOB_IS_REFUSED, REFUSAL))
        steps.log_in(driver)
        bob:wait()
        local before = driver:server(SERVER_GAMES)
        driver:expect(before == "meadow\ttrue\t1", "the game is there, bob in it: " .. before)

        steps.delete_game(driver, "Meadow")
        driver:wait_for(function()
            return driver:try_find("Text", DELETED)
        end, nil, "the deletion's notification")
        driver:wait_screen("ManageGamesScreen")
        local out = driver:client("bob", string.format(BOB_IS_OUT, DELETED)):wait()
        driver:expect(out == "true true true", "bob is back on the menu, told, without the game's data and store: " .. out)

        local after = driver:server(SERVER_GAMES)
        driver:expect(after == "\tfalse\t0", "the server has no game and nobody is in one: " .. after)
    end
}
