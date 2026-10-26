local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    steps.join_game(driver)
    steps.log_out(driver)
    steps.log_in(driver)
end
