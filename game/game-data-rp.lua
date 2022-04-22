GameDataRp = {}

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
    app.screenManager:Show(GameScreen(app.data.game))
end

MakeClassOf(GameDataRp, RemoteProcedure)
