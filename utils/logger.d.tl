-- utils/logger.tlt
global interface Logger is Model
    _is_enabled: boolean
    _name: string
    _separator: string
    _start_time: number
    -- any: the values formatted by `format` (string.format accepts any).
    _log_implementation: function(self, format: string, level: integer, ...: any)
    set_name: function(self, name: string)
    log: function(self, text: string)
    log_format: function(self, format: string, ...: any) -- any: see above
    log_up: function(self, format: string, up: integer, ...: any) -- any: see above
end
