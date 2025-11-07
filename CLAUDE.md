# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Treflove is a multiplayer turn-based tabletop game engine built on LÖVE (love2d). The game master creates rules in Lua and can dynamically modify game state during gameplay. The project follows a server-client uniform architecture where many classes work in both server and client contexts. Only vanilla love2d is used - no external dependencies.

## Running the Application

Run server only:
```bash
love . server localhost 8080
```

Run client only:
```bash
love . client localhost 8080
```

Run both server and client together:
```bash
./run.sh
```

## Development Commands

Format all Lua code (uses lua-format):
```bash
./format-code.sh
```

Diagnose all Lua code (uses lua-language-server):
```bash
./diagnose-code.sh [target_path]
```

The `diagnose-code.sh` script:
- Runs `lua-language-server` diagnostics and outputs results as JSON
- Accepts optional `target_path` argument to filter results (file or directory)
- Defaults to diagnosing the entire project if no target is specified
- Examples:
  - `./diagnose-code.sh` - diagnose entire project
  - `./diagnose-code.sh app/client.lua` - diagnose single file
  - `./diagnose-code.sh controls/` - diagnose directory

The project uses:
- `lua-format` for code formatting (config in [.lua-format](.lua-format))
- `luacheck` for linting (config in [.luacheckrc](.luacheckrc))
- `lua-language-server` for diagnosis report (config in [.luarc.json](.luarc.json))

## Type Annotations

The [annotations/](annotations/) folder contains type definition packages for external libraries used by the Lua language server. These provide autocomplete, type checking, and diagnostics for frameworks like LÖVE.

- Annotation packages are typically git submodules maintained in upstream repositories
- **DO NOT manually edit** annotation files - they are often auto-generated
- Integrated via `workspace.library` setting in [.luarc.json](.luarc.json)
- Update submodules with: `git submodule update --init --recursive`
- **External library documentation** can be found within annotation files. For example, `love.keypressed` is documented in [annotations/love2d/library/love.lua](annotations/love2d/library/love.lua):
  ```lua
  ---Callback function triggered when a key is pressed.
  ---@alias love.keypressed fun(key: love.KeyConstant, scancode: love.Scancode, isrepeat: boolean)
  ```
- See [annotations/CLAUDE.md](annotations/CLAUDE.md) for details on adding new annotation packages

## Architecture

### Dual-Mode Bootstrap

[main.lua](main.lua) parses arguments and instantiates either Client or Server:
- **Client** ([app/client.lua](app/client.lua)): Full UI application with multiple event managers (pointer, keyboard, wheel, button, text, file-drop, resize), screen manager, connection manager, asset manager, backstack navigation, notification system, and session management
- **Server** ([app/server.lua](app/server.lua)): Can run headless or with a screen saver, manages multiple sessions (one per connection), persists game state to `save.lua` using human-readable serialization

Both inherit from [App](app/app.lua) and register LÖVE callbacks.

### Custom Class System

The project implements a custom class system in [utils/class.lua](utils/class.lua) with **multiple inheritance** support:

```lua
local MyClass = class("MyClass", BaseClass1, BaseClass2)
```

Key functions:
- `class(name, ...)` - creates a new class with optional base classes
- `is_instance_of(obj, cls)` - type checking
- `get_class_name_of(obj)` - reflection
- `get_class_of(obj)` - get class table
- `assert_type(obj, typ)` - runtime validation

Classes define an `init` method that acts as a constructor. Multiple inheritance merges methods from all base classes in reverse order.

### Global App Instance

The global `app` variable references either the Client or Server instance and is accessible everywhere. Check `app.is_client` or `app.is_server` to determine context. Many systems are accessed through app managers (e.g., `app.screen_manager`, `app.asset_manager`).

### Networking Architecture

Thread-based networking using LÖVE's threading system:

- **ConnectionManager** ([networking/connection-manager.lua](networking/connection-manager.lua)): Tracks all connections, indexed by channels
- **Connection** ([networking/connection.lua](networking/connection.lua)): Wraps a pair of channels (in/out) and threads for bidirectional communication
- **Connector** ([networking/connector.lua](networking/connector.lua)): Establishes connections
- **RemoteProcedure** ([networking/remote-procedure.lua](networking/remote-procedure.lua)): Base class for RPC pattern

Each connection spawns separate threads for sending and receiving. The server maintains multiple connections simultaneously; the client maintains one connection to the server.

### Remote Procedure Pattern

RPCs inherit from RemoteProcedure and implement:
- `send_response(request)` - server-side handler that returns response data
- `receive_response(response)` - client-side handler that processes response
- `send_request(request, cb)` - initiates RPC call

The class name is used as the RPC identifier. Examples: LoginRp, UploadAssetRp, DownloadAssetRp.

### Session Management

