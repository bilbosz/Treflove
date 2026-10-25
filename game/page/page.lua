local Image = require("controls.image")
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
---@field tokens string[] Names of the tokens placed on the page

---@class Page: Model, ClippingRectangle
---@field data PageData
---@field get_data fun(self: Page): PageData
---@field private _background Image
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
    local bg = Image(self, path)
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
    for _, name in ipairs(data.tokens) do
        table.insert(self._tokens, Token(name, app.data.tokens[name], self._page_coordinates))
    end

    local pointer_event_manager = app.pointer_event_manager
    pointer_event_manager.pointer_down:register(self, self.on_pointer_down)
    pointer_event_manager.pointer_up:register(self, self.on_pointer_up)
    pointer_event_manager.pointer_move:register(self, self.on_pointer_move)
    pointer_event_manager:set_receive_through(self, true)
    app.wheel_event:register(self, self.on_wheel_moved)
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
    self._pointer_down_pos[button] = nil
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
    if not self._game_screen:is_showed() then -- under another screen
        return
    end
    local real_mouse_x, real_mouse_y = app.pointer_event_manager:get_position()
    local self_mouse_x, self_mouse_y = self:transform_to_local(real_mouse_x, real_mouse_y)
    if self_mouse_x >= 0 and self_mouse_x < self.size[1] and self_mouse_y >= 0 and self_mouse_y < self.size[2] then
        local bg = self._background
        local bg_mouse_x, bg_mouse_y = bg:transform_to_local(real_mouse_x, real_mouse_y)

        local zoom_inc = math.pow(Consts.PAGE_ZOOM_INCREASE, y)

        bg:set_origin(bg_mouse_x, bg_mouse_y)
        bg:set_position(self_mouse_x, self_mouse_y)

        local scale = bg:get_scale() * zoom_inc
        bg:set_scale(scale)
    end
end

---The view moved so that the point, in page meters, is at the middle of
---the page's box, at the current zoom
---@param x number
---@param y number
function Page:center_on(x, y)
    local bg = self._background
    local gx, gy = self._page_coordinates:transform_to_global(x, y)
    bg:set_origin(bg:transform_to_local(gx, gy))
    local w, h = self:get_size()
    bg:set_position(w * 0.5, h * 0.5)
end

---The view scaled and moved so that the rectangle, in page meters, fills
---the page's box within a padding, as the preview fits an image
---@param x number
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

---@param key string A token placed on the page
---@return Token
function Page:find_token(key)
    for _, token in ipairs(self._tokens) do
        if token:get_key() == key then
            return token
        end
    end
    error(string.format("no token %q on the page", key))
end

---@param key string A token placed on the page
function Page:fit_token(key)
    local token = self:find_token(key)
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
