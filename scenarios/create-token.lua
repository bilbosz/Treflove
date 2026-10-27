local steps = require("scenarios.lib.steps")
local Utils = require("utils.utils")

local ID = "Gandalf"
local NAME = "Gandalf"
local AVATAR = "token/smaug.png"
local DRAG_X, DRAG_Y = 60, 40
local TOLERANCE = 1e-6
local CREATE_REFUSAL = "Not allowed to create a token"
local DELETE_REFUSAL = "Not allowed to delete the token \"Smaug\""

local SAVE = [[
    return assert(table.from_string(assert(love.filesystem.read("s/games/meadow/save.lua"))))
]]

local GRANT = [[
    local game = app.games:get("meadow")
    game:get_data().players.piotr.permissions = {"write:tokens/@owned", "read:tokens/Gandalf", "write:tokens/Gandalf"}
    game:save()
]]

local BOB_DOES_NOT_SEE_IT = [[
    driver:expect(not driver:try_find("Token", "Gandalf"), "no Gandalf on bob's page")
    driver:expect(app.data.tokens.Gandalf == nil, "no Gandalf in bob's data")
]]

local BOB_ENTERS_AGAIN = [[
    driver:key(require("app.consts").BACKSTACK_KEY)
    driver:wait_screen("UserMenuScreen")
    steps.enter_game(driver)
    local gandalf = driver:find("Token", "Gandalf")
    driver:find("Token", "Bilbo Baggins")
    driver:expect(app.data.tokens.Gandalf ~= nil, "Gandalf in bob's data")
    local x, y = gandalf:get_position()
    return {x, y, require("utils.utils").get_time()}
]]

local BOB_DRAGS_BOTH = [[
    local tokens = steps.select_tokens(driver, {"Gandalf", "Bilbo Baggins"})
    local coordinates = app.session:get_game_screen():get_page():get_page_coordinates()
    local x, y = tokens[1]:transform_to_global(0, 0)
    local from_x, from_y = coordinates:transform_to_local(x, y)
    local to_x, to_y = coordinates:transform_to_local(x + %d, y + %d)
    local expected = {}
    for i, token in ipairs(tokens) do
        local start_x, start_y = token:get_position()
        expected[i] = {start_x + to_x - from_x, start_y + to_y - from_y}
    end
    steps.drag_token(driver, "Gandalf", %d, %d)
    local released = require("utils.utils").get_time()
    local moved = {}
    for i, token in ipairs(tokens) do
        local mx, my = token:get_position()
        driver:expect(math.abs(mx - expected[i][1]) < 1e-6 and math.abs(my - expected[i][2]) < 1e-6,
                      string.format("token %%d moved to (%%g, %%g), expected (%%g, %%g)", i, mx, my, expected[i][1], expected[i][2]))
        moved[i] = {mx, my}
    end
    return {gandalf = moved[1], bilbo = moved[2], released = released}
]]

local BOB_SEES_THE_DELETION = [[
    local page = app.session:get_game_screen():get_page()
    driver:wait_for(function()
        return not page:try_find_token("Gandalf")
    end, nil, "Gandalf gone on bob's client")
    local gone = require("utils.utils").get_time()
    driver:expect(not driver:try_find("Token", "Gandalf"), "no Gandalf control on bob's page")
    driver:expect(app.data.tokens.Gandalf == nil, "no Gandalf in bob's data")
    return gone
]]

local BOB_IS_REFUSED = [[
    app.session:create_token("Orc", {name = "Orc", diameter = 1, avatar = "token/smaug.png", position = {1, 1}})
    driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the creation's refusal")
    app.session:delete_token("Smaug")
    driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the deletion's refusal")
    driver:expect(app.data.tokens.Orc == nil and not driver:try_find("Token", "Orc"), "no Orc on bob's client")
]]

---@param a number
---@param b number
---@return boolean
local function _near(a, b)
    return math.abs(a - b) < TOLERANCE
end

---@param driver ScenarioDriver
---@return GameData
local function _read_save(driver)
    return assert(table.from_string("return " .. driver:server(SAVE))) --[[@as GameData]]
end

---@param driver ScenarioDriver
---@param position {[1]: number, [2]: number}|nil
---@param x number
---@param y number
---@param what string
local function _expect_position(driver, position, x, y, what)
    driver:expect(position and _near(position[1], x) and _near(position[2], y),
                  string.format("%s: %s, expected (%g, %g)", what, position and string.format("(%g, %g)", position[1], position[2]) or "none", x, y))
end

