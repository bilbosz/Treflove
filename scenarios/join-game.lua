local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    local screen = steps.join_game(driver)
    driver:expect(screen:get_page():get_data().name == "Meadow", "the fixture's page is shown")
    driver:find("Token", "Bilbo Baggins")
    driver:find("Token", "Smaug")
    driver:expect(#screen:get_page():get_tokens() == 2, "the page holds the fixture's two tokens")
end
