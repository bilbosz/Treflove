---@class HitTest
local hit_test = {}

local WEAK_KEYS = {
    __mode = "k"
}

---@alias ReceiveThroughSet table<Control, boolean> Controls that also receive events consumed above them (weak keys)

---@return ReceiveThroughSet
function hit_test.make_receive_through_set()
    return setmetatable({}, WEAK_KEYS)
end

---@param ctrl Control
---@param event Event
---@param x number
---@param y number
---@param list Control[] Output list of hit controls with a handler, in tree order
local function _collect_hit_controls(ctrl, event, x, y, list)
    if not ctrl:is_visible() or not ctrl:get_global_recursive_aabb():is_point_inside(x, y) then
        return
    end
    if event:get_handler(ctrl) then
        table.insert(list, ctrl)
    end
    for _, child in ipairs(ctrl:get_children()) do
        ---@cast child Control
        _collect_hit_controls(child, event, x, y, list)
    end
end

---@param event Event
---@param receive_through ReceiveThroughSet
---@param x number
---@param y number
---@param ... any Extra arguments forwarded after (x, y)
function hit_test.dispatch(event, receive_through, x, y, ...)
    ---@type Control[]
    local list = {}
    _collect_hit_controls(app.root, event, x, y, list)
    local top_to_be_called = true
    for _, ctrl in ripairs(list) do
        local handler = event:get_handler(ctrl)
        ---@cast handler PointerEventHandler|FileDroppedHandler|nil
        if handler then
            if top_to_be_called then
                local pass_through = handler(ctrl, x, y, ...)
                if not pass_through then
                    top_to_be_called = false
                end
            elseif receive_through[ctrl] then
                handler(ctrl, x, y, ...)
            end
        end
    end
end

return hit_test
