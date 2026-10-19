-- networking/connection-manager.tlt: every connection, indexed by its
-- channels. `remove` ends a connection with
-- `lifetime.destroy(connection)` (docs/lifetime.md, "Ownership").
global type ConnectionManagerOnConnect = function(connection: Connection)
global type ConnectionManagerOnDisconnect = function(connection: Connection)

global interface ConnectionManager is Object
    _connections: {Connection: boolean}
    _by_in_channel: {love.Channel: Connection}
    _by_out_channel: {love.Channel: Connection}
    _on_connect: ConnectionManagerOnConnect
    _on_disconnect: ConnectionManagerOnDisconnect
    _connector: Connector
    start: function(self, on_connect: ConnectionManagerOnConnect, on_disconnect: ConnectionManagerOnDisconnect)
    add_connection: function(self, in_channel: love.Channel, in_thread: love.Thread, out_channel: love.Channel, out_thread: love.Thread)
    remove_by_in_channel: function(self, in_channel: love.Channel)
    remove_by_out_channel: function(self, out_channel: love.Channel)
    remove: function(self, connection: Connection)
    get_connections: function(self): {Connection: boolean}
end
