# Treflove

## Design goal

The aim of the project is to create or prototype a multiplayer game for several people and the ability to play a turn-based tabletop game. The individual rules of the game will be created by the game master in Lua and he will be able to change the game state (tokens, objects, maps, sound) at any time during the game. Main goal of this project is to make the game master's work as easy as possible.

## Prerequisites

- To run: [LÖVE](https://love2d.org/) 11.5, the only runtime requirement, and the author makes sure to deliver.
- To build: [LuaJIT](https://luajit.org/) (or Lua 5.1) and the git submodules under `lib/` (`git submodule update --init`). The source is [Teal](https://github.com/teal-language/tl) with the [lua-lifetime](https://github.com/bilbosz/lua-lifetime) extension, compiled into plain Lua under `build/`.

See [REQUIREMENTS.md](REQUIREMENTS.md) for the development tools.

## Architectural goals

Server-client uniform architecture - some classes are used in server and client context.

No external requirements at runtime other than what the vanilla love2d framework offers, plus the lifetime runtime (a single Lua file from lua-lifetime, vendored into `build/` by the build). The toolchain is two vendored git submodules, so a clone builds with nothing installed but LuaJIT: [tl](https://github.com/teal-language/tl), the Teal compiler (types checked at build time), and [lua-lifetime](https://github.com/bilbosz/lua-lifetime), the transpiler and runtime for owned objects with destructors; a third submodule, [love-api](https://github.com/love2d-community/love-api), describes LÖVE's API for the generated LÖVE types.

## Running

Build first (the app runs from `build/`):

    ./build-code.sh

To run server use command:

    love . server localhost 8080

To run client instance run command:

    love . client localhost 8080

To build and run single instance of client and server use:

    ./run.sh

## Project status

Milestones that are consider done at this point:
* module system
* classes with inheritance
* networking
* asset handling - sending into server and backpropagating
* graphical control system
* simple interactive gui elements
* event system
* user login logic
* storing assets and game state on server's user directory
* storing client settings in user directory
* human readable data serialization
* typed with Teal
* deterministic ownership with lua-lifetime

Known to-dos:
* game master script handling
* game objects other than tokens
* clipping controls that are out of clipping rectangle
* handling other media than images
* ability to change board and background music at will
* adding prefabs
* game state synchronization
