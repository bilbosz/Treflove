---@class Profiler The Tracy bindings: zones, frame marks and plots over the
---C API of a Tracy client shared library, loaded through LuaJIT's FFI. Every
---function is a no-op until `start` has loaded the library, so the
---instrumentation stays in the code and costs one call per zone when the
---profiler is off. The functions are looked up on this table at each call,
---never captured as locals, so that `start` can swap them.
local profiler = {}

---The environment variable naming the Tracy client shared library
profiler.ENV_VAR = "TREFLOVE_TRACY"

---@type boolean True once `start` has loaded the library
profiler.enabled = false

---@alias ProfilerZone ffi.cdata*|nil The context of an open zone, nil when the profiler is off

---@class TracySourceLocation: ffi.cdata* A `___tracy_source_location_data`, the static description of a zone
---@field name ffi.cdata* The zone name, a C string
---@field file ffi.cdata* A C string
---@field line number
---@field color number 0 for the default

---The C API of Tracy 0.9 to 0.14 (public/tracy/TracyC.h). The zone context
---is the layout of a client built without TRACY_ON_DEMAND.
local CDEF = [[
typedef struct ___tracy_source_location_data {
    const char* name;
    const char* function;
    const char* file;
    uint32_t line;
    uint32_t color;
} ___tracy_source_location_data;
typedef struct ___tracy_c_zone_context {
    uint32_t id;
    int32_t active;
} ___tracy_c_zone_context;
___tracy_c_zone_context ___tracy_emit_zone_begin(const ___tracy_source_location_data* srcloc, int32_t active);
void ___tracy_emit_zone_end(___tracy_c_zone_context ctx);
void ___tracy_emit_zone_text(___tracy_c_zone_context ctx, const char* txt, size_t size);
void ___tracy_emit_zone_value(___tracy_c_zone_context ctx, uint64_t value);
void ___tracy_emit_frame_mark(const char* name);
void ___tracy_emit_plot(const char* name, double val);
int32_t ___tracy_connected(void);
void ___tracy_set_thread_name(const char* name);
]]

local cdef_declared = false

---@type ffi.namespace*|nil The loaded client. The functions bound from it do
---not keep it alive, and a collected namespace unloads its library, so it is
---held here for the program's life.
local library = nil

---@param name string
---@return ProfilerZone
function profiler.zone_begin(name)
    return nil
end

---A zone named after the class of `obj`
---@param obj table A class instance
---@return ProfilerZone
function profiler.zone_begin_of(obj)
    return nil
end

---@param zone ProfilerZone
function profiler.zone_end(zone)
end

---@param zone ProfilerZone
---@param text string
function profiler.zone_text(zone, text)
end

---@param zone ProfilerZone
---@param value number A non-negative integer
function profiler.zone_value(zone, value)
end

---The end of a frame
function profiler.frame_mark()
end

---@param name string
---@param value number
function profiler.plot(name, value)
end

---@return boolean True while the Tracy profiler is connected
function profiler.is_connected()
    return false
end

---Puts a zone named `name` around `t[key]`, in place; nothing when the
---profiler is off. An error raised inside leaves the zone open, and so the
---wrapped function is one whose errors end the program.
---@param t table A module or a class
---@param key string The name of the function
---@param name string The zone name
function profiler.wrap(t, key, name)
end

