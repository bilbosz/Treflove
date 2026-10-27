local Image = require("controls.image")
local PageSurroundings = require("game.page.page-surroundings")
local Control = require("controls.control")
local Model = require("data.model")
local ClippingRectangle = require("controls.clipping-rectangle")
local Selection = require("game.page.selection")
local Token = require("game.token.token")
local Consts = require("app.consts")

---@class PageData
---@field name string
---@field pixel_per_meter number
---@field width number Page width in meters
---@field image string Path of the background image asset
---@field tokens string[] Ids of the tokens placed on the page

---@class Page: Model, ClippingRectangle
---@field data PageData
---@field get_data fun(self: Page): PageData
---@field private _background Image
---@field private _surroundings PageSurroundings
---@field private _page_coordinates Control Coordinate system scaled to page meters
---@field private _name string
---@field private _pixel_per_meter number
---@field private _page_width number
---@field private _pointer_down_pos table<PointerId, [number, number]> Local pointer-down positions per button
---@field private _game_screen GameScreen
---@field private _selection Selection
---@field private _tokens Token[]
---@field private _select_set_start_pos table<Token, [number, number]>|nil While dragging: the start positions of the selected tokens the player may write, the ones the drag moves
local Page = class("Page", Model, ClippingRectangle)

---@private
---@param path string
function Page:_create_background(path)
    local bg = Image(nil, path)
    self._surroundings = PageSurroundings(self, bg, self._page_width)
    self:add_child(bg)
    self._background = bg
    local bg_w, bg_h = bg:get_size()

    local w, h = self:get_size()

    bg:set_scale(self._pixel_per_meter * self._page_width / bg_w)
    bg:set_origin(bg_w * 0.5, bg_h * 0.5)
    bg:set_position(w * 0.5, h * 0.5)
end

---@private
function Page:_create_page_coordinates()
    local bg = self._background
    local bg_w = bg:get_size()
    self._page_coordinates = Control(bg)
    self._page_coordinates:set_scale(bg_w / self._page_width)
end

---@param data PageData
---@param game_screen GameScreen
---@param width number
---@param height number
function Page:init(data, game_screen, width, height)

    Model.init(self, data)
    ClippingRectangle.init(self, game_screen:get_control(), width, height)
    self._name = data.name
    self._pixel_per_meter = data.pixel_per_meter
    self._page_width = data.width
    self._pointer_down_pos = {}
    self._game_screen = game_screen

    self:_create_background(data.image)
    self:_create_page_coordinates()
    self._selection = Selection(self)

    self._tokens = {}
    for _, id in ipairs(data.tokens) do
        table.insert(self._tokens, Token(id, app.data.tokens[id], self._page_coordinates))
    end

    local pointer_event_manager = app.pointer_event_manager
    pointer_event_manager.pointer_down:register(self, self.on_pointer_down)
    pointer_event_manager.pointer_up:register(self, self.on_pointer_up)
    pointer_event_manager.pointer_move:register(self, self.on_pointer_move)
    pointer_event_manager:set_receive_through(self, true)
    app.wheel_event:register(self, self.on_wheel_moved)
    self:_constrain_view()
end

---@private
---@return number, number The least and the greatest scale of the map, in units per texel: the page fitted to the view, and a page meter spanning `Consts.PAGE_MAX_UNITS_PER_METER`
function Page:_get_scale_limits()
    local bg_w, bg_h = self._background:get_size()
    local view_w, view_h = self:get_size()
    local min_scale = math.min((view_w - 2 * Consts.PADDING) / bg_w, (view_h - 2 * Consts.PADDING) / bg_h)
    local max_scale = math.max(Consts.PAGE_MAX_UNITS_PER_METER * self._page_width / bg_w, min_scale)
    return min_scale, max_scale
end

---@private
---@param scale number
---@return number
function Page:_clamp_scale(scale)
    local min_scale, max_scale = self:_get_scale_limits()
    return math.min(math.max(scale, min_scale), max_scale)
end

---@param from number The map's near edge on one axis, in view units
---@param to number Its far edge
---@param extent number The view's extent on that axis
---@return number The least shift that keeps `Consts.PAGE_MIN_VISIBLE` of the map in view
local function _get_pan_shift(from, to, extent)
    local min_visible = math.min(Consts.PAGE_MIN_VISIBLE, to - from, extent)
    if to < min_visible then
        return min_visible - to
    elseif from > extent - min_visible then
        return extent - min_visible - from
    end
    return 0
