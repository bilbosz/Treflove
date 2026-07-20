local Rectangle = require("controls.rectangle")
local UpdateEventListener = require("events.update-event").Listener
local Aabb = require("utils.aabb")
local Consts = require("app.consts")

---@class Selection: Rectangle, UpdateEventListener
---@field _page Page
---@field _start_point number[]
---@field _end_point number[]
---@field _select_set table<Token, boolean> Currently selected tokens
local Selection = class("Selection", Rectangle, UpdateEventListener)

---@param self Selection
local function _update_rectangle(self)
    local aabb = Aabb()
    aabb:add_point(unpack(self._start_point))
    aabb:add_point(unpack(self._end_point))
    self:set_position(aabb:get_position())
    self:set_size(aabb:get_size())
end

---@param page Page
function Selection:init(page)
    -- assert_type(page, Page)
    self._page = page
    Rectangle.init(self, self._page:get_page_coordinates(), 0, 0, Consts.PAGE_SELECTION_COLOR)
    self:set_enabled(false)
    self._start_point = {
        0,
        0
    }
    self._end_point = {
        0,
        0
    }
    self._select_set = {}
    app.update_event_manager:register_listener(self)
end

function Selection:show()
    self:set_enabled(true)
end

function Selection:hide()
    self:set_enabled(false)
end

---@param x number
---@param y number
function Selection:set_start_point(x, y)
    assert(not self:is_enabled())
    self:show()
    self._start_point[1], self._start_point[2] = x, y
    self._end_point[1], self._end_point[2] = x, y
    _update_rectangle(self)
end

---@param x number
---@param y number
function Selection:set_end_point(x, y)
    assert(self:is_enabled())
    self._end_point[1], self._end_point[2] = x, y
    _update_rectangle(self)
end

function Selection:apply()
    self._select_set = {}
    local aabb = self:get_aabb()
    for _, token in ipairs(self._page:get_tokens()) do
        local x, y = token:get_position()
        local r = token:get_radius()
        local intersects = aabb:is_intersecting_circle(x, y, r)
        self._select_set[token] = intersects or nil
        token:set_select(intersects)
    end
    self:on_selection_change()
end

function Selection:add_apply()
    local aabb = self:get_aabb()
    for _, token in ipairs(self._page:get_tokens()) do
        local x, y = token:get_position()
        local r = token:get_radius()
        local intersects = aabb:is_intersecting_circle(x, y, r)
        if intersects then
            self._select_set[token] = true
            token:set_select(true)
        end
    end
    self:on_selection_change()
end

function Selection:toggle_apply()
    local aabb = self:get_aabb()
    for _, token in ipairs(self._page:get_tokens()) do
        local x, y = token:get_position()
        local r = token:get_radius()
        local intersects = aabb:is_intersecting_circle(x, y, r)
        if intersects then
            local new_select = not token:get_select()
            self._select_set[token] = new_select or nil
            token:set_select(new_select)
        end
    end
    self:on_selection_change()
end

function Selection:unselect()
    for _, token in ipairs(self._page:get_tokens()) do
        self._select_set[token] = nil
        token:set_select(false)
    end
    self:on_selection_change()
end

---@return table<Token, boolean>
function Selection:get_select_set()
    return self._select_set
end

function Selection:on_selection_change()
    self._page:get_game_screen():on_selection_change()
end

function Selection:on_update()
    self:reattach()
end

return Selection
