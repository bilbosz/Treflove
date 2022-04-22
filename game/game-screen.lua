GameScreen = {}

local function ListRequiredAssets(self)
    local list = {}
    if self.data.screen == "World" then
        local world = app.data.worlds[self.data.params.name]
        table.insert(list, world.image)
        for _, v in ipairs(world.tokens) do
            table.insert(list, app.data.tokens[v].avatar)
        end
    end
    return list
end

local function DownloadAssets(self, cb)
    local list = ListRequiredAssets(self)
    app.assetManager:DownloadMissingAssets(list, cb)
end

function GameScreen:Init()
    Screen.Init(self)
end

function GameScreen:Show()
    Screen.Show(self)
    if self.data.screen == "World" then
        DownloadAssets(self, function()
            World(self.data.params, self.screen, app.width, app.height)
        end)
    end
end

MakeModelOf(GameScreen, Screen)
