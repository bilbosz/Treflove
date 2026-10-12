-- networking/connector.tlt: starts the thread that accepts (server) or
-- opens (client) connections and hands each new one, or each closed one,
-- to the ConnectionManager. The thread scripts (networking/detail/*.tlt)
-- have no fragments: nothing requires them; they are started from build/.

-- What a connection thread (networking/detail/*) pushes on the connector's
-- channel: "a" a new connection, "i"/"o" its input/output side closed.
global enum ConnectorAction
    "a"
    "i"
    "o"
end

-- {"a", in_channel, in_thread, out_channel, out_thread}, or {"i",
-- in_channel}, or {"o", out_channel}.
global type ConnectorMessage = {ConnectorAction, love.Channel, love.Thread, love.Channel, love.Thread}

global interface Connector is Object
    _address: string
    _port: string
    _channel: love.Channel -- messages from the connection thread
    _retry_time: number -- seconds between connection attempts
    _thread: love.Thread
    _connection_manager: ConnectionManager
    _last_start: number -- the time of the last connection thread start
    start: function(self, connection_manager: ConnectionManager)
    _try_restart_connection: function(self)
    _handle_connections: function(self)
    remove_thread: function(self)
    on_update: function(self) -- registered on app.update_event
end
