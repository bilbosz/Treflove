OptionsManager = {}

function OptionsManager:Init()

end

function OptionsManager:ToggleFullscreen()
    love.window.setFullscreen(not love.window.getFullscreen())
end

MakeClassOf(OptionsManager)
