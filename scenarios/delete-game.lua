local steps = require("scenarios.lib.steps")

local REFUSAL = "You may not delete the game \"Meadow\""
local DELETED = "The game \"Meadow\" was deleted"

local BOB_HAS_NOTHING_TO_DELETE = [[
    steps.log_in(driver, "piotr", "secret")
    steps.open_delete_game(driver)
    driver:expect(not driver:try_find("TextButton", "Meadow"), "Meadow is not offered to a player who may not delete it")
    driver:find("Text", "No games to delete")
    app.session:delete_game("meadow")
    driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the refusal of a deletion sent past the gate")
    driver:click("TextButton", "Back")
    driver:wait_screen("GamesMenuScreen")
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
        local bob = driver:client("bob", string.format(BOB_HAS_NOTHING_TO_DELETE, REFUSAL))
        steps.log_in(driver)
        bob:wait()
        local before = driver:server(SERVER_GAMES)
        driver:expect(before == "meadow\ttrue\t1", "the game is there, bob in it: " .. before)

        steps.open_delete_game(driver)
        driver:click("TextButton", "Meadow")
        driver:wait_screen("ConfirmDeleteGameScreen")
        driver:find("Text", "Are you sure to delete \"Meadow\" game?")
        driver:click("TextButton", "No")
        driver:wait_screen("DeleteGameScreen")
        driver:click("TextButton", "Back")
        driver:wait_screen("GamesMenuScreen")
        driver:click("TextButton", "Back")
        driver:wait_screen("UserMenuScreen")
        local unchanged = driver:server(SERVER_GAMES)
        driver:expect(unchanged == before, "No deletes nothing: " .. unchanged)

        steps.delete_game(driver, "Meadow")
        driver:wait_for(function()
            return driver:try_find("Text", DELETED)
        end, nil, "the deletion's notification")
        driver:wait_screen("GamesMenuScreen")
        local out = driver:client("bob", string.format(BOB_IS_OUT, DELETED)):wait()
        driver:expect(out == "true true true", "bob is back on the menu, told, without the game's data and store: " .. out)

        local after = driver:server(SERVER_GAMES)
        driver:expect(after == "\tfalse\t0", "the server has no game and nobody is in one: " .. after)
    end
}
