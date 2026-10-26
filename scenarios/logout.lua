local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    steps.join_game(driver)
    driver:key(Consts.BACKSTACK_KEY)
    driver:wait_screen("UserMenuScreen")
    driver:click("TextButton", "Log Out")
    driver:wait_screen("LoginScreen")
    driver:expect(not assert(app.session):is_logged_in(), "the session logged out")
    steps.log_in(driver)
end
