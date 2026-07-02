"""Shared handlers for TileSet management tools."""

from __future__ import annotations

from godot_ai.handlers._readiness import require_writable_async
from godot_ai.runtime.direct import DirectRuntime


async def tileset_generate_specialized(
    runtime: DirectRuntime,
    biom: str,
    layer_sources: dict[str, list[int]],
    root_dir: str = "res://",
) -> dict:
    """Generate per-layer specialized TileSet .tres files from the main biome
    TileSet (``{root_dir}/{biom}/{biom}.tres``).

    Each specialized file contains only the Source-IDs assigned to that
    layer, re-numbered from 0.  The main ``{biom}.tres`` is never modified.
    Existing files are never overwritten (idempotent).

    ``layer_sources`` maps layer names to source_id arrays from the main
    .tres, e.g.::

        {
            "floor":    [0, 5, 6],
            "walls":    [1, 2, 3, 4],
            "props":    [7],
            "animated": [8],
        }

    Returns ``{"created": [...paths...], "skipped": [...paths...]}``.

    Source-ID remapping note: ``volcano_animated.tres`` stores Lava
    (Source 8 in the main .tres) as **Source 0**.  All ``tilemap_manage``
    calls targeting that layer must use the remapped ID.
    """
    await require_writable_async(runtime)
    return await runtime.send_command(
        "tileset_generate_specialized",
        {
            "biom": biom,
            "layer_sources": layer_sources,
            "root_dir": root_dir,
        },
    )


async def tileset_get_atlas_tiles(
    runtime: DirectRuntime,
    tileset_path: str,
    source_id: int,
) -> dict:
    """Return all occupied atlas positions for one source in a TileSet.

    Calls the GDScript ``get_atlas_tiles`` handler (read-only) and returns
    its result unchanged.

    Args:
        runtime:       In-process runtime adapter.
        tileset_path:  ``res://`` path to the ``.tres`` TileSet resource.
        source_id:     Integer index of the ``TileSetAtlasSource`` to query.

    Returns:
        ``{"tiles": [{"col": int, "row": int}, ...], "count": int}`` on
        success, or an error dict from the GDScript handler.
    """
    return await runtime.send_command(
        "tileset_get_atlas_tiles",
        {
            "tileset_path": tileset_path,
            "source_id": source_id,
        },
    )


async def tileset_get_atlas_image(
    runtime: DirectRuntime,
    tileset_path: str,
    source_id: int,
    max_size: int = 0,
) -> dict:
    """Return the atlas texture of a TileSetAtlasSource as a Base64-encoded PNG.

    Reads the ``TileSetAtlasSource.texture`` directly from the resource —
    no UI interaction required.  The image can optionally be downscaled for
    faster transfer.

    Args:
        runtime:       In-process runtime adapter.
        tileset_path:  ``res://`` path to the ``.tres`` TileSet resource.
        source_id:     Integer index of the ``TileSetAtlasSource`` to query.
        max_size:      If > 0, scale the image so its longest edge is at most
                       this many pixels.  0 (default) = full resolution.

    Returns:
        ``{"image_base64": str, "width": int, "height": int,
           "original_width": int, "original_height": int, "format": "png"}``
        on success, or an error dict from the GDScript handler.
    """
    return await runtime.send_command(
        "tileset_get_atlas_image",
        {
            "tileset_path": tileset_path,
            "source_id": source_id,
            "max_size": max_size,
        },
    )
