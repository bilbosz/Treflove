# Treflove

## Design goal

The aim of the project is to create or prototype a multiplayer game for several people and the ability to play a turn-based tabletop game. The individual rules of the game will be created by the game master in Lua and he will be able to change the game state (tokens, objects, maps, sound) at any time during the game. Main goal of this project is to make the game master's work as easy as possible.

## Prerequisites

[LÖVE](https://love2d.org/) is the only requirement for this project and the author makes sure to deliver.

This branch also carries [lua-lifetime](https://github.com/bilbosz/lua-lifetime) as a git submodule
(`lib/lua-lifetime`, pure Lua, used as a library): run `git submodule update --init --recursive`
after cloning. See [docs/lifetimes.md](docs/lifetimes.md) for what it replaces.

## Architectural goals

Server-client uniform architecture - some classes are used in server and client context.

No external requirements other than what vanilla love2d framework offers. This branch is the
exception made for comparison: object lifetimes (who owns what, and in which order things are
released) are tracked by the lua-lifetime runtime instead of hand-written `release()` chains -
[docs/lifetimes.md](docs/lifetimes.md).

## Running

To run server use command:

    love . server localhost 8080

To run client instance run command:

    love . client localhost 8080

To run single instance of client and server use:

    ./run.sh

To debug, use the VS Code launch configurations (Run and Debug): the client,
the server, both at once, or the test suite; see
[docs/development.md](docs/development.md#debugging).

## Project status

Milestones that are consider done at this point:
* module system
* classes with inheritance
* networking
* asset handling - sending into server and backpropagating
* assets workspace - browsing the server's assets, folders, renaming and deleting
* media previews - images, videos and audio with a player, fonts with a sample text
* graphical control system
* simple interactive gui elements
* event system
* user login logic
* storing assets and game state on server's user directory
* storing client settings in user directory
* human readable data serialization

Known to-dos:
* game master script handling
* game objects other than tokens
* clipping controls that are out of clipping rectangle
* handling other media than images in the game (playing sound, a video on a page)
* ability to change board and background music at will
* adding prefabs
* game state synchronization
