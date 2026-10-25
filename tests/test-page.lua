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

---@param client GameClient
---@param x number The rectangle, in page meters
---@param y number
---@param w number
---@param h number
local function assert_fitted(client, x, y, w, h)
    local page = client.game_screen:get_page()
    local view_w, view_h = page:get_size()
    local cx, cy = page:transform_to_global(view_w * 0.5, view_h * 0.5)
    local coordinates = page:get_page_coordinates()
    local gx, gy = coordinates:transform_to_global(x + w * 0.5, y + h * 0.5)
    test.assert_near(gx, cx, 1e-2, "centered")
    test.assert_near(gy, cy, 1e-2)
    local x0, y0 = coordinates:transform_to_global(x, y)
    local x1, y1 = coordinates:transform_to_global(x + w, y + h)
    local scale = math.min((view_w - 2 * Consts.PADDING) / w, (view_h - 2 * Consts.PADDING) / h)
    test.assert_near(x1 - x0, w * scale, 1e-2, "scaled to fit")
    test.assert_near(y1 - y0, h * scale, 1e-2)
end

test.case("the view is fitted to a token of the page, or to the page itself, within a padding", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        page:fit_token("Smaug")
        assert_fitted(client, 3.5, 1.5, 1, 1)
        page:fit_page()
        assert_fitted(client, 0, 0, 10, 10)
        test.assert_error(function()
            page:fit_token("Gollum")
        end, "a token on no page")
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)
