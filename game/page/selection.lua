local Rectangle = require("controls.rectangle")
local UpdateEventListener = require("events.update-event").Listener
local Aabb = require("utils.aabb")
local Consts = require("app.consts")

---@class Selection: Rectangle, UpdateEventListener
local Selection = class("Selection", Rectangle, UpdateEventListener)

local function UpdateRectangle(self)
    local aabb = Aabb()
    aabb:add_point(unpack(self.start_point))
    aabb:add_point(unpack(self.end_point))
    self:set_position(aabb:get_position())
    self:set_size(aabb:get_size())
end

function Selection:init(page)
    -- assert_type(page, Page)
    self.page = page
    Rectangle.init(self, self.page:get_page_coordinates(), 0, 0, Consts.PAGE_SELECTION_COLOR)
    self:set_enabled(false)
    self.start_point = {
        0,
        0
    }
    self.end_point = {
        0,
        0
    }
    self.select_set = {}
    app.update_event_manager:register_listener(self)
end

function Selection:show()
    self:set_enabled(true)
end

function Selection:hide()
    self:set_enabled(false)
end

function Selection:set_start_point(x, y)
    assert(not self:is_enabled())
    self:show()
    self.start_point[1], self.start_point[2] = x, y
    self.end_point[1], self.end_point[2] = x, y
    UpdateRectangle(self)
end

function Selection:set_end_point(x, y)
    assert(self:is_enabled())
    self.end_point[1], self.end_point[2] = x, y
    UpdateRectangle(self)
end

function Selection:apply()
    self.select_set = {}
    local aabb = self:get_aabb()
    for _, token in ipairs(self.page:get_tokens()) do
        local x, y = token:get_position()
        local r = token:get_radius()
        local intersects = aabb:is_intersecting_circle(x, y, r)
        self.select_set[token] = intersects or nil
        token:set_select(intersects)
    end
    self:on_selection_change()
end

function Selection:add_apply()
    local aabb = self:get_aabb()
    for _, token in ipairs(self.page:get_tokens()) do
        local x, y = token:get_position()
        local r = token:get_radius()
        local intersects = aabb:is_intersecting_circle(x, y, r)
        if intersects then
            self.select_set[token] = true
            token:set_select(true)
        end
    end
    self:on_selection_change()
end

function Selection:toggle_apply()
    local aabb = self:get_aabb()
    for _, token in ipairs(self.page:get_tokens()) do
        local x, y = token:get_position()
        local r = token:get_radius()
        local intersects = aabb:is_intersecting_circle(x, y, r)
        if intersects then
            local new_select = not token:get_select()
            self.select_set[token] = new_select or nil
            token:set_select(new_select)
        end
    end
    self:on_selection_change()
end

function Selection:Unselect()
    for _, token in ipairs(self.page:get_tokens()) do
        self.select_set[token] = nil
        token:set_select(false)
    end
    self:on_selection_change()
end

function Selection:get_select_set()
    return self.select_set
end

function Selection:on_selection_change()
    self.page:get_game_screen():on_selection_change()
end

function Selection:on_update()
    self:reattach()
end

return Selection
