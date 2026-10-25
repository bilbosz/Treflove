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

test.case("a view drag holds the pointer: it goes on beyond the page and ends on the release there", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local manager = client.app.pointer_event_manager
        local coordinates = page:get_page_coordinates()
        local px, py, pw = page:get_position_and_size()
        local x0, y0 = coordinates:transform_to_global(0, 0)

        manager:dispatch_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_VIEW_BUTTON)
        test.assert_eq(manager:get_captor(Consts.PAGE_DRAG_VIEW_BUTTON), page)
        manager:dispatch_pointer_move(px + pw + 300, py + 130, nil)
        local x1, y1 = coordinates:transform_to_global(0, 0)
        test.assert_near(x1 - x0, pw + 200)
        test.assert_near(y1 - y0, 30)

        manager:dispatch_pointer_up(px + pw + 300, py + 130, Consts.PAGE_DRAG_VIEW_BUTTON)
        test.assert_eq(manager:get_captor(Consts.PAGE_DRAG_VIEW_BUTTON), nil)
        manager:dispatch_pointer_move(px + 100, py + 100, nil)
        local x2, y2 = coordinates:transform_to_global(0, 0)
        test.assert_near(x2, x1)
        test.assert_near(y2, y1)
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("the view is centered on a token of the page, or on the page itself", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local coordinates = page:get_page_coordinates()
        local w, h = page:get_size()
        local cx, cy = page:transform_to_global(w * 0.5, h * 0.5)

        page:center_on_token("Smaug")
        local x, y = coordinates:transform_to_global(4, 2)
        test.assert_near(x, cx, 1e-2)
        test.assert_near(y, cy, 1e-2)

        page:center_on_page()
        x, y = coordinates:transform_to_global(5, 5)
        test.assert_near(x, cx, 1e-2)
        test.assert_near(y, cy, 1e-2)

        test.assert_error(function()
            page:center_on_token("Gollum")
        end, "a token on no page")
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)
