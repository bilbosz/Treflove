function IsIdentifier( str )
    local l = #str
    local b, e = string.find( str, "[%a_][%w_]*" )
    return b == 1 and e == l
end