-- Lists the shown screen's clickable controls (every Input: buttons, fields, rows) with their class, caption and
-- window position, top to bottom: luajit tools/console.lua <client console> < .claude/skills/headless-smoke/scripts/list-inputs.lua
local Input = require("ui.input")
local Utils = require("utils.utils")
local found = {}
local function visit(ctrl)
    if not ctrl:is_visible() then
        return
    end
    if is_instance_of(ctrl, Input) then
        local x, y, w, h = ctrl:get_global_aabb():get_position_and_size()
        table.insert(found, {
            class = get_class_name_of(ctrl),
            caption = Utils.get_caption(ctrl),
            enabled = ctrl:is_enabled() and ctrl:are_all_predecessors_enabled(),
            x = x, y = y, w = w, h = h
        })
    end
    for _, child in ipairs(ctrl:get_children()) do
        visit(child)
    end
end
visit(app.root)
table.sort(found, function(a, b)
    if a.y ~= b.y then
        return a.y < b.y
    end
    return a.x < b.x
end)
local lines = {string.format("%s: %d inputs", get_class_name_of(app.screen_manager:get_screen()), #found)}
for i, it in ipairs(found) do
    table.insert(lines, string.format("%2d %-16s %-24s %s at %d,%d size %dx%d", i, it.class, it.caption and string.format("%q", it.caption) or "", it.enabled and "enabled" or "disabled", it.x, it.y, it.w, it.h))
end
return table.concat(lines, "\n")
