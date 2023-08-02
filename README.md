# Treflove

## Design goal

The aim of the project is to create or prototype a multiplayer game for several people and the ability to play a turn-based tabletop game. The individual rules of the game will be created by the game master in Lua and he will be able to change the game state (tokens, objects, maps, sound) at any time during the game. Main goal of this project is to make the game master's work as easy as possible.

## Prerequisites

[LÖVE](https://love2d.org/) is the only requirement for this project and the author makes sure to deliver.

## Architectural goals

Server-client uniform architecture - some classes are used in server and client context.

No external requirements other than what vanilla love2d framework offers.

## Running

To run server use command:

    love . server localhost 8080

To run client instance run command:

    love . client localhost 8080

To run single instance of client and server use:

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

Known to-dos:
* game master script handling
* game objects other than tokens
* clipping controls that are out of clipping rectangle
* handling other media than images
* ability to change board and background music at will
* adding prefabs
* game state synchronization
