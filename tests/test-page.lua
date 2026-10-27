local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local lifetime = require("lifetime")
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

---@param client GameClient
---@return table<string, number[]> The positions of the `UpdateTokenRp` requests the client sent, by token id
local function sent_moves(client)
    ---@type table<string, number[]>
    local moves = {}
    while client.connection:get_out_channel():getCount() > 0 do
        local request = game_client.pop_request(client, "UpdateTokenRp") --[[@as UpdateTokenRequest]]
        test.assert_eq(moves[request.id], nil, "one request per token")
        ---@type string[]
        local keys = {}
        for key in pairs(request.changes) do
            table.insert(keys, key)
        end
        test.assert_deep_eq(keys, {
            "position"
        }, "the position alone")
        moves[request.id] = request.changes.position --[[@as number[] ]]
    end
    return moves
end

---@param client GameClient
---@param moves table<string, number[]> As `sent_moves` gives them
---@param ids string[] The tokens expected moved
local function assert_moves(client, moves, ids)
    ---@type string[]
    local moved = {}
    for id in pairs(moves) do
        table.insert(moved, id)
    end
    table.sort(moved)
    test.assert_deep_eq(moved, ids)
    for _, id in ipairs(ids) do
        local x, y = game_client.find_token(client, id):get_position()
        test.assert_near(moves[id][1], x, 1e-9, id)
        test.assert_near(moves[id][2], y, 1e-9, id)
    end
end