---@param list string[]
---@param value string
---@return boolean
local function _contains(list, value)
    return table.find_array_idx(list, value) ~= nil
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
        local page = game:get_page()

        local center_x, center_y = page:get_view_center()
        local requested = Utils.get_time()
        local gandalf = steps.create_token(driver, ID, NAME, AVATAR)
        local shown = Utils.get_time()
        local x, y = gandalf:get_position()
        _expect_position(driver, {
            x,
            y
        }, center_x, center_y, "Gandalf on adam's page, at the view's center")
        driver:log(string.format("Gandalf shown at (%g, %g) on the lead %.1f ms after the request", x, y, (shown - requested) * 1000))
        local data = assert(app.data)
        driver:expect(data.tokens.Gandalf and _contains(data.pages.Meadow.tokens, ID), "Gandalf in adam's data and on its page's list")

        driver:client("bob", BOB_DOES_NOT_SEE_IT):wait()

        local save = _read_save(driver)
        local saved = save.tokens.Gandalf
        driver:expect(saved, "Gandalf in the server's save")
        driver:expect(saved.name == NAME and saved.avatar == AVATAR and saved.diameter == 1 and saved.owners == nil,
                      string.format("Gandalf saved as created, without owners: %s", table.to_string(saved)))
        _expect_position(driver, saved.position, center_x, center_y, "Gandalf in the server's save")
        driver:expect(_contains(save.pages.Meadow.tokens, ID), "Gandalf on the saved page's list")

        driver:server(GRANT)
        local granted = Utils.get_time()
        local entered = assert(table.from_string("return " .. driver:client("bob", BOB_ENTERS_AGAIN):wait())) --[[@as number[] ]]
        _expect_position(driver, entered, x, y, "Gandalf on bob's page after entering again")
        driver:log(string.format("bob sees Gandalf at (%g, %g) after entering Meadow again, %.1f ms after the grant", entered[1], entered[2], (entered[3] - granted) * 1000))

        local dragged = assert(table.from_string("return " .. driver:client("bob", string.format(BOB_DRAGS_BOTH, DRAG_X, DRAG_Y, DRAG_X, DRAG_Y)):wait())) --[[@as {gandalf: number[], bilbo: number[], released: number}]]
        local gx, gy, bx, by = dragged.gandalf[1], dragged.gandalf[2], dragged.bilbo[1], dragged.bilbo[2]
        driver:wait_for(function()
            local ax, ay = page:find_token(ID):get_position()
            local cx, cy = page:find_token("Bilbo"):get_position()
            return _near(ax, gx) and _near(ay, gy) and _near(cx, bx) and _near(cy, by)
        end, nil, "both tokens moved on adam's client")
        local pushed = Utils.get_time()
        driver:log(string.format("bob dragged Gandalf to (%g, %g) and Bilbo to (%g, %g); adam saw both %.1f ms after the release", gx, gy, bx, by, (pushed - dragged.released) * 1000))
        save = _read_save(driver)
        _expect_position(driver, save.tokens.Gandalf.position, gx, gy, "Gandalf in the server's save after the drag")
        _expect_position(driver, save.tokens.Bilbo.position, bx, by, "Bilbo in the server's save after the drag")

        local watch = driver:client("bob", BOB_SEES_THE_DELETION)
        local deleting = Utils.get_time()
        steps.delete_token(driver, NAME)
        driver:expect(assert(app.data).tokens.Gandalf == nil, "no Gandalf in adam's data")
        local gone = assert(tonumber(watch:wait()))
        driver:log(string.format("bob lost Gandalf %.1f ms after the deletion's request", (gone - deleting) * 1000))
        save = _read_save(driver)
        driver:expect(save.tokens.Gandalf == nil and not _contains(save.pages.Meadow.tokens, ID), "no Gandalf in the server's save")
        local grants = save.players.piotr.permissions or {}
        for _, grant in ipairs(grants) do
            driver:expect(not string.find(grant, "tokens/Gandalf", 1, true), "piotr's saved grants name Gandalf no more: " .. table.concat(grants, ", "))
        end
        driver:expect(#grants == 1 and grants[1] == "write:tokens/@owned", "piotr keeps his other grant: " .. table.concat(grants, ", "))

        driver:client("bob", string.format(BOB_IS_REFUSED, CREATE_REFUSAL, DELETE_REFUSAL)):wait()
        save = _read_save(driver)
        driver:expect(save.tokens.Smaug and _contains(save.pages.Meadow.tokens, "Smaug"), "Smaug still in the server's save")
        driver:expect(save.tokens.Orc == nil, "no Orc in the server's save")
    end
}
