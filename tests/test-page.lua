local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")

---@param token Token
---@return number[]
local function position(token)
    return {
        token:get_position()
    }
end

test.suite("Page")

test.case("a drag over a mixed selection moves only the tokens the player may write; the selection stays", function()
    local client = game_client.enter({
        "read",
        "write:tokens/@owned"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local owned, other = game_client.find_token(client, "Bilbosza"), game_client.find_token(client, "Smaug")
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local owned_start, other_start = position(owned), position(other)

        local px, py = page:get_position()
        local x0, y0, x1, y1 = px + 100, py + 100, px + 160, py + 130
        local coordinates = page:get_page_coordinates()
        local wx0, wy0 = coordinates:transform_to_local(x0, y0)
        local wx1, wy1 = coordinates:transform_to_local(x1, y1)
        page:on_pointer_down(x0, y0, Consts.PAGE_DRAG_TOKEN_BUTTON)
        page:on_pointer_move(x1, y1)
        page:on_pointer_up(x1, y1, Consts.PAGE_DRAG_TOKEN_BUTTON)

        local moved = position(owned)
        test.assert_near(moved[1], owned_start[1] + wx1 - wx0, 1e-9)
        test.assert_near(moved[2], owned_start[2] + wy1 - wy0, 1e-9)
        test.assert_true(moved[1] ~= owned_start[1], "the owned token moved")
        test.assert_deep_eq(position(other), other_start, "the other token stayed")
        test.assert_deep_eq(client.app.data.tokens.Smaug.position, other_start, "and so did its data")
        test.assert_true(page:get_selection():get_select_set()[owned])
        test.assert_true(page:get_selection():get_select_set()[other])
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("the game master drags the whole selection", function()
    local client = game_client.enter({
        "read",
        "write"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local a, b = game_client.find_token(client, "Bilbosza"), game_client.find_token(client, "Smaug")
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local a_start, b_start = position(a), position(b)
        local px, py = page:get_position()
        page:on_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        page:on_pointer_move(px + 160, py + 100)
        page:on_pointer_up(px + 160, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        test.assert_true(position(a)[1] > a_start[1])
        test.assert_near(position(a)[1] - a_start[1], position(b)[1] - b_start[1], 1e-9)
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)
