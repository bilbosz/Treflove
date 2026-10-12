-- game/game-data-rp.lua (still Lua): the client asks for the game state,
-- then downloads the assets of the current page and shows the game.

-- The persisted game state: server/save.lua, app.data on both sides.
global record GameState
    game: GameScreenData
    pages: {string: PageData} -- by page name
    token_properties: {string: TokenPropertyDef} -- by token data key
    tokens: {string: TokenData} -- by token name
    players: {string: PlayerData} -- by login
end

global record GameDataResponse is ResponseBody
    data: GameState -- the full game state served by the server
end

global interface GameDataRp is RemoteProcedure
    send_request: function(self, request: EmptyBody, cb?: function(response: GameDataResponse))
    send_response: function(self, request: EmptyBody): GameDataResponse
    receive_response: function(self, response: GameDataResponse)
end
