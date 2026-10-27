local steps = require("scenarios.lib.steps")

local LABEL = "Bilbo Baggins"
local DRAG_X, DRAG_Y = 80, 40
local TOLERANCE = 1e-6

return {
    peers = {
        "bob"
    },
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", [[
            steps.join_game(driver, "piotr", "secret")
        ]])
        local game = steps.join_game(driver)
        bob:wait()
        driver:client("bob", [[
            driver:find("Token", "Bilbo Baggins")
            driver:expect(not driver:try_find("Token", "Smaug"), "piotr reads only the tokens he owns")
        ]]):wait()

        local token = steps.select_token(driver, LABEL)
        local start_x, start_y = token:get_position()
        local coordinates = game:get_page():get_page_coordinates()
        local x, y = token:transform_to_global(0, 0)
        local from_x, from_y = coordinates:transform_to_local(x, y)
        local to_x, to_y = coordinates:transform_to_local(x + DRAG_X, y + DRAG_Y)
        local expected_x, expected_y = start_x + to_x - from_x, start_y + to_y - from_y
        driver:expect(expected_x > start_x and expected_y > start_y, string.format("the drag moves by a positive offset: (%g, %g)", to_x - from_x, to_y - from_y))

        local moved_x, moved_y = steps.drag_token(driver, LABEL, DRAG_X, DRAG_Y)
        driver:expect(math.abs(moved_x - expected_x) < TOLERANCE and math.abs(moved_y - expected_y) < TOLERANCE,
                      string.format("Bilbo moved from (%g, %g) to (%g, %g), expected (%g, %g)", start_x, start_y, moved_x, moved_y, expected_x, expected_y))
        driver:log(string.format("Bilbo at (%g, %g) on the lead", moved_x, moved_y))
        local position = assert(app.data).tokens.Bilbo.position
        driver:expect(position[1] == moved_x and position[2] == moved_y, string.format("the client's data holds Bilbo at (%g, %g)", position[1], position[2]))
    end
}
