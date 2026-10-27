local steps = require("scenarios.lib.steps")
local Utils = require("utils.utils")

local LABEL = "Bilbo Baggins"
local DRAG_X, DRAG_Y = 80, 40
local TOLERANCE = 1e-6
local REFUSAL = "Not allowed to change the token \"Bilbo\""

local SAVED_BILBO = [[
    local data = assert(table.from_string(assert(love.filesystem.read("s/games/meadow/save.lua"))))
    local position = data.tokens.Bilbo.position
    return position[1], position[2]
]]

local BOB_SEES_THE_MOVE = [[
    local token = assert(app.session:get_game_screen()):get_page():find_token("Bilbo")
    driver:wait_for(function()
        local x, y = token:get_position()
        return x ~= 6 or y ~= 7
    end, nil, "Bilbo moved on bob's client")
    local x, y = token:get_position()
    return x, y, require("utils.utils").get_time()
]]

local BOB_IS_REFUSED = [[
    app.session:update_token("Bilbo", {position = {1, 1}})
    driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the refusal")
    local x, y = assert(app.session:get_game_screen()):get_page():find_token("Bilbo"):get_position()
    return x, y
]]

---@param driver ScenarioDriver
---@param body string Two numbers, tab-separated
---@param x number
---@param y number
---@param what string
local function _expect_position(driver, body, x, y, what)
    local x_field, y_field = string.match(body, "^([^\t]+)\t([^\t]+)")
    local got_x, got_y = tonumber(x_field), tonumber(y_field)
    driver:expect(got_x and got_y and math.abs(got_x - x) < TOLERANCE and math.abs(got_y - y) < TOLERANCE, string.format("%s: %s, expected (%g, %g)", what, body, x, y))
end

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
        local watch = driver:client("bob", BOB_SEES_THE_MOVE)

        local token = steps.select_token(driver, LABEL)
        local start_x, start_y = token:get_position()
        local coordinates = game:get_page():get_page_coordinates()
        local x, y = token:transform_to_global(0, 0)
        local from_x, from_y = coordinates:transform_to_local(x, y)
        local to_x, to_y = coordinates:transform_to_local(x + DRAG_X, y + DRAG_Y)
        local expected_x, expected_y = start_x + to_x - from_x, start_y + to_y - from_y
        driver:expect(expected_x > start_x and expected_y > start_y, string.format("the drag moves by a positive offset: (%g, %g)", to_x - from_x, to_y - from_y))

        local moved_x, moved_y = steps.drag_token(driver, LABEL, DRAG_X, DRAG_Y)
        local released = Utils.get_time()
        driver:expect(math.abs(moved_x - expected_x) < TOLERANCE and math.abs(moved_y - expected_y) < TOLERANCE,
                      string.format("Bilbo moved from (%g, %g) to (%g, %g), expected (%g, %g)", start_x, start_y, moved_x, moved_y, expected_x, expected_y))
        driver:log(string.format("Bilbo at (%g, %g) on the lead", moved_x, moved_y))
        local position = assert(app.data).tokens.Bilbo.position
        driver:expect(position[1] == moved_x and position[2] == moved_y, string.format("the client's data holds Bilbo at (%g, %g)", position[1], position[2]))

        local seen = watch:wait()
        _expect_position(driver, seen, moved_x, moved_y, "Bilbo on bob's client")
        local seen_at = string.match(seen, "^[^\t]+\t[^\t]+\t([^\t]+)$")
        driver:log(string.format("bob saw the move %.1f ms after the release", (assert(tonumber(seen_at)) - released) * 1000))
        _expect_position(driver, driver:server(SAVED_BILBO), moved_x, moved_y, "Bilbo in the server's save")

        _expect_position(driver, driver:client("bob", string.format(BOB_IS_REFUSED, REFUSAL)):wait(), moved_x, moved_y, "Bilbo on bob's client after the refusal")
        _expect_position(driver, driver:server(SAVED_BILBO), moved_x, moved_y, "Bilbo in the server's save after the refusal")
    end
}
