"""MCP tool for TileSet management."""

from __future__ import annotations

from fastmcp import FastMCP

from godot_ai.handlers import tileset as tileset_handlers
from godot_ai.tools._meta_tool import register_manage_tool

_DESCRIPTION = """\
TileSet management — generate per-layer specialized subset .tres files from
a biome's main TileSet resource.

Ops:
  • tileset_generate_specialized(biom, layer_sources, root_dir="res://")
        Generate specialized .tres files for each layer from the main
        {root_dir}/{biom}/{biom}.tres.

        Each specialized file contains only the Source-IDs for that layer,
        re-numbered from 0. The main {biom}.tres is never modified.
        Existing files are NEVER overwritten (idempotent).

        biom: canonical biome folder name (e.g. "volcano")

        root_dir: optional base folder for biome TileSets (default: "res://")

        layer_sources: object mapping layer names to source_id arrays
        from the main .tres, e.g.:
          {
            "floor":    [0, 5, 6],
            "walls":    [1, 2, 3, 4],
            "props":    [7],
            "animated": [8]
          }

        Returns: {
          "created": ["res://.../volcano_floor.tres", ...],
          "skipped": ["res://.../volcano_walls.tres", ...]
        }

        Source-ID remapping: Source-IDs in specialized files start at 0.
        Example: volcano lava (Source 8 in main .tres) → Source 0 in
        volcano_animated.tres. Use the remapped ID in tilemap_manage calls.

        Hard stop: if the main {biom}.tres does not exist, the command
        returns NODE_NOT_FOUND with a hint to run setup_{biom}.gd first.
"""


def register_tileset_tools(mcp: FastMCP) -> None:
    register_manage_tool(
        mcp,
        tool_name="tileset_manage",
        description=_DESCRIPTION,
        ops={
            "tileset_generate_specialized": tileset_handlers.tileset_generate_specialized,
        },
    )
