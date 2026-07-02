@tool
extends RefCounted

## TileSet management — generate per-layer specialized subset .tres files
## from a biome's main TileSet resource.
##
## Specialized files contain only the Source-IDs for one layer, re-numbered
## from 0. The main {biom}.tres is never modified.

const ErrorCodes := preload("res://addons/godot_ai/utils/error_codes.gd")


func _init() -> void:
	pass  # No undo_redo needed — uses ResourceSaver only


## Generate specialized TileSet .tres files from the main biome TileSet.
##
## params:
##   biom         — canonical biome folder name (e.g. "volcano")
##   root_dir     — optional base folder (default: "res://")
##   layer_sources — Dictionary mapping layer names to source_id arrays:
##                   {"floor": [0, 5, 6], "walls": [1, 2, 3, 4],
##                    "props": [7], "animated": [8]}
##
## Returns: {created: [...paths...], skipped: [...paths...]}
## Existing files are NEVER overwritten (idempotent).
## Source-IDs in specialized files start at 0 and are sequential.
## Example: volcano Source 8 (lava) → volcano_animated.tres Source 0.
func generate_specialized_tilesets(params: Dictionary) -> Dictionary:
	var biom: String = params.get("biom", "")
	if biom.is_empty():
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "'biom' parameter is required")

	var root_dir: String = params.get("root_dir", "res://").strip_edges()
	if root_dir.is_empty():
		root_dir = "res://"
	if not root_dir.ends_with("/"):
		root_dir += "/"

	var main_path := "%s%s/%s.tres" % [root_dir, biom, biom]
	if not ResourceLoader.exists(main_path):
		return ErrorCodes.make(
			ErrorCodes.NODE_NOT_FOUND,
			"Main TileSet not found: %s" % main_path
		)

	var main_ts: TileSet = load(main_path)
	if main_ts == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR,
			"Failed to load TileSet: %s" % main_path)

	var layer_sources: Dictionary = params.get("layer_sources", {})
	if layer_sources.is_empty():
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS,
			"'layer_sources' parameter is required (e.g. {\"floor\": [0, 5, 6]})")

	var created: Array[String] = []
	var skipped: Array[String] = []

	for layer_name in layer_sources:
		var output_path := "%s%s/%s_%s.tres" % [root_dir, biom, biom, layer_name]

		if ResourceLoader.exists(output_path):
			skipped.append(output_path)
			continue

		var source_ids: Array = layer_sources[layer_name]
		var new_ts := TileSet.new()
		new_ts.tile_size = main_ts.tile_size

		var new_id := 0
		for src_id in source_ids:
			var src := main_ts.get_source(int(src_id))
			if src == null:
				push_error("tileset_handler: Source %d not found in %s — skipping" % [src_id, main_path])
				continue
			new_ts.add_source(src, new_id)
			new_id += 1

		var err := ResourceSaver.save(new_ts, output_path)
		if err != OK:
			return ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR,
				"Failed to save %s (Godot error %d)" % [output_path, err]
			)
		created.append(output_path)

	return {"data": {"created": created, "skipped": skipped}}


## Query all occupied atlas tile positions for a single source.
##
## params:
##   tileset_path  — res:// path to the TileSet resource (required, non-empty)
##   source_id     — integer index of the source within the TileSet (required)
##
## Returns:
##   {"data": {"tiles": [{"col": int, "row": int}, ...], "count": int}}
##     on success (including empty sources, where tiles=[] and count=0)
##   ErrorCodes.make(code, message)  on any validation or load failure
##
## Error codes:
##   MISSING_REQUIRED_PARAM  — tileset_path absent/empty, or source_id absent
##   RESOURCE_NOT_FOUND      — ResourceLoader.exists(tileset_path) is false
##   WRONG_TYPE              — loaded resource is not a TileSet, or source is
##                             not a TileSetAtlasSource
##   VALUE_OUT_OF_RANGE      — source_id < 0 or >= TileSet.get_source_count()
##
## This method is read-only: it never calls ResourceSaver or modifies any resource.
func get_atlas_tiles(params: Dictionary) -> Dictionary:
	var tileset_path: String = params.get("tileset_path", "")
	if tileset_path.is_empty():
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM,
			"'tileset_path' parameter is required and must not be empty"
		)

	if not params.has("source_id"):
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM,
			"'source_id' parameter is required"
		)

	if not ResourceLoader.exists(tileset_path):
		return ErrorCodes.make(
			ErrorCodes.RESOURCE_NOT_FOUND,
			"TileSet resource not found: %s" % tileset_path
		)

	var ts = load(tileset_path)
	if not ts is TileSet:
		var loaded_type := "null" if ts == null else ts.get_class()
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE,
			"Resource at '%s' is not a TileSet (got %s)" % [tileset_path, loaded_type]
		)

	var source_index: int = params.get("source_id", -999)
	if source_index < 0 or source_index >= ts.get_source_count():
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE,
			"source_id %d is out of range (TileSet has %d sources)" % [source_index, ts.get_source_count()]
		)

	var source_id: int = ts.get_source_id(source_index)
	var src = ts.get_source(source_id)
	if not src is TileSetAtlasSource:
		var source_type := "null" if src == null else src.get_class()
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE,
			"Source %d is not a TileSetAtlasSource (got %s)" % [source_id, source_type]
		)

	var tiles: Array = []
	for i in range(src.get_tiles_count()):
		var v: Vector2i = src.get_tile_id(i)
		tiles.append({"col": v.x, "row": v.y})

	return {"data": {"tiles": tiles, "count": tiles.size()}}


