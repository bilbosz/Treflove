# Profiling (Tracy)

The profiler module binds the C API of the [Tracy
profiler](https://github.com/wolfpld/tracy) through LuaJIT's FFI. The
instrumentation stays in the code: a zone is a pair of calls on the module,
no-ops until the Tracy client library is loaded at startup, so a run without
the profiler pays one empty call per zone. The library is loaded only when
the environment variable `TREFLOVE_TRACY` names it; the same binary serves
both.

## Setup

Tracy has two halves of one version: the client, a shared library the
profiled program loads, and the GUI (`tracy-profiler`), which connects to it
and shows the capture. The protocol changes between versions, so both must
be the same.

1. Build the client library (needs `git`, `cmake` and a C++ compiler):
   ```bash
   ./build-tracy.sh
   ```
   It clones Tracy at the pinned version into `lib/tracy` (ignored by git)
   and builds `lib/tracy/build/libTracyClient.so` (`TracyClient.dll`,
   `libTracyClient.dylib`). The binding declares the zone context of a
   client built without `TRACY_ON_DEMAND`; leave it off.
2. Get the GUI of the same version: the Windows binaries are on Tracy's
   releases page; elsewhere, build `lib/tracy/profiler` with CMake as the
   Tracy manual describes (it needs the GLFW or Wayland, FreeType and
   Capstone development packages).

## Running

```bash
./profile.sh              # the client under the profiler, the server plain
./profile.sh server       # the other way round
```

By hand, any side:
```bash
TREFLOVE_TRACY=/path/to/libTracyClient.so love . client localhost 8080
```

Then connect the GUI to `localhost`. The client listens from the start and
records until the GUI connects, so a capture may begin at the first frame.
With no GUI the program runs as usual, only slower by the instrumentation.
When the variable is set but the library cannot be loaded, the program says
so once on stderr and runs unprofiled.

## What is instrumented

- **Frames**: a frame mark at every `love.update`
- **The update** (zone `update`): the defer manager, the update event, the
  collector step, each a zone; a plot `Lua heap (KB)` after the step
- **The draw** (zone `draw`): every visible control drawn by the control
  tree gets a zone named after its class (`Panel`, `Text`, `Image`, ...),
  nested as the tree is, so the time of a screen reads as a tree
- **Input callbacks**: `pointer move: hit test` (the pointer event
  manager), `pointer move: buttons` (the button event manager), `pointer
  down`, `pointer up`, `key pressed`, `text input`, `resize`
- **Fonts**: `new font`, a rasterization at a new pixel size
- **lua-lifetime**: the entry points of the runtime are wrapped when the
  profiler starts: `lifetime.attach`, `lifetime.destroy` (one zone holds
  the whole cascade), `lifetime.discard`, `lifetime.hook`,
  `lifetime.named_hook`, `lifetime.block`, `lifetime.token`. Deaths the
  collector finds run inside the `collector step` zone.

## Adding a zone

```lua
local profiler = require("utils.profiler")

local zone = profiler.zone_begin("asset download")
...
profiler.zone_end(zone)
```

- `profiler.zone_begin(name)` / `profiler.zone_end(zone)`: a zone; names
  are static strings, one source location is allocated per name on first
  use. `profiler.zone_begin_of(obj)` names the zone after the class of a
  class instance.
- `profiler.zone_text(zone, text)` and `profiler.zone_value(zone, n)`
  attach a detail to the open zone.
- `profiler.plot(name, value)` plots a number over time;
  `profiler.frame_mark()` ends a frame; `profiler.is_connected()` tells
  whether the GUI is attached.
- `profiler.wrap(t, key, name)` puts a zone around a module or class
  function in place, as the lifetime entry points are; nothing happens when
  the profiler is off.

Call the functions through the module table, never captured into locals at
load time: `start` replaces the no-ops on the table.

## Caveats

- A zone must end on every path: an error raised inside leaves it open, and
  Tracy's zone validation then ends the capture. Put zones where an error
  ends the program anyway (a frame callback, a wrapped runtime call), not
  around a `pcall` that is expected to fail.
- The wrapped runtime functions sit one stack frame deeper: the location
  lua-lifetime records for a death, and the level it raises its errors at,
  point at the wrapper while the profiler is on.
- A zone context is a struct returned by value; LuaJIT boxes it in a cdata,
  one small allocation per zone, so a profiled run collects a little more
  than an unprofiled one.
- Only the main Lua state is instrumented; the networking threads are
  separate states and get no zones.
- The binding is in `utils/profiler.lua`: the C declarations are those of
  Tracy 0.9 to 0.14; a client built with `TRACY_ON_DEMAND` has a different
  zone context layout and will not work with it.
