-- data/download-missing-assets-rp.lua (still Lua): the client asks the
-- server for the content of every asset it lacks.
global record DownloadMissingAssetsRequest is RequestBody
    list: {string} -- asset paths
end

global record DownloadMissingAssetsResponse is ResponseBody
    success: boolean
    contents: {string: string} -- path -> base64 content
end

global interface DownloadMissingAssetsRp is RemoteProcedure
    send_request: function(self, request: DownloadMissingAssetsRequest, cb?: function(response: DownloadMissingAssetsResponse))
    send_response: function(self, request: DownloadMissingAssetsRequest): DownloadMissingAssetsResponse
    receive_response: function(self, response: DownloadMissingAssetsResponse)
end
