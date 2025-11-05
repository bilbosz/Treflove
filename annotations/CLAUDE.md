# CLAUDE.md

This file provides guidance to Claude Code when working with type annotations in this folder.

## Purpose

The [annotations/](annotations/) folder contains type definition packages used by the Lua language server to provide autocomplete, type checking, and diagnostics for external libraries and frameworks.

## Structure

Each subdirectory represents a separate annotation package, typically maintained as a git submodule pointing to an upstream repository that provides type definitions.

## Integration

Annotations are integrated via the [.luarc.json](.luarc.json) configuration at the repository root using the `workspace.library` setting, which tells the Lua language server to include these definitions when analyzing code.

## Important Notes

- **DO NOT manually edit** annotation files - they are maintained in upstream repositories and often auto-generated
- Annotation folders are typically **git submodules** - use git submodule commands to update them
- To update all submodules: `git submodule update --init --recursive`

## Adding New Annotation Packages

When adding annotations for new libraries:

1. Add the annotation package as a git submodule in this directory:
   ```bash
   git submodule add <repository-url> annotations/<package-name>
   ```

2. Update [.luarc.json](.luarc.json) to include the new annotations:
   ```json
   "workspace.library": [
     "annotations/<package-name>"
   ]
   ```

3. Run diagnostics to verify the annotations work correctly:
   ```bash
   ./diagnose-code.sh
   ```

## Maintenance

Periodically update annotation submodules to get the latest type definitions and bug fixes from upstream sources. Always test the project after updating to ensure compatibility.

## Documentation

For information about writing and using Lua Language Server annotations, see the official documentation:
- **Annotations Guide**: https://luals.github.io/wiki/annotations/