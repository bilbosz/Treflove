local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    local screen = steps.join_game(driver)
    local data = assert(app.data)
    driver:expect(data.name == "Meadow", "the fixture's game is joined: " .. data.name)
    local root = app.asset_manager:get_store():get_root()
    driver:expect(root == "c/games/meadow", "the client keeps the game's assets in a store of its own: " .. root)
    driver:expect(screen:get_page():get_data().name == "Meadow", "the fixture's page is shown")
    driver:find("Token", "Bilbo Baggins")
    driver:find("Token", "Smaug")
    driver:expect(#screen:get_page():get_tokens() == 2, "the page holds the fixture's two tokens")
end
