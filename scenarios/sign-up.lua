local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    steps.sign_up(driver, "frodo", "Frodo", "ring")
    local _, users = steps.server_sessions(driver)
    driver:expect(users == "frodo", "frodo is logged in on the server: " .. users)

    driver:click("TextButton", "Log Out")
    driver:wait_screen("LoginScreen")
    driver:expect(not assert(app.session):is_logged_in(), "the session logged out")
    steps.log_in(driver, "frodo", "ring")
    _, users = steps.server_sessions(driver)
    driver:expect(users == "frodo", "frodo is logged in again: " .. users)

    local account = driver:server([[
        local account = assert(app.accounts:get("frodo"))
        return account.name, #account.auth > 0
    ]])
    driver:expect(account == "Frodo\ttrue", "the server's accounts hold frodo: " .. account)
end