## Return the atlas texture of a TileSetAtlasSource as a Base64-encoded PNG.
##
## params:
##   tileset_path  — res:// path to the TileSet resource (required, non-empty)
##   source_id     — integer index of the source within the TileSet (required)
##   max_size      — optional int; if > 0, the image is scaled so its longest
##                   edge is at most max_size pixels (default 0 = full res)
##
## Returns:
##   {"data": {"image_base64": String, "width": int, "height": int,
##             "original_width": int, "original_height": int, "format": "png"}}
##     on success
##   ErrorCodes.make(code, message)  on any validation or load failure
##
## Error codes:
##   MISSING_REQUIRED_PARAM  — tileset_path absent/empty, or source_id absent
##   RESOURCE_NOT_FOUND      — ResourceLoader.exists(tileset_path) is false
##   WRONG_TYPE              — loaded resource is not a TileSet, or source is
##                             not a TileSetAtlasSource, or texture is null
##   VALUE_OUT_OF_RANGE      — source_id < 0 or >= TileSet.get_source_count()
##
## This method is read-only: it never calls ResourceSaver or modifies anything.
func get_atlas_image(params: Dictionary) -> Dictionary:
	var tileset_path: String = params.get("tileset_path", "")
	if tileset_path.is_empty():
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM,
			"'tileset_path' parameter is required and must not be empty"
		)

	if not params.has("source_id"):
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM,
			"'source_id' parameter is required"
		)

	if not ResourceLoader.exists(tileset_path):
		return ErrorCodes.make(
			ErrorCodes.RESOURCE_NOT_FOUND,
			"TileSet resource not found: %s" % tileset_path
		)

	var ts = load(tileset_path)
	if not ts is TileSet:
		var loaded_type := "null" if ts == null else ts.get_class()
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE,
			"Resource at '%s' is not a TileSet (got %s)" % [tileset_path, loaded_type]
		)

	var source_index: int = params.get("source_id", -999)
	if source_index < 0 or source_index >= ts.get_source_count():
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE,
			"source_id %d is out of range (TileSet has %d sources)" % [source_index, ts.get_source_count()]
		)

	var source_id: int = ts.get_source_id(source_index)
	var src = ts.get_source(source_id)
	if not src is TileSetAtlasSource:
		var source_type := "null" if src == null else src.get_class()
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE,
			"Source %d is not a TileSetAtlasSource (got %s)" % [source_id, source_type]
		)

	var tex: Texture2D = src.texture
	if tex == null:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE,
			"Source %d has no texture assigned" % source_id
		)

	var img: Image = tex.get_image()
	if img == null:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE,
			"Could not retrieve image data from texture of source %d" % source_id
		)

	var original_width: int = img.get_width()
	var original_height: int = img.get_height()

	var max_size: int = params.get("max_size", 0)
	if max_size > 0:
		var longest_edge: int = max(original_width, original_height)
		if longest_edge > max_size:
			var scale: float = float(max_size) / float(longest_edge)
			var new_w: int = max(1, int(original_width * scale))
			var new_h: int = max(1, int(original_height * scale))
			img = img.duplicate()
			img.resize(new_w, new_h, Image.INTERPOLATE_BILINEAR)

	var png_bytes: PackedByteArray = img.save_png_to_buffer()
	var b64: String = Marshalls.raw_to_base64(png_bytes)

	return {
		"data": {
			"image_base64": b64,
			"width": img.get_width(),
			"height": img.get_height(),
			"original_width": original_width,
			"original_height": original_height,
			"format": "png",
		}
	}