end

---@private
function Page:_constrain_view()
    local bg = self._background
    local view_w, view_h = self:get_size()
    local scale = bg:get_scale()
    local clamped = self:_clamp_scale(scale)
    if clamped ~= scale then
        bg:set_origin(bg:transform_to_local(self:transform_to_global(view_w * 0.5, view_h * 0.5)))
        bg:set_position(view_w * 0.5, view_h * 0.5)
        bg:set_scale(clamped)
    end

    local bg_w, bg_h = bg:get_size()
    local origin_x, origin_y = bg:get_origin()
    local x, y = bg:get_position()
    local x0, y0 = x - origin_x * clamped, y - origin_y * clamped
    local dx = _get_pan_shift(x0, x0 + bg_w * clamped, view_w)
    local dy = _get_pan_shift(y0, y0 + bg_h * clamped, view_h)
    if dx ~= 0 or dy ~= 0 then
        bg:set_position(x + dx, y + dy)
    end
end

---@private
---@return boolean
function Page:_is_zoomed_out()
    local min_scale = self:_get_scale_limits()
    return self._background:get_scale() <= min_scale * (1 + 1e-9)
end

---@param width number
---@param height number
function Page:set_size(width, height)
    local old_w, old_h = self:get_size()
    local fitted = self:_is_zoomed_out()
    ClippingRectangle.set_size(self, width, height)
    self._surroundings:set_size(width, height)
    if fitted and (width ~= old_w or height ~= old_h) then
        self:fit_page()
    else
        self:_constrain_view()
    end
end

---@return Control
function Page:get_page_coordinates()
    return self._page_coordinates
end

---@return Token[]
function Page:get_tokens()
    return self._tokens
end

---@param x number
---@param y number
---@param button number|lightuserdata Mouse button or touch id (never nil for down events)
function Page:on_pointer_down(x, y, button)
    local tx, ty = self:transform_to_local(x, y)
    if button == Consts.PAGE_SELECT_BUTTON and not self._pointer_down_pos[Consts.PAGE_DRAG_TOKEN_BUTTON] then
        local wx, wy = self._page_coordinates:transform_to_local(x, y)
        self._selection:set_start_point(wx, wy)
        self._pointer_down_pos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.PAGE_DRAG_VIEW_BUTTON then
        self._pointer_down_pos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.PAGE_DRAG_TOKEN_BUTTON and not self._pointer_down_pos[Consts.PAGE_SELECT_BUTTON] then
        self._pointer_down_pos[button] = {
            self._page_coordinates:transform_to_local(x, y)
        }
        self._select_set_start_pos = {}
        local set = self._selection:get_select_set()
        for token in pairs(set) do
            if token:is_writable() then
                self._select_set_start_pos[token] = {
                    token:get_position()
                }
            end
        end
    end
    if self._pointer_down_pos[button] then
        app.pointer_event_manager:capture(self, button)
    end
end

---@param x number
---@param y number
---@param button number|lightuserdata Mouse button or touch id (never nil for up events)
function Page:on_pointer_up(x, y, button)
    if self._pointer_down_pos[Consts.PAGE_SELECT_BUTTON] and button == Consts.PAGE_SELECT_BUTTON then
        local wx, wy = self._page_coordinates:transform_to_local(x, y)
        local selection = self._selection
        selection:set_end_point(wx, wy)

        local shift = app.keyboard_manager:is_key_down("lshift")
        local ctrl = app.keyboard_manager:is_key_down("lctrl")
        if shift then
            selection:add_apply()
        elseif ctrl then
            selection:toggle_apply()
        else
            selection:apply()
        end
        selection:hide()
    end
    if self._pointer_down_pos[Consts.PAGE_DRAG_TOKEN_BUTTON] and button == Consts.PAGE_DRAG_TOKEN_BUTTON then
        self:_send_moves()
    end
    self._pointer_down_pos[button] = nil
end

---@private
function Page:_send_moves()
    local session = assert(app.session)
    for token, start_pos in pairs(assert(self._select_set_start_pos)) do
        local x, y = token:get_position()
        if x ~= start_pos[1] or y ~= start_pos[2] then
            session:update_token(token:get_id(), {
                position = {
                    x,
                    y
                }
            })
        end
    end
    self._select_set_start_pos = nil
end

