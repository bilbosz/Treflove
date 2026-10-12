-- data/download-asset-rp.tlt: the client asks the server for
-- one asset's content.
global record DownloadAssetRequest is RequestBody
    path: string
end

global record DownloadAssetResponse is ResponseBody
    path: string
    content: string -- base64
end

global interface DownloadAssetRp is RemoteProcedure
    send_request: function(self, request: DownloadAssetRequest, cb?: function(response: DownloadAssetResponse))
    send_response: function(self, request: DownloadAssetRequest): DownloadAssetResponse
    receive_response: function(self, response: DownloadAssetResponse)
end
