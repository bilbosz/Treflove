-- networking/remote-procedure.tlt: the base of every remote
-- procedure; the class name is its id on the connection. Each subclass
-- redeclares `send_request`, `send_response` and `receive_response` with
-- its own body records (a narrower parameter type is accepted for a
-- redeclared field).

-- Called with the response body after `receive_response`.
global type RemoteProcedureCb = function(response: ResponseBody)

-- The body of a request or a response that carries nothing.
global record EmptyBody is RequestBody, ResponseBody
end

global interface RemoteProcedure is Object
    _id: string -- the class name
    _connection: Connection
    start: function(self)
    stop: function(self)
    send_request: function(self, request: RequestBody, cb?: RemoteProcedureCb)
    -- Abstract: the handler on the receiving side; returns the response.
    send_response: function(self, request: RequestBody): ResponseBody
    -- Abstract: processes the response on the requesting side.
    receive_response: function(self, response: ResponseBody)
    -- release (Object): `self:stop()` only, so a second release is
    -- harmless; a procedure is anchored to its owner (`LoginRp(...) @
    -- self`, the asset procedures `@ session`).
end
