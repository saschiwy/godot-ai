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
        returns RESOURCE_NOT_FOUND with a hint to run setup_{biom}.gd first.

  • tileset_get_atlas_tiles(tileset_path, source_id)
        Return all occupied atlas tile positions for one source in a TileSet.
        Read-only — does not modify any resource or project file.

        tileset_path: res:// path to the .tres TileSet resource (required)
        source_id:    integer index of the TileSetAtlasSource to query (required, ≥ 0)

        Returns:
          {"tiles": [{"col": int, "row": int}, ...], "count": int}

        Error codes (passed through from GDScript handler):
          MISSING_REQUIRED_PARAM  — tileset_path empty or source_id absent
          RESOURCE_NOT_FOUND      — tileset_path does not exist on disk
          WRONG_TYPE              — not a TileSet, or source is not a TileSetAtlasSource
          VALUE_OUT_OF_RANGE      — source_id out of bounds for this TileSet

  • tileset_get_atlas_image(tileset_path, source_id, max_size=0)
        Return the atlas sprite-sheet texture of a TileSetAtlasSource as a
        Base64-encoded PNG image.  Read-only — reads the texture directly
        from the resource without any UI interaction.

        tileset_path: res:// path to the .tres TileSet resource (required)
        source_id:    integer index of the TileSetAtlasSource to query (required, ≥ 0)
        max_size:     optional int; if > 0, scale the image so its longest
                      edge is at most max_size pixels (default 0 = full res)

        Returns:
          {"image_base64": str, "width": int, "height": int,
           "original_width": int, "original_height": int, "format": "png"}

        Error codes (passed through from GDScript handler):
          MISSING_REQUIRED_PARAM  — tileset_path empty or source_id absent
          RESOURCE_NOT_FOUND      — tileset_path does not exist on disk
          WRONG_TYPE              — not a TileSet, source not a TileSetAtlasSource,
                                    or source has no texture assigned
          VALUE_OUT_OF_RANGE      — source_id out of bounds for this TileSet

  • Atlas image workflow:
        To visually inspect what tiles look like, use tileset_get_atlas_image
        instead of editor screenshots. It reads the texture directly from the
        resource — no UI interaction or editor state required.
"""


def register_tileset_tools(mcp: FastMCP) -> None:
    register_manage_tool(
        mcp,
        tool_name="tileset_manage",
        description=_DESCRIPTION,
        ops={
            "tileset_generate_specialized": tileset_handlers.tileset_generate_specialized,
            "tileset_get_atlas_tiles": tileset_handlers.tileset_get_atlas_tiles,
            "tileset_get_atlas_image": tileset_handlers.tileset_get_atlas_image,
        },
        read_resource_forms={
            "tileset_get_atlas_tiles": None,
            "tileset_get_atlas_image": None,
        },
    )