[Session](game/session.lua) ties a connection to user state:
- Manages login/logout lifecycle via [Login](login/login.lua)
- Coordinates screen transitions (connecting → login → user menu → game)
- Integrates with asset manager and backstack navigation
- Server maintains `_sessions` table mapping Connection → Session
- **Note**: Client auto-logs in with hardcoded credentials "adam"/"krause" at [game/session.lua:56](game/session.lua#L56)

### Event System

Event managers follow a consistent pattern in [events/](events/):
- Managers maintain lists of listeners
- Listeners register/unregister with managers
- Events are dispatched to all registered listeners
- Multiple event types: PointerEvent, WheelEvent, ButtonEvent, TextEvent, Keyboard, FileDropEvent, ResizeEvent, UpdateEvent

Client sets up all event managers in its `init` and wires them to LÖVE callbacks in `register_love_callbacks`.

### UI Control Hierarchy

[Control](controls/control.lua) is the base class for all UI elements:
- Manages parent-child relationships via `add_child`/`remove_child`
- Handles transforms (position, scale, rotation)
- Computes axis-aligned bounding boxes (AABBs) for hit testing
- Propagates events down the hierarchy
- Can intercept pointer events

Specialized controls:
- [DrawableControl](controls/drawable-control.lua): Adds rendering
- Primitives: Rectangle, Circle, Text, Image
- [ClippingMask](controls/clipping-mask.lua): Clips children to rectangular bounds

Higher-level UI components in [ui/](ui/) like Panel, TextButton, Input, NumberInput build on these primitives.

### Screen Management

[ScreenManager](screens/screen-manager.lua) manages active screen via `show(screen)`. Screens are full-screen UI containers. Key screens:
- ConnectingScreen - connection status
- LoginScreen - authentication
- UserMenuScreen - post-login menu
- GameScreen - main game view
- WaitingScreen - loading states
- ScreenSaver - server screen when headless

### Asset Management

[AssetManager](data/asset-manager.lua):
- Tracks assets per session
- Downloads missing assets from server on demand
- Handles asset uploads to server
- [Asset](data/asset.lua) wraps LÖVE's filesystem operations

RPCs: DownloadAssetRp, DownloadMissingAssetsRp, UploadAssetRp

### Data Persistence

Server persists game state to `save.lua` in human-readable format:
- `table.to_string()` serializes Lua tables to string ([utils/table.lua](utils/table.lua))
- `table.from_string()` deserializes back to tables
- `Server:save_data()` writes to file
- `Server:_load_data()` reads on startup

### Backstack Navigation

[BackstackManager](utils/backstack-manager.lua) maintains a stack of callbacks for back navigation (similar to browser history). When user presses back, the top callback is invoked and popped.

## Code Conventions

- **Naming**:
  - snake_case for functions, variables, and module tables
  - PascalCase for classes
  - Examples:
    - Class: `local MyClass = class("MyClass")`
    - Module: `local arg_parser = {}` (table with static functions)
    - Function: `function arg_parser.parse(args)`
    - Variable: `local start_time = 0`
- **Modules vs Classes**:
  - **Modules**: Tables with static functions (no instances created)
    - Use snake_case naming: `arg_parser`, `utils`, etc.
    - Return the table directly: `return arg_parser`
    - Example: [app/arg-parser.lua](app/arg-parser.lua)
  - **Classes**: Use custom class system for object-oriented code
    - Use PascalCase naming: `Client`, `Server`, `Session`
    - Create instances with `ClassName()`
    - Example: [app/client.lua](app/client.lua)
- **Privacy**: Prefix private members with underscore (`_method`, `_field`)
- **Callbacks**: Named with `on_` prefix (`on_connect`, `on_disconnect`)
- **Type annotations**: Use LuaDoc format (`---@class`, `---@param`, `---@return`, `---@field`, `---@alias`)
  - **Required whenever possible**: All public functions and methods should have type annotations
  - **Parameters**: Always annotate function parameters with `---@param name Type`
  - **Return values**: Only annotate return types when functions **DO** return values using `---@return Type`
  - **Void functions**: Do NOT annotate functions that return nothing - no `---@return void` or similar
  - **Classes**: All classes must have `---@class ClassName` annotation
    - For single inheritance: `---@class ClassName : BaseClass`
    - For multiple inheritance: `---@class ClassName : BaseClass1, BaseClass2, BaseClass3`
    - Multiple inheritance is supported by the custom class system (see [utils/class.lua](utils/class.lua))
  - **Fields**: Class fields should be documented with `---@field name Type`
    - For constants/configuration tables with literal values, the Lua language server can infer types automatically - explicit field annotations are optional
  - **Variadic functions**: Functions using `...` should document the variadic parameter with `---@param ... Type`
  - **LÖVE framework types**: Use specific LÖVE types from annotations (e.g., `love.KeyConstant`, `love.Font`, `love.DroppedFile`) instead of generic types like `string` or `any`
- **Type aliases**: For callbacks: `---@alias CallbackName fun(param:Type)`

## Global Variables and Functions

Defined in [.luacheckrc](.luacheckrc) and loaded via [app/globals.lua](app/globals.lua):

- `app` - global Client or Server instance
- `class()` - class constructor
- `is_instance_of()`, `get_class_name_of()`, `get_class_of()` - reflection
- `assert_type()`, `assert_unreachable()` - assertions
- `table.*` - extended table utilities (merge, find, serialization)
- `love.*` - LÖVE framework API
- `dump()` - debug dumping (only in debug mode)

## Key Design Patterns

**Shared Client/Server Code**: Classes in `data/`, `controls/`, `networking/` work in both contexts. Use `app.is_client` or `app.is_server` to branch behavior.

**Manager Pattern**: Centralized managers coordinate subsystems (ConnectionManager, ScreenManager, AssetManager, event managers, etc.).

**Event Listeners**: Components implement listener interfaces and register with managers.

**Remote Procedures**: Request-response pattern over network connections using class names as identifiers.

**Resource Cleanup**: Classes implement `release()` methods for cleanup, called when objects are no longer needed.

## LÖVE Framework Integration

- Entry: [main.lua](main.lua)
- Config: [conf.lua](conf.lua)
- Callbacks registered in `App:register_love_callbacks()` and overridden in Client/Server
- Client uses love.graphics, love.window, love.keyboard, love.mouse, love.touch
- Both use love.thread and love.channel for networking
- Server can run headless (no graphics) or with minimal UI
