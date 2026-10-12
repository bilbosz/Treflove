-- utils/dump.tlt: the debug dumper, set only in debug mode (app/globals.tlt).
-- any: dumps values of any type and returns what the configured text
-- processor returns (by default `print`, nothing).
global dump: function(...: any): any
