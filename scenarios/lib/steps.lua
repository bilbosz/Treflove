---@class steps
local steps = {}

steps.LOGIN = "adam"
steps.PASSWORD = "krause"

---@param driver ScenarioDriver
---@param login string|nil Defaults to `steps.LOGIN`
---@param password string|nil Defaults to `steps.PASSWORD`
function steps.log_in(driver, login, password)
    driver:wait_screen("LoginScreen")
    driver:click("TextInput", nil, 1)
    driver:type(login or steps.LOGIN)
    driver:click("TextInput", nil, 2)
    driver:type(password or steps.PASSWORD)
    driver:click("TextButton", "Sign In")
    driver:wait_screen("UserMenuScreen")
    driver:log("logged in")
end

---@param driver ScenarioDriver
---@return GameScreen
function steps.join_game(driver)
    steps.log_in(driver)
    driver:click("TextButton", "Join Game")
    local screen = driver:wait_screen("GameScreen") --[[@as GameScreen]]
    driver:log("in the game")
    return screen
end

return steps
