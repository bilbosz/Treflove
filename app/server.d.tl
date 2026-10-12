-- app/server.tlt: the server application: a session per
-- connection, the game state persisted to save.lua.
global interface Server is App
    _save_file: Asset
    -- Each session is anchored to its connection
    -- (`Session(connection) @ connection`), which the disconnect destroys.
    _sessions: {Connection: Session}
    _load_data: function(self)
    save_data: function(self)
end
