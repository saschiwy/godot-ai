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
