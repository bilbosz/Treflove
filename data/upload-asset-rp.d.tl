-- data/upload-asset-rp.tlt: the client sends an asset to the
-- server.
global record UploadAssetRequest is RequestBody
    path: string
    content: string -- base64
end

global record UploadAssetResponse is ResponseBody
    success: boolean
end

global interface UploadAssetRp is RemoteProcedure
    send_request: function(self, request: UploadAssetRequest, cb?: function(response: UploadAssetResponse))
    send_response: function(self, request: UploadAssetRequest): UploadAssetResponse
    receive_response: function(self, response: UploadAssetResponse)
end
