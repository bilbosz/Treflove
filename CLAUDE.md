# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Treflove is a multiplayer turn-based tabletop game engine built on LÖVE (love2d). The game master creates rules in Lua and can dynamically modify game state during gameplay. The project follows a server-client uniform architecture where many classes work in both server and client contexts. At runtime only vanilla love2d and the lifetime runtime (copied from the `lib/lua-lifetime` submodule into `build/`) are used - no other dependencies.

The source is Teal with the lua-lifetime extension: every module, test module and test helper is a `.tlt` file, with its public types in a `.d.tl` declaration fragment, compiled by `./build-code.sh` into plain Lua 5.1 under `build/`, which the app and the tests run. Types replace annotations ([docs/types.md](docs/types.md)); ownership is written with `@` and `!@`, and `release` methods are destructors run by the lifetime runtime ([docs/lifetime.md](docs/lifetime.md)). The only `.lua` sources are the LÖVE bootstraps (`main.lua`, `conf.lua`), the test entry point (`tests/run.lua`) and the build tools (`tools/`); `server/save.lua` is data.

## Prerequisites

External tools required by the dev scripts (`luajit`, `love`, `luacheck`) are listed with installation instructions in [REQUIREMENTS.md](REQUIREMENTS.md). The toolchain - the Teal compiler (`lib/tl`), the lifetime transpiler and runtime (`lib/lua-lifetime`) and the LÖVE API description (`lib/love-api`) - are git submodules under `lib/` (`git submodule update --init`).

## Documentation

Detailed guidance is split into topic files, imported below. To address one topic selectively, reference its file directly (e.g., `@docs/types.md` in a prompt):

- [docs/development.md](docs/development.md) - running the app, source layout, the build, dev commands (build/test/lint), test suite, CI
- [docs/architecture.md](docs/architecture.md) - subsystems, ownership, design patterns, LÖVE integration
- [docs/conventions.md](docs/conventions.md) - naming, modules vs classes, fragments, casts, globals
- [docs/types.md](docs/types.md) - Teal types: declaration fragments, the class recipe, modules, LÖVE types
- [docs/lifetime.md](docs/lifetime.md) - the lifetime extension: destructors, the ownership tree, hooks, tokens, tombstones

@docs/development.md

@docs/architecture.md

@docs/conventions.md

@docs/types.md

@docs/lifetime.md

## Project Status

The README lists completed milestones and known to-dos. Notably **not yet implemented**: game master script handling, game state synchronization, game objects other than tokens, media other than images, and prefabs.
