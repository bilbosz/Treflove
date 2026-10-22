# CLAUDE.md

Guidance for the type annotation packages in this folder.

## Purpose

Type definition packages used by the Lua language server for autocomplete,
type checking and diagnostics of external libraries and frameworks (LÖVE).

## Structure

Each subdirectory is a separate annotation package, a git submodule pointing
to an upstream repository that provides the type definitions, except `enet`:
no upstream package types LÖVE's lua-enet binding, so `enet/library/enet.lua`
is written here, from the binding's source (`src/libraries/enet/enet.cpp` in
LÖVE), and maintained with it.

## Integration

The packages are listed in the language server's workspace library
configuration at the repository root, which tells the server to include them
when analyzing code.

## Important Notes

- **Do not edit** the submodules' annotation files by hand: they are
  maintained upstream and often auto-generated; `enet` is the one package
  edited here
- Update the submodules with `git submodule update --init --recursive`

## Adding New Annotation Packages

1. Add the package as a git submodule in this folder
   (`git submodule add <repository-url> annotations/<package-name>`)
2. Add it to the language server's workspace library configuration
3. Run the diagnostics script to verify the annotations work

## Maintenance

Update the annotation submodules periodically for the latest type definitions
and fixes from upstream, and test the project afterwards.

## Documentation

The Lua Language Server annotation guide: https://luals.github.io/wiki/annotations/
