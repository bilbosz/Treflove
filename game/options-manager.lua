---@class OptionsManager
local OptionsManager = class("OptionsManager")

function OptionsManager:toggle_fullscreen()
    app.resize_manager:toggle_fullscreen()
end

return OptionsManager