---@param ffi ffilib
---@param lib ffi.namespace*
local function _install(ffi, lib)
    local C_zone_begin = lib.___tracy_emit_zone_begin
    local C_zone_end = lib.___tracy_emit_zone_end
    local C_zone_text = lib.___tracy_emit_zone_text
    local C_zone_value = lib.___tracy_emit_zone_value
    local C_frame_mark = lib.___tracy_emit_frame_mark
    local C_plot = lib.___tracy_emit_plot
    local C_connected = lib.___tracy_connected

    ---@param s string
    ---@return ffi.cdata* A NUL-terminated copy, alive as long as it is held
    local function c_string(s)
        return ffi.new("char[?]", #s + 1, s)
    end

    ---@type table<string, {location: TracySourceLocation, name: ffi.cdata*, file: ffi.cdata*}> The source locations by zone name; a zone's strings must outlive every zone emitted with them
    local locations = {}
    ---@type table<string, ffi.cdata*> The names of the plots, as C strings
    local plot_names = {}

    ---@param name string
    ---@return TracySourceLocation
    local function location_of(name)
        local entry = locations[name]
        if not entry then
            local info = debug.getinfo(3, "Sl")
            local file = info and info.short_src or "?"
            local line = info and info.currentline or 0
            local c_name, c_file = c_string(name), c_string(file)
            local location = ffi.new("___tracy_source_location_data") ---@cast location TracySourceLocation
            location.name = c_name
            location["function"] = c_name
            location.file = c_file
            location.line = line > 0 and line or 0
            location.color = 0
            entry = {
                location = location,
                name = c_name,
                file = c_file
            }
            locations[name] = entry
        end
        return entry.location
    end

    ---@param zone ffi.cdata*
    ---@param ... any The results of the wrapped function
    ---@return any ...
    local function finish(zone, ...)
        C_zone_end(zone)
        return ...
    end

    ---@type Profiler The bindings that replace the no-ops
    local bindings = {}

    ---@param name string
    ---@return ffi.cdata*
    function bindings.zone_begin(name)
        return C_zone_begin(location_of(name), 1)
    end

    ---@param obj table
    ---@return ffi.cdata*
    function bindings.zone_begin_of(obj)
        return C_zone_begin(location_of(get_class_name_of(obj)), 1)
    end

    ---@param zone ffi.cdata*
    function bindings.zone_end(zone)
        C_zone_end(zone)
    end

    ---@param zone ffi.cdata*
    ---@param text string
    function bindings.zone_text(zone, text)
        C_zone_text(zone, text, #text)
    end

    ---@param zone ffi.cdata*
    ---@param value number
    function bindings.zone_value(zone, value)
        C_zone_value(zone, value)
    end

    function bindings.frame_mark()
        C_frame_mark(nil)
    end

    ---@param name string
    ---@param value number
    function bindings.plot(name, value)
        local c_name = plot_names[name]
        if not c_name then
            c_name = c_string(name)
            plot_names[name] = c_name
        end
        C_plot(c_name, value)
    end

    ---@return boolean
    function bindings.is_connected()
        return C_connected() ~= 0
    end

    ---@param t table
    ---@param key string
    ---@param name string
    function bindings.wrap(t, key, name)
        local fn = t[key]
        assert_type(fn, "function")
        local location = location_of(name)
        t[key] = function(...)
            return finish(C_zone_begin(location, 1), fn(...))
        end
    end

    lib.___tracy_set_thread_name("main")
    for key, binding in pairs(bindings) do
        profiler[key] = binding
    end
    profiler.enabled = true
end

---Puts zones around the entry points of the lua-lifetime runtime. The
---runtime reports where an object died and raises its errors at its caller;
---through a wrapper both point at the wrapper.
local function _instrument_lifetime()
    local lifetime = require("lifetime")
    profiler.wrap(lifetime, "attach", "lifetime.attach")
    profiler.wrap(lifetime, "destroy", "lifetime.destroy")
    profiler.wrap(lifetime, "discard", "lifetime.discard")
    profiler.wrap(lifetime, "hook", "lifetime.hook")
    profiler.wrap(lifetime, "named_hook", "lifetime.named_hook")
    profiler.wrap(lifetime, "block", "lifetime.block")
    profiler.wrap(lifetime, "token", "lifetime.token")
end

---Loads the Tracy client and turns the no-ops into bindings. Without a path
---the environment variable `ENV_VAR` is read; unset, the profiler stays
---off. Loading twice is a no-op.
---@param path string|nil The Tracy client shared library (libTracyClient.so, TracyClient.dll, libTracyClient.dylib)
---@return boolean enabled
---@return string|nil reason Why the profiler stays off
function profiler.start(path)
    if library then
        return true, nil
    end
    path = path or os.getenv(profiler.ENV_VAR)
    if not path or path == "" then
        return false, profiler.ENV_VAR .. " is not set"
    end
    local has_ffi, ffi = pcall(require, "ffi")
    if not has_ffi then
        return false, "LuaJIT's FFI is not available"
    end
    if not cdef_declared then
        ffi.cdef(CDEF)
        cdef_declared = true
    end
    local loaded, lib = pcall(ffi.load, path)
    if not loaded then
        return false, tostring(lib)
    end
    local bound, err = pcall(_install, ffi, lib)
    if not bound then
        return false, "not a Tracy client with the expected C API: " .. tostring(err)
    end
    library = lib
    _instrument_lifetime()
    return true, nil
end

return profiler
