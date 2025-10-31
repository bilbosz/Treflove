# CLAUDE.md - App Directory

This file provides guidance to Claude Code (claude.ai/code) when working with the app layer of Treflove.

## Overview

The `app/` directory contains the application layer that bootstraps and manages the entire Treflove application. It defines the base App class and its two specializations: Client and Server.

## File Structure

- **[globals.lua](globals.lua)**: Loads global utilities (table, utils, class, dump in debug mode)
- **[arg-parser.lua](arg-parser.lua)**: Parses command-line arguments
- **[consts.lua](consts.lua)**: Application-wide constants (colors, fonts, dimensions, keybindings)
- **[app.lua](app.lua)**: Base App class with common functionality
- **[client.lua](client.lua)**: Client application with full UI and event managers
- **[server.lua](server.lua)**: Server application managing connections and persistence

## Bootstrap Flow

1. [main.lua](../main.lua) requires [globals.lua](globals.lua) first (sets up global utilities)
2. ArgParser parses command-line arguments: `love . <client|server> <address> <port>`
3. Based on `app_type`, either Client or Server is instantiated with parsed params
4. The instance assigns itself to global `app` variable
5. LÖVE callbacks are registered via `register_love_callbacks()`
6. LÖVE calls `love.load()` which triggers `App:load()`

## App Base Class

[app.lua](app.lua) defines the abstract App class that both Client and Server inherit from.

### Key Responsibilities

**Initialization**:
- Sets global `app` reference to self
- Initializes time tracking (`_start_time`, `_time`)
- Creates Logger instance
- Stores parsed arguments
- Creates UpdateEventManager and DeferManager
- Calls `register_love_callbacks()` to wire up LÖVE

**LÖVE Callback Registration**:
- `love.load()` → calls `self:load()` (implemented by Client/Server)
- `love.draw()` → renders `self.root` control hierarchy (if window enabled)
- `love.update(dt)` → updates defer manager, checks for quit, updates time, invokes update events, runs GC step
- `love.errorhandler()` → prints error and stack trace in debug mode, silent otherwise
- `love.keypressed()` → handles F2 (toggle AABB drawing), F4 (quit)

**Root Control Management**:
- `self.root` is the top-level Control that contains all UI
- `rescale_root()` computes scale to fit MODEL_WIDTH (2000) to actual window width
- Real height is computed dynamically: `height = real_height / scale`
- Only created if `config.window` is enabled (headless server has no root)

**Time Management**:
- `_start_time` set at construction using `Utils.get_time()`
- `_time` updated every frame: `get_time() - _start_time`
- Accessible via `App:get_time()`

**Quit Handling**:
- `App:quit()` sets `_mark_for_quit = true`
- Checked in `love.update()` and triggers `love.event.quit()` next frame
- Deferred quit prevents issues with quitting mid-frame

**Logging**:
- `App:log(...)` - general logging
- `App:log_fun(...)` - includes function name in debug mode

**Debug Features** (only when `debug` is true):
- F2 key toggles AABB visualization via `_draw_aabbs` flag
- Error handler prints full stack trace
- `log_fun` includes calling function name

### Fields (see @field annotations)

The App class declares all manager fields that may exist in Client or Server:
- Event managers: pointer, keyboard, wheel, button, text, resize, file-drop, update
- Core managers: connection, screen, asset, backstack, notification, options
- Session and data
- Dimensions: width, height
- Root control
- Flags: is_client, is_server