---@param x number
---@param y number
function Page:on_pointer_move(x, y)
    if self._pointer_down_pos[Consts.PAGE_DRAG_VIEW_BUTTON] then
        local px, py = unpack(self._pointer_down_pos[Consts.PAGE_DRAG_VIEW_BUTTON])
        local tx, ty = self:transform_to_local(x, y)
        local bg = self._background
        local bg_x, bg_y = bg:get_position()
        bg:set_position(bg_x + tx - px, bg_y + ty - py)
        self._pointer_down_pos[Consts.PAGE_DRAG_VIEW_BUTTON][1], self._pointer_down_pos[Consts.PAGE_DRAG_VIEW_BUTTON][2] = tx, ty
        self:_constrain_view()
    end
    if self._pointer_down_pos[Consts.PAGE_SELECT_BUTTON] then
        local wx, wy = self._page_coordinates:transform_to_local(x, y)
        self._selection:set_end_point(wx, wy)
    end
    if self._pointer_down_pos[Consts.PAGE_DRAG_TOKEN_BUTTON] then
        local sx, sy = unpack(self._pointer_down_pos[Consts.PAGE_DRAG_TOKEN_BUTTON])
        local wx, wy = self._page_coordinates:transform_to_local(x, y)
        local ox, oy = wx - sx, wy - sy
        for token, start_pos in pairs(assert(self._select_set_start_pos)) do
            local start_pos_x, start_pos_y = unpack(start_pos)
            token:set_position(start_pos_x + ox, start_pos_y + oy)
        end
    end
end

---@param x number Horizontal wheel movement
---@param y number Vertical wheel movement
function Page:on_wheel_moved(x, y)
    if not self._game_screen:is_showed() then
        return
    end
    local real_mouse_x, real_mouse_y = app.pointer_event_manager:get_position()
    local self_mouse_x, self_mouse_y = self:transform_to_local(real_mouse_x, real_mouse_y)
    if self_mouse_x >= 0 and self_mouse_x < self.size[1] and self_mouse_y >= 0 and self_mouse_y < self.size[2] then
        local bg = self._background
        local bg_mouse_x, bg_mouse_y = bg:transform_to_local(real_mouse_x, real_mouse_y)

        local scale = self:_clamp_scale(bg:get_scale() * math.pow(Consts.PAGE_ZOOM_INCREASE, y))

        bg:set_origin(bg_mouse_x, bg_mouse_y)
        bg:set_position(self_mouse_x, self_mouse_y)
        bg:set_scale(scale)
        self:_constrain_view()
    end
end

---@param x number In page meters
---@param y number
function Page:center_on(x, y)
    local bg = self._background
    local gx, gy = self._page_coordinates:transform_to_global(x, y)
    bg:set_origin(bg:transform_to_local(gx, gy))
    local w, h = self:get_size()
    bg:set_position(w * 0.5, h * 0.5)
    self:_constrain_view()
end

---@param x number The rectangle, in page meters
---@param y number
---@param w number
---@param h number
function Page:fit(x, y, w, h)
    local bg = self._background
    local bg_w = bg:get_size()
    local view_w, view_h = self:get_size()
    local meters_to_view = math.min((view_w - 2 * Consts.PADDING) / w, (view_h - 2 * Consts.PADDING) / h)
    bg:set_scale(meters_to_view * self._page_width / bg_w)
    self:center_on(x + w * 0.5, y + h * 0.5)
end

function Page:fit_page()
    local bg_w, bg_h = self._background:get_size()
    local page_w = self._page_width
    self:fit(0, 0, page_w, bg_h / bg_w * page_w)
end

---@param id string A token placed on the page
---@return Token
function Page:find_token(id)
    local token = self:try_find_token(id)
    if not token then
        error(string.format("no token %q on the page", id))
    end
    return token
end

---@param id string
---@return Token|nil The token placed on the page under `id`, `nil` when there is none
function Page:try_find_token(id)
    for _, token in ipairs(self._tokens) do
        if token:get_id() == id then
            return token
        end
    end
    return nil
end

---@param id string A token placed on the page
function Page:fit_token(id)
    local token = self:find_token(id)
    local x, y = token:get_position()
    local r = token:get_radius()
    self:fit(x - r, y - r, 2 * r, 2 * r)
end

---@return GameScreen
function Page:get_game_screen()
    return self._game_screen
end

---@return Selection
function Page:get_selection()
    return self._selection
end

return Page
