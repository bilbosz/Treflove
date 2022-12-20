GameDataRp = {}

local function ListRequiredAssets()
    local list = {}
    local data = app.data
    local page = data.pages[data.game.page]
    table.insert(list, page.image)
    for _, v in ipairs(page.tokens) do
        table.insert(list, data.tokens[v].avatar)
    end
    return list
end

function GameDataRp:Init(connection)
    RemoteProcedure.Init(self, connection)
end

function GameDataRp:SendResponse()
    return {
        data = app.data
    }
end

function GameDataRp:ReceiveResponse(response)
    app.data = response.data
    app.screenManager:Show(WaitingScreen("Synchronizing Assets..."))
    local list = ListRequiredAssets()
    app.assetManager:DownloadMissingAssets(list, function()
        app.screenManager:Show(GameScreen(app.data.game))
    end)
end

MakeClassOf(GameDataRp, RemoteProcedure)