test.case("a drag sends one update per token it moved, with the id and the position; an unwritable token sends none", function()
    local client = game_client.enter({
        "read",
        "write:tokens/@owned"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local px, py = page:get_position()
        page:on_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        page:on_pointer_move(px + 160, py + 130)
        test.assert_deep_eq(sent_moves(client), {}, "nothing before the release")
        page:on_pointer_up(px + 160, py + 130, Consts.PAGE_DRAG_TOKEN_BUTTON)
        assert_moves(client, sent_moves(client), {
            "Bilbosza"
        })
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("a master's drag sends an update for every selected token; a drag that ends where it began sends none", function()
    local client = game_client.enter({
        "read",
        "write"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local px, py = page:get_position()
        page:on_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        page:on_pointer_move(px + 160, py + 100)
        page:on_pointer_up(px + 160, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        assert_moves(client, sent_moves(client), {
            "Bilbosza",
            "Smaug"
        })
        page:on_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        page:on_pointer_move(px + 200, py + 140)
        page:on_pointer_move(px + 100, py + 100)
        page:on_pointer_up(px + 100, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
        test.assert_deep_eq(sent_moves(client), {}, "back where it began")
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

---@param page Page
---@return number, number, number, number The page's rectangle in the view's coordinates, for a square page as the test data's
local function map_rect(page)
    local coordinates = page:get_page_coordinates()
    local width = page:get_data().width
    local x0, y0 = page:transform_to_local(coordinates:transform_to_global(0, 0))
    local x1, y1 = page:transform_to_local(coordinates:transform_to_global(width, width))
    return x0, y0, x1, y1
end

---@param page Page
---@return number
local function units_per_meter(page)
    local x0, _, x1 = map_rect(page)
    return (x1 - x0) / page:get_data().width
end

---@param page Page
---@return number, number The view's units per page meter at the zoom-out and the zoom-in limit, for a square page
local function zoom_limits(page)
    local view_w, view_h = page:get_size()
    local min_units = math.min(view_w - 2 * Consts.PADDING, view_h - 2 * Consts.PADDING) / page:get_data().width
    return min_units, math.max(Consts.PAGE_MAX_UNITS_PER_METER, min_units)
end

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
    local min_units, max_units = zoom_limits(page)
    local fit = math.min((view_w - 2 * Consts.PADDING) / w, (view_h - 2 * Consts.PADDING) / h)
    local scale = math.min(math.max(fit, min_units), max_units)
    test.assert_near(x1 - x0, w * scale, 1e-2, "scaled to fit, within the limits")
    test.assert_near(y1 - y0, h * scale, 1e-2)
end

---@param page Page
local function assert_pan_limit(page)
    local view_w, view_h = page:get_size()
    local x0, y0, x1, y1 = map_rect(page)
    local visible_x = math.min(Consts.PAGE_MIN_VISIBLE, x1 - x0, view_w)
    local visible_y = math.min(Consts.PAGE_MIN_VISIBLE, y1 - y0, view_h)
    test.assert_true(x1 >= visible_x - 1e-3 and x0 <= view_w - visible_x + 1e-3, "the least of the map in view across")
    test.assert_true(y1 >= visible_y - 1e-3 and y0 <= view_h - visible_y + 1e-3, "and down")
end

---@param client GameClient
---@param x number In the page's own coordinates
---@param y number
local function point_at(client, x, y)
    client.app:set_pointer_position(client.game_screen:get_page():transform_to_global(x, y))
end

---@param client GameClient
---@param steps number Positive zooms in
local function wheel(client, steps)
    local page = client.game_screen:get_page()
    for _ = 1, math.abs(steps) do
        page:on_wheel_moved(0, steps > 0 and 1 or -1)
    end
end

test.case("on entry the view is the page fitted, within the limits", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        assert_fitted(client, 0, 0, 10, 10)
        assert_pan_limit(client.game_screen:get_page())
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

        manager:dispatch_pointer_down(px + pw - 100, py + 100, Consts.PAGE_DRAG_VIEW_BUTTON)
        test.assert_eq(manager:get_captor(Consts.PAGE_DRAG_VIEW_BUTTON), page)
        manager:dispatch_pointer_move(px + pw + 300, py + 130, nil)
        local x1, y1 = coordinates:transform_to_global(0, 0)
        test.assert_near(x1 - x0, 400)
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

test.case("a view drag stops with the least of the map in view, at every edge", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local manager = client.app.pointer_event_manager
        local px, py, pw, ph = page:get_position_and_size()
        local view_w, view_h = page:get_size()
        local visible = Consts.PAGE_MIN_VISIBLE

        manager:dispatch_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_VIEW_BUTTON)
        manager:dispatch_pointer_move(px + pw + 5000, py + 100, nil)
        local x0, _, x1 = map_rect(page)
        test.assert_near(x0, view_w - visible, 1e-3, "dragged far right")
        local width = x1 - x0

        manager:dispatch_pointer_move(px - 5000, py + 100, nil)
        x0, _, x1 = map_rect(page)
        test.assert_near(x1, visible, 1e-3, "dragged far left")
        test.assert_near(x1 - x0, width, 1e-3, "the scale kept")

        manager:dispatch_pointer_move(px - 5000, py + ph + 5000, nil)
        local _, y0 = map_rect(page)
        test.assert_near(y0, view_h - visible, 1e-3, "dragged far down")

        manager:dispatch_pointer_move(px - 5000, py - 5000, nil)
        local _, _, x, y1 = map_rect(page)
        test.assert_near(y1, visible, 1e-3, "dragged far up")
        test.assert_near(x, visible, 1e-3, "a square at the corner")

        manager:dispatch_pointer_move(px - 4990, py - 4980, nil)
        local _, _, x2, y2 = map_rect(page)
        test.assert_near(x2, visible + 10, 1e-3, "the map follows the pointer back at once")
        test.assert_near(y2, visible + 20, 1e-3)
        manager:dispatch_pointer_up(px - 4990, py - 4980, Consts.PAGE_DRAG_VIEW_BUTTON)
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("the wheel zooms about the pointer, out to the page fitted and in to the meter's limit", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local coordinates = page:get_page_coordinates()
        local manager = client.app.pointer_event_manager
        local view_w, view_h = page:get_size()
        local min_units, max_units = zoom_limits(page)

        point_at(client, view_w * 0.5, view_h * 0.5)
        wheel(client, 3)
        test.assert_true(units_per_meter(page) > min_units, "zoomed in")
        wheel(client, -50)
        test.assert_near(units_per_meter(page), min_units, 1e-3, "out no further than the page fitted")
        local fitted = {
            map_rect(page)
        }
        page:fit_page()
        local refitted = {
            map_rect(page)
        }
        for i = 1, 4 do
            test.assert_near(refitted[i], fitted[i], 1e-3, "fitting changes nothing")
        end

        point_at(client, 300, 400)
        local mx, my = coordinates:transform_to_local(manager:get_position())
        wheel(client, 1)
        test.assert_near(units_per_meter(page), min_units * Consts.PAGE_ZOOM_INCREASE, 1e-3, "one step in")
        local nx, ny = coordinates:transform_to_local(manager:get_position())
        test.assert_near(nx, mx, 1e-3, "the point under the pointer stays")
        test.assert_near(ny, my, 1e-3)

        wheel(client, 1)
        test.assert_near(units_per_meter(page), max_units, 1e-3, "the step past the limit stops at it")
        nx, ny = coordinates:transform_to_local(manager:get_position())
        test.assert_near(nx, mx, 1e-3, "about the pointer still")
        test.assert_near(ny, my, 1e-3)

        wheel(client, 50)
        test.assert_near(units_per_meter(page), Consts.PAGE_MAX_UNITS_PER_METER, 1e-3, "in no further than the limit")
        assert_pan_limit(page)
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("a change of size keeps the view within the limits, and a fitted page fitted", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local manager = client.app.pointer_event_manager
        local view_w, view_h = page:get_size()
        point_at(client, view_w * 0.5, view_h * 0.5)
        wheel(client, 1)
        local zoomed = units_per_meter(page)

        page:set_size(2000, 1900)
        local min_units = zoom_limits(page)
        test.assert_true(min_units > zoomed, "a larger view raises the zoom-out limit")
        test.assert_near(units_per_meter(page), min_units, 1e-3, "the scale raised to it")
        assert_pan_limit(page)

        wheel(client, 1)
        zoomed = units_per_meter(page)
        local px, py = page:get_position()
        manager:dispatch_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_VIEW_BUTTON)
        manager:dispatch_pointer_move(px + 5000, py + 5000, nil)
        manager:dispatch_pointer_up(px + 5000, py + 5000, Consts.PAGE_DRAG_VIEW_BUTTON)
        page:set_size(800, 600)
        test.assert_near(units_per_meter(page), zoomed, 1e-3, "a smaller view keeps the scale")
        local x0, y0 = map_rect(page)
        test.assert_near(x0, 800 - Consts.PAGE_MIN_VISIBLE, 1e-3, "the map pulled into the smaller view")
        test.assert_near(y0, 600 - Consts.PAGE_MIN_VISIBLE, 1e-3)

        page:fit_page()
        page:set_size(1000, 700)
        assert_fitted(client, 0, 0, 10, 10)
        page:set_size(1800, 1600)
        assert_fitted(client, 0, 0, 10, 10)
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("the page draws its surroundings under the map, sized to the view", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local page = client.game_screen:get_page()
        local children = page:get_children()
        ---@diagnostic disable-next-line: invisible
        local surroundings = page._surroundings
        test.assert_eq(children[1], surroundings)
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(children[2], page._background)
        test.assert_deep_eq({
            surroundings:get_size()
        }, {
            page:get_size()
        })
        page:draw()
        page:set_size(1000, 700)
        test.assert_deep_eq({
            surroundings:get_size()
        }, {
            1000,
            700
        })
        page:draw()
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)

test.case("the view is fitted to a token of the page, no closer than the zoom-in limit, or to the page itself, within a padding", function()
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

test.case("a token's avatar follows its data, fitted to the token", function()
    local client = game_client.enter({
        "read"
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        local token = game_client.find_token(client, "Bilbosza")
        local old = token._image
        token:set_data("avatar", "token/s.png")
        test.assert_false(lifetime.alive(old))
        local image = token._image
        test.assert_true(image ~= old)
        test.assert_eq(image:get_parent(), token._clip)
        local w, h = image:get_size()
        local d = token:get_data().diameter
        test.assert_near((image:get_scale()), math.max(d / w, d / h))
        test.assert_deep_eq({
            image:get_position()
        }, {
            d * 0.5,
            d * 0.5
        })
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end)
