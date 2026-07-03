@tool
extends McpTestSuite

const ErrorCodes := preload("res://addons/godot_ai/utils/error_codes.gd")
const TilemapHandler := preload("res://addons/godot_ai/handlers/tilemap_handler.gd")
const TilesetHandler := preload("res://addons/godot_ai/handlers/tileset_handler.gd")

var _tilemap_handler: TilemapHandler
var _tileset_handler: TilesetHandler
var _undo_redo: EditorUndoRedoManager
var _created_nodes: Array[Node] = []
var _created_files: Array[String] = []
var _created_dirs: Array[String] = []


func suite_name() -> String:
	return "tilemap"


func suite_setup(ctx: Dictionary) -> void:
	_undo_redo = ctx.get("undo_redo")
	_tilemap_handler = TilemapHandler.new(_undo_redo)
	_tileset_handler = TilesetHandler.new()


func teardown() -> void:
	_cleanup_runtime_artifacts()


func suite_teardown() -> void:
	_cleanup_runtime_artifacts()


func _cleanup_runtime_artifacts() -> void:
	for node in _created_nodes:
		if is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.queue_free()
	_created_nodes.clear()

	for path in _created_files:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
		var uid_path := abs_path + ".uid"
		if FileAccess.file_exists(uid_path):
			DirAccess.remove_absolute(uid_path)
	_created_files.clear()

	for i in range(_created_dirs.size() - 1, -1, -1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_created_dirs[i]))
	_created_dirs.clear()


func _make_test_tileset() -> TileSet:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(1, 1)
	src.create_tile(Vector2i.ZERO)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(1, 1)
	ts.add_source(src, 0)
	return ts


func _create_layer(name: String) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return {}
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = _make_test_tileset()
	scene_root.add_child(layer)
	_created_nodes.append(layer)
	return {
		"layer": layer,
		"path": McpScenePath.from_node(layer, scene_root),
	}


func test_tilemap_set_and_get_cells() -> void:
	var ctx := _create_layer("_McpTileLayerA")
	if ctx.is_empty():
		skip("No scene open")
		return
	var path: String = ctx.path

	var result := _tilemap_handler.set_cell({
		"path": path,
		"source_id": 0,
		"atlas_col": 0,
		"atlas_row": 0,
		"map_x": 2,
		"map_y": 3,
	})
	assert_has_key(result, "data")
	assert_true(result.data.undoable)

	var cells := _tilemap_handler.get_used_cells({"path": path})
	assert_has_key(cells, "data")
	assert_eq(cells.data.count, 1)
	assert_eq(cells.data.cells[0].x, 2)
	assert_eq(cells.data.cells[0].y, 3)


func test_tilemap_clear_is_undoable() -> void:
	var ctx := _create_layer("_McpTileLayerB")
	if ctx.is_empty():
		skip("No scene open")
		return
	var path: String = ctx.path

	var a := _tilemap_handler.set_cell({
		"path": path,
		"source_id": 0,
		"atlas_col": 0,
		"atlas_row": 0,
		"map_x": 0,
		"map_y": 0,
	})
	var b := _tilemap_handler.set_cell({
		"path": path,
		"source_id": 0,
		"atlas_col": 0,
		"atlas_row": 0,
		"map_x": 1,
		"map_y": 1,
	})
	assert_has_key(a, "data")
	assert_has_key(b, "data")
	assert_true(a.data.undoable)
	assert_true(b.data.undoable)

	var cleared := _tilemap_handler.clear_layer({"path": path})
	assert_has_key(cleared, "data")
	assert_true(cleared.data.cleared)
	assert_true(cleared.data.undoable)

	var after_clear := _tilemap_handler.get_used_cells({"path": path})
	assert_eq(after_clear.data.count, 0)

	var did_undo := editor_undo(_undo_redo)
	assert_true(did_undo, "undo should succeed")
	var restored := _tilemap_handler.get_used_cells({"path": path})
	assert_eq(restored.data.count, 2)


func test_tileset_generate_specialized_with_root_dir() -> void:
	var root_dir := "res://tests/_mcp_tileset"
	var biom := "volcano"
	var biom_dir := "%s/%s" % [root_dir, biom]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(biom_dir))
	_created_dirs.append(biom_dir)
	_created_dirs.append(root_dir)

	var main_path := "%s/%s.tres" % [biom_dir, biom]
	var save_err := ResourceSaver.save(_make_test_tileset(), main_path)
	assert_eq(save_err, OK)
	_created_files.append(main_path)

	var generated := _tileset_handler.generate_specialized_tilesets({
		"biom": biom,
		"root_dir": root_dir,
		"layer_sources": {"floor": [0]},
	})
	assert_has_key(generated, "data")
	assert_eq(generated.data.created.size(), 1)
	var expected_output := "%s/%s_floor.tres" % [biom_dir, biom]
	assert_contains(generated.data.created, expected_output)
	assert_true(ResourceLoader.exists(expected_output), "specialized .tres should be written")
	_created_files.append(expected_output)

	var rerun := _tileset_handler.generate_specialized_tilesets({
		"biom": biom,
		"root_dir": root_dir,
		"layer_sources": {"floor": [0]},
	})
	assert_has_key(rerun, "data")
	assert_contains(rerun.data.skipped, expected_output)
