local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
---@param field TextInput
---@param text string
---@param caret integer
---@param start integer The selection's start
---@param finish integer The selection's end
---@param after string The step that led here, named in a failure
local function expect_field(driver, field, text, caret, start, finish, after)
    local actual_start, actual_finish = field:get_selection()
    driver:expect(field:get_text() == text and field:get_caret() == caret and actual_start == start and actual_finish == finish,
                  string.format("after %s the field holds %q, the caret at %d, the selection [%d, %d): %q, %d, [%d, %d)", after, text, caret, start, finish, field:get_text(), field:get_caret(),
                                actual_start, actual_finish))
end

---@param driver ScenarioDriver
---@param modifier love.KeyConstant
---@param key love.KeyConstant
local function chord(driver, modifier, key)
    driver:key_down(modifier)
    driver:key(key)
    driver:key_up(modifier)
end

---@param driver ScenarioDriver
return function(driver)
    driver:wait_screen("LoginScreen")
    local login = driver:find("TextInput") --[[@as TextInput]]
    driver:click(login)
    driver:expect(login:is_focused(), "the login field took the focus")
    expect_field(driver, login, "", 0, 0, 0, "the click")

    driver:type("adxm")
    expect_field(driver, login, "adxm", 4, 4, 4, "typing")
    driver:key("left")
    expect_field(driver, login, "adxm", 3, 3, 3, "Left")
    driver:key("backspace")
    expect_field(driver, login, "adm", 2, 2, 2, "Backspace")
    driver:key("home")
    expect_field(driver, login, "adm", 0, 0, 0, "Home")
    chord(driver, "lshift", "end")
    expect_field(driver, login, "adm", 3, 0, 3, "Shift+End")
    driver:type("piotr")
    expect_field(driver, login, "piotr", 5, 5, 5, "typing over the selection")
    chord(driver, "lctrl", "a")
    expect_field(driver, login, "piotr", 5, 0, 5, "Ctrl+A")
    chord(driver, "lctrl", "c")
    expect_field(driver, login, "piotr", 5, 0, 5, "Ctrl+C")
    local clipboard = app.text_event_manager:get_clipboard()
    driver:expect(clipboard == "piotr", "Ctrl+C copied the selection: " .. clipboard)
    driver:key("end")
    expect_field(driver, login, "piotr", 5, 5, 5, "End")
    chord(driver, "lctrl", "v")
    expect_field(driver, login, "piotrpiotr", 10, 10, 10, "Ctrl+V")

    steps.set_text(driver, login, steps.LOGIN)
    driver:click("TextInput", nil, 2)
    driver:type(steps.PASSWORD)
    driver:click("TextButton", "Sign In")
    driver:wait_screen("UserMenuScreen")
    local _, users = steps.server_sessions(driver)
    driver:expect(users == steps.LOGIN, "the login set_text typed is the one the server logged in: " .. users)
    steps.enter_game(driver)
end
