# CLAUDE.md - App Directory

Guidance for the application layer: the base `App` class and its two
specializations, `Client` and `Server`, plus the argument parser and the
constants.

## Bootstrap

1. The entry point starts the debugger when VS Code attached one (the
   debugger module, a no-op otherwise), loads the global utilities (the class
   system, the table utilities, `dump` in debug mode) and parses the command
   line:
   `love . <client|server> <address> <port>`
2. Client or Server is instantiated with the parsed parameters and assigns
   itself to the global `app`
3. The instance registers the LÖVE callbacks; `love.load` then calls the
   instance's `load`

The LÖVE configuration callback parses the same command line, so a server can
run without a window.

## The App base class

- **Time**: a start time taken at construction and a frame time updated every
  `love.update`, read with `app:get_time()`
- **Update**: every frame runs the defer manager, honours a pending quit,
  updates the time, triggers `update_event` (dt) and runs a collector step
- **Root control**: with a window, `app.root` is the top-level `Control` of
  all UI, scaled so that the model width (2000 units) fits the real window
  width; the model height follows from the aspect ratio. Headless, there is
  no root and no draw callback
- **Quit**: `app:quit()` marks the app; the next update calls
  `love.event.quit`, so a quit never happens mid-frame. `love.quit` removes
  every connection in order (each session's tree is torn down while LÖVE's
  threads and channels are still usable) and then tells lua-lifetime the
  program is ending
- **Debug mode** (LÖVE's `debug`): a key toggles the drawing of bounding
  boxes, the error handler prints a stack trace and pauses the debugger when
  one is attached, and `log_fun` includes the calling function's name
- **Logging**: `app:log(...)` and `app:log_fun(...)`

The class declares every manager field that may exist on either side; not
all exist on every instance (a headless server has no pointer manager).

## Client

Creates the UI managers: connection, resize, screen, pointer, button,
keyboard, text, notification, options, asset, backstack, file drop, and the
wheel event. `load` pushes the quit callback onto the backstack (the back key
quits), shows the connecting screen and starts connecting; a connection
creates the session (anchored to the connection), a disconnect shows the
connecting screen again and clears the session and the data.

The client wires every LÖVE input callback: a key press first goes to the
app (debug keys), then toggles fullscreen or is dispatched to the keyboard
manager and the text event manager; mouse and touch go to **both** the
pointer event manager (hit-tested controls) and the button event manager
(hover, press, click), so different systems handle the same input (button
clicks versus drag and drop); the wheel, file drops, text input and resizes
go to their managers.

## Server

Owns the save file, a map from connection to session, the connection manager
and the asset manager; with a window it shows a screen saver. `load` reads
the persisted state, then listens: a connection creates a session (anchored
to the connection), a disconnect removes the map entry.

Persistence is a human-readable Lua table: `save_data()` serializes `app.data`
into the save file; the server calls it when the game state changes. Sessions
are independent but share `app.data`.

## Argument parser

A module (not a class) with one `parse` function. It validates the app type
(`"server"` or `"client"`, typed as a literal union), the address
(`localhost` or an IPv4) and the port (1024 to 65535, kept as a string), and
returns a typed result table, or `nil` for invalid input, in which case the
usage message is shown.

## Constants

One module with every application-wide constant: colors, fonts, dimensions,
keybindings, mouse buttons, network settings, asset roots and logger
filters. Some are derived from others. The fonts are loaded only when the
window configuration exists: a headless server has no fonts, and so has
plain LuaJIT, where the tests fake them.

## Patterns

- Branch shared code on `app.is_client` / `app.is_server`
- Reach subsystems through the managers: `app.screen_manager:show(...)`,
  `app.asset_manager:download_asset(...)`, `app.backstack_manager:push(...)`
- A subclass extending the LÖVE callbacks calls the base registration first
  and then adds or wraps callbacks