Not all fields exist on all instances (e.g., Server doesn't have pointer_event_manager unless it has a window).

## Client Class

[client.lua](client.lua) extends App for the game client.

### Additional Initialization

Creates all UI-related managers:
- **ConnectionManager**: Connects to server
- **ResizeManager**: Handles window resizing
- **ScreenManager**: Manages screen transitions
- **Event Managers**: Pointer, Wheel, Button, Keyboard, Text, FileDropEvent
- **NotificationManager**: Shows notifications
- **OptionsManager**: Client settings
- **AssetManager**: Asset download/upload
- **BackstackManager**: Back navigation
- **Session**: Initially nil, created on connection

### Load Flow

1. Pushes quit callback onto backstack (escape key quits)
2. Shows ConnectingScreen
3. Starts connection via ConnectionManager
4. On connection: creates Session
5. On disconnection: shows ConnectingScreen again, releases Session

### LÖVE Callback Extensions

Client overrides `register_love_callbacks()` and extends it with:
- **F11**: Toggle fullscreen
- **Escape**: Backstack navigation (handled in keyboard_manager)
- **Mouse events**: mousepressed, mousereleased, mousemoved → dispatched to pointer_event_manager and button_event_manager
- **Touch events**: touchpressed, touchreleased, touchmoved → dispatched to pointer_event_manager and button_event_manager
- **Wheel**: wheelmoved → wheel_event_manager
- **Keyboard**: keypressed, keyreleased → keyboard_manager and text_event_manager
- **Text**: textinput → text_event_manager
- **File drop**: filedropped → file_system_drop_event_manager
- **Resize**: resize → resize_manager

### Event Flow

All input events are dispatched to multiple managers:
- Pointer events go to both pointer_event_manager AND button_event_manager
- This allows different systems to handle the same event (e.g., button clicks vs. drag-and-drop)

## Server Class

[server.lua](server.lua) extends App for the game server.

### Additional Initialization

Creates server-specific components:
- **_save_file**: Asset("save.lua", true) for persistence
- **_sessions**: Table mapping Connection → Session
- **ConnectionManager**: Listens for connections
- **AssetManager**: Serves assets to clients
- **ScreenManager**: Only if `self.root` exists (window mode), shows ScreenSaver

### Load Flow

1. Loads saved data via `_load_data()`
2. Starts ConnectionManager listening for connections
3. On client connect: creates new Session for that connection
4. On client disconnect: releases and removes Session

### Data Persistence

**Loading** (`_load_data()`):
- Reads `save.lua` file content
- Deserializes via `table.from_string(content)`
- Stores in `self.data`

**Saving** (`save_data()`):
- Serializes `self.data` via `table.to_string(self.data)`
- Writes to `save.lua` file

The server is responsible for calling `save_data()` when game state changes.

### Multi-Session Architecture

The server maintains multiple sessions simultaneously:
- `_sessions[connection] = Session(connection)`
- Each connected client has its own Session instance
- Sessions are independent but share `app.data`

## ArgParser

[arg-parser.lua](arg-parser.lua) validates and parses command-line arguments.

**Expected format**: `love . <app_type> <address> <port>`

**Validation**:
- `app_type`: Must be "server" or "client"
- `address`: Either "localhost" or valid IPv4 (e.g., "192.168.1.1")
- `port`: Number between 1024-65535

**Returns**: `ArgParserResult` table with validated fields, or `nil` if invalid.

**Usage in main.lua**:
```lua
local params = ArgParser.parse(arg)
if not params then
    -- Show usage and quit
end
```

## Constants

[consts.lua](consts.lua) defines application-wide constants.

### Categories

**Application**:
- `APP_USAGE_MESSAGE`: Help text
- `APP_SUCCESS_EXIT_CODE`: 0
- `MODEL_WIDTH`: 2000 (virtual width, scaled to fit screen)

**Networking**:
- `NETWORK_COMPRESSION`: "lz4"
- `HASH_ALGORITHM`: "sha256"
- `CLIENT_SEED`, `SERVER_SEED`: RNG seeds

**Asset Paths**:
- `ASSETS_SERVER_ROOT`: "s"
- `ASSETS_CLIENT_ROOT`: "c"

**Colors** (RGB 0-1 range):
- Background, foreground, button states (normal/hover/select/readonly)
- Notification, logo, selection, token colors
- Multivalue variants for special buttons

**Fonts**:
- `DISPLAY_FONT`: OpenSans.ttf at 80pt
- `USER_INPUT_FONT`: NotoSansMono.ttf at 80pt
- Only loaded if `config.window` exists

**Keybindings**:
- `DRAW_AABBS_KEY`: "f2"
- `QUIT_KEY`: "f4"
- `TOGGLE_FULLSCREEN_KEY`: "f11"
- `BACKSTACK_KEY`: "escape"

**UI Dimensions**:
- Menu scales, padding, spacing
- Input field dimensions
- Notification panel sizing
- Token/page selection settings

**Mouse Buttons**:
- `LEFT_MOUSE_BUTTON`: 1
- `PAGE_SELECT_BUTTON`: 1
- `PAGE_DRAG_TOKEN_BUTTON`: 2
- `PAGE_DRAG_VIEW_BUTTON`: 3

**Logging**:
- `LOGGER_NAME_BLACKLIST`: Patterns for verbose loggers to suppress

### Dynamic Values

Some constants are computed from others:
```lua
Consts.PANEL_FIELD_SCALE = Consts.MENU_FIELD_SCALE
Consts.PANEL_TEXT_INPUT_HEIGHT = Consts.MENU_TEXT_INPUT_HEIGHT
```

Fonts are only loaded when window config exists (headless server doesn't load fonts).

## Global App Variable

The `app` global is set in `App:init()`:
```lua
app = self
```

This makes the app instance accessible everywhere without requiring imports. Check `app.is_client` or `app.is_server` to branch behavior in shared code.

**Manager access pattern**:
```lua
app.screen_manager:show(SomeScreen())
app.asset_manager:download_asset(...)
app.backstack_manager:push(callback)
```

## Debug Mode

When `debug` is true (controlled by LÖVE):
- `love.draw()` supports AABB visualization (F2 key)
- `love.errorhandler()` prints stack traces
- `App:log_fun()` includes function names
- [globals.lua](globals.lua) loads dump utilities

## Headless vs Window Mode

**Window mode** (`config.window` is true):
- Creates `self.root` control
- Registers `love.draw()` callback
- Loads fonts in Consts
- Client always runs in window mode

**Headless mode** (`config.window` is false):
- `self.root` is nil
- No draw callback
- No fonts
- Server can run headless for production

Server checks `if self.root then` before creating ScreenManager.

## Common Patterns

**Extending LÖVE callbacks**:
```lua
function Client:register_love_callbacks()
    App.register_love_callbacks(self)  -- Call parent
    -- Add client-specific callbacks
    function love.keypressed(key)
        -- Handle client input
    end
end
```

**Accessing managers from anywhere**:
```lua
app.notification_manager:show_notification("Hello")
app.screen_manager:show(GameScreen())
```

**Checking context**:
```lua
if app.is_client then
    -- Client-only code
elseif app.is_server then
    -- Server-only code
end
```

**Time tracking**:
```lua
local elapsed = app:get_time()
```
