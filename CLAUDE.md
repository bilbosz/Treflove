# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Treflove is a multiplayer turn-based tabletop game engine built on LÖVE (love2d). The game master creates rules in Lua and can dynamically modify game state during gameplay. The project follows a server-client uniform architecture where many classes work in both server and client contexts. Only vanilla love2d is used - no external dependencies.

## Prerequisites

External tools required by the dev scripts (`love`, `lua-format`, `lua-language-server`, `jq`, `rg`) are listed with installation instructions in [REQUIREMENTS.md](REQUIREMENTS.md).

## Documentation

Detailed guidance is split into topic files, imported below. To address one topic selectively, reference its file directly (e.g., `@docs/type-annotations.md` in a prompt):

- [docs/development.md](docs/development.md) - running the app, dev commands (format/lint/diagnose), test suite
- [docs/architecture.md](docs/architecture.md) - subsystems, design patterns, LÖVE integration
- [docs/conventions.md](docs/conventions.md) - naming, modules vs classes, globals
- [docs/type-annotations.md](docs/type-annotations.md) - LuaDoc annotation rules, strict typing, LÖVE types, annotation packages

@docs/development.md

@docs/architecture.md

@docs/conventions.md

@docs/type-annotations.md

## Project Status

The README lists completed milestones and known to-dos. Notably **not yet implemented**: game master script handling, game state synchronization, game objects other than tokens, media other than images, and prefabs.
