# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Treflove is a multiplayer turn-based tabletop game engine built on LÖVE (love2d). The game master creates rules in Lua and can dynamically modify game state during gameplay. The project follows a server-client uniform architecture where many classes work in both server and client contexts. Only vanilla love2d is used at runtime - no external dependencies.

The source is being migrated from Lua to Teal with the lua-lifetime extension (`.tlt` files with `.d.tl` declaration fragments), compiled by `./build-code.sh` into plain Lua under `build/`, which the app runs. Converted so far: the class system, `utils/`, `events/`, `controls/`, `networking/` (with the connection thread scripts), `data/`, `app/consts`, `app/arg-parser`, `app/globals`; everything else is still `.lua`.

## Prerequisites

External tools required by the dev scripts (`luajit`, `love`, `luacheck`) are listed with installation instructions in [REQUIREMENTS.md](REQUIREMENTS.md). The Teal compiler, lua-lifetime and the LÖVE API description are submodules under `lib/` (`git submodule update --init`).

## Documentation

Detailed guidance is split into topic files, imported below. To address one topic selectively, reference its file directly (e.g., `@docs/types.md` in a prompt):

- [docs/development.md](docs/development.md) - running the app, the build, dev commands (build/test/lint), test suite
- [docs/architecture.md](docs/architecture.md) - subsystems, design patterns, LÖVE integration
- [docs/conventions.md](docs/conventions.md) - naming, modules vs classes, globals
- [docs/types.md](docs/types.md) - Teal types: declaration fragments, the class recipe, modules, LÖVE types
- [docs/lifetime.md](docs/lifetime.md) - the lifetime extension: destructors, ownership, hooks, tombstones

@docs/development.md

@docs/architecture.md

@docs/conventions.md

@docs/types.md

@docs/lifetime.md

## Project Status

The README lists completed milestones and known to-dos. Notably **not yet implemented**: game master script handling, game state synchronization, game objects other than tokens, media other than images, and prefabs.
