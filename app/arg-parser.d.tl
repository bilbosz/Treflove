-- app/arg-parser.tlt
global enum AppType
    "server"
    "client"
end

global record ArgParserResult
    app_type: AppType
    address: string
    port: string -- port number as a string (range: 1024-65535)
end

-- Example usage: `love . server 0.0.0.0 8080` or `love . client 192.0.0.1 8080`
global record ArgParser
    parse: function(args: {string}): ArgParserResult
end
