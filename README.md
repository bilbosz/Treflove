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

The server starts from scratch: its save directory holds no accounts and
no games until someone signs up from the login screen and creates a game
from the games list, and it keeps them across restarts. Nothing in the
program resets it; `--fixture <dir>`, the scenario tooling, empties a
root and seeds it, and needs `--identity`, a save directory of its own.

To run single instance of client and server use:

    ./run.sh

To run a scenario headless (the client driven through its UI; exit code 0 or 1):

    ./scenario.sh join-game

To play in the Old Town world (a scenario fixture: a real map, four tokens),
in a window the app stays open in:

    ./scenario.sh old-town --windowed

To run Lua inside a running client or server, and to watch their values in a window:

    love . console 127.0.0.1 9090 'return app:get_time()'
    love . monitor 127.0.0.1 client:9090,server:9091

To debug, use the VS Code launch configurations (Run and Debug): the client,
the server, both at once, a scenario headless, or the test suite; see
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
* accounts created from the login screen, kept by the server outside every game
* many games on one server, each with its state and assets, listed and joined from the menu, a new one bootstrapped from a template
* storing assets and game state on server's user directory
* storing client settings in user directory
* human readable data serialization
* scenarios driving the client through its UI, headless or in a window, and a console port into the live program
* the console as a command and a monitor window over the watches and the log of client and server
* token changes synchronized through the server: checked against the player's grants, saved, pushed to the other clients in the game
* tokens created from the game's New Token entry and deleted from the token panel, through the server like a change
* the game's pages, groups, players' grants, token properties and the shown page edited from the game's side panels, through the server like a token, the shown page switching on every client

Known to-dos:
* game master script handling
* game objects other than tokens
* clipping controls that are out of clipping rectangle
* handling other media than images in the game (playing sound, a video on a page)
* ability to change board and background music at will
* adding prefabs
* game state synchronization beyond tokens and entries (a token's owners, a token moved to another page, a player removed from a game)
