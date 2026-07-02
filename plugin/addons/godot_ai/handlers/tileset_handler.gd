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
