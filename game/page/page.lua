local Image = require("controls.image")
local Control = require("controls.control")
local Model = require("data.model")
local ClippingRectangle = require("controls.clipping-rectangle")
local PointerEventListener = require("events.pointer-event").Listener
local WheelEventListener = require("events.wheel-event").Listener
local Selection = require("game.page.selection")
local Token = require("game.token.token")
local Consts = require("app.consts")

---@class Page: Model, ClippingRectangle, PointerEventListener, WheelEventListener
local Page = class("Page", Model, ClippingRectangle, PointerEventListener, WheelEventListener)

function Page:_create_background(path)
    local bg = Image(self, path)
    self.background = bg
    local bg_w, bg_h = bg:get_size()

    local w, h = self:get_size()

    bg:set_scale(self.pixelPerMeter * self.page_width / bg_w)
    bg:set_origin(bg_w * 0.5, bg_h * 0.5)
    bg:set_position(w * 0.5, h * 0.5)
end

function Page:_create_page_coordinates()
    local bg = self.background
    local bg_w = bg:get_size()
    self.page_coordinates = Control(bg)
    self.page_coordinates:set_scale(bg_w / self.page_width)
end

function Page:init(data, game_screen, width, height)

    Model.init(self, data)
    ClippingRectangle.init(self, game_screen:get_control(), width, height)
    PointerEventListener.init(self, true)
    self.name = data.name
    self.pixelPerMeter = data.pixel_per_meter
    self.page_width = data.width
    self.pointerDownPos = {}
    self.game_screen = game_screen

    self:_create_background(data.image)
    self:_create_page_coordinates()
    self.selection = Selection(self)

    self.tokens = {}
    for _, name in ipairs(data.tokens) do
        table.insert(self.tokens, Token(app.data.tokens[name], self.page_coordinates))
    end

    app.pointer_event_manager:register_listener(self)
    app.wheel_event_manager:register_listener(self)
end

function Page:get_page_coordinates()
    return self.page_coordinates
end

function Page:get_tokens()
    return self.tokens
end

function Page:on_pointer_down(x, y, button)
    local tx, ty = self:transform_to_local(x, y)
    if tx < 0 or tx >= self.size[1] or ty < 0 or ty >= self.size[2] then
        return
    end
    if button == Consts.PAGE_SELECT_BUTTON and not self.pointerDownPos[Consts.PAGE_DRAG_TOKEN_BUTTON] then
        local wx, wy = self.page_coordinates:transform_to_local(x, y)
        self.selection:set_start_point(wx, wy)
        self.pointerDownPos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.PAGE_DRAG_VIEW_BUTTON then
        self.pointerDownPos[button] = {
            tx,
            ty
        }
    end
    if button == Consts.PAGE_DRAG_TOKEN_BUTTON and not self.pointerDownPos[Consts.PAGE_SELECT_BUTTON] then
        self.pointerDownPos[button] = {
            self.page_coordinates:transform_to_local(x, y)
        }
        self.selectSetStartPos = {}
        local set = self.selection:get_select_set()
        for token in pairs(set) do
            self.selectSetStartPos[token] = {
                token:get_position()
            }
        end
    end
end

function Page:on_pointer_up(x, y, button)
    if self.pointerDownPos[Consts.PAGE_SELECT_BUTTON] and button == Consts.PAGE_SELECT_BUTTON then
        local wx, wy = self.page_coordinates:transform_to_local(x, y)
        local selection = self.selection
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
    self.pointerDownPos[button] = nil
end

function Page:on_pointer_move(x, y)
    if self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON] then
        local px, py = unpack(self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON])
        local tx, ty = self:transform_to_local(x, y)
        local bg = self.background
        local bg_x, bg_y = bg:get_position()
        bg:set_position(bg_x + tx - px, bg_y + ty - py)
        self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON][1], self.pointerDownPos[Consts.PAGE_DRAG_VIEW_BUTTON][2] = tx, ty
    end
    if self.pointerDownPos[Consts.PAGE_SELECT_BUTTON] then
        local wx, wy = self.page_coordinates:transform_to_local(x, y)
        self.selection:set_end_point(wx, wy)
    end
    if self.pointerDownPos[Consts.PAGE_DRAG_TOKEN_BUTTON] then
        local sx, sy = unpack(self.pointerDownPos[Consts.PAGE_DRAG_TOKEN_BUTTON])
        local wx, wy = self.page_coordinates:transform_to_local(x, y)
        local ox, oy = wx - sx, wy - sy
        local set = self.selection:get_select_set()
        for token in pairs(set) do
            local startPosX, startPosY = unpack(self.selectSetStartPos[token])
            token:set_position(startPosX + ox, startPosY + oy)
        end
    end
end

function Page:on_wheel_moved(x, y)
    local realMouseX, realMouseY = love.mouse.get_position()
    local selfMouseX, selfMouseY = self:transform_to_local(realMouseX, realMouseY)
    if selfMouseX >= 0 and selfMouseX < self.size[1] and selfMouseY >= 0 and selfMouseY < self.size[2] then
        local bg = self.background
        local bgMouseX, bgMouseY = bg:transform_to_local(realMouseX, realMouseY)

        local zoom_inc = math.pow(Consts.PAGE_ZOOM_INCREASE, y)

        bg:set_origin(bgMouseX, bgMouseY)
        bg:set_position(selfMouseX, selfMouseY)

        local scale = bg:get_scale() * zoom_inc
        bg:set_scale(scale)
    end
end

function Page:get_game_screen()
    return self.game_screen
end

function Page:get_selection()
    return self.selection
end

return Page
