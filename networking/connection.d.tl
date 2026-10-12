-- networking/connection.tlt: a pair of channels and threads to the other
-- side, with request/response dispatch. A connection is a root of the
-- ownership tree: ConnectionManager:remove destroys it and what is anchored
-- to it dies in the cascade (docs/lifetime.md, "Networking").

-- The body of a request: each remote procedure declares its own record
-- `is RequestBody` (DownloadAssetRequest, LoginRequest, ...).
global interface RequestBody
end

-- The body of a response: each remote procedure declares its own record
-- `is ResponseBody`.
global interface ResponseBody
end

-- A request as it travels: `source` is "c" (client) or "s" (server), the
-- side that sent it; `id` the remote procedure's class name.
global record Request
    source: string
    id: string
    body: RequestBody
end

-- A response as it travels: `source` and `id` of the request it answers.
global record Response
    source: string
    id: string
    body: ResponseBody
end

-- Processes the body of a received response.
global type ConnectionResponseHandler = function(body: ResponseBody)
-- Handles a request body and returns the response body.
global type ConnectionRequestHandler = function(body: RequestBody): ResponseBody

global interface Connection is Object
    _queue: {ConnectionResponseHandler} -- awaiting responses, in request order
    _in_channel: love.Channel
    _in_thread: love.Thread
    _out_channel: love.Channel
    _out_thread: love.Thread
    _source: string -- "c" or "s"
    _requests_handlers: {string: ConnectionRequestHandler}
    send_request: function(self, id: string, body: RequestBody, response_handler: ConnectionResponseHandler)
    register_request_handler: function(self, id: string, request_handler: ConnectionRequestHandler)
    unregister_request_handler: function(self, id: string)
    get_in_channel: function(self): love.Channel
    get_out_channel: function(self): love.Channel
    on_update: function(self) -- registered on app.update_event
    _handle_response: function(self, message: Response)
    _send_response: function(self, request: Request)
    -- release (Object): unregisters from app.update_event and releases the
    -- threads and channels, which are not anchored (docs/lifetime.md,
    -- "Networking").
end
