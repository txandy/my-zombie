# Tests de integración del WorldBuilder: lo construido coincide con WorldData.
extends GdUnitTestSuite

const FIXTURE_PATH: String = "res://tests/world/generation/fixtures/hash_fixture_settings.tres"

var _settings: WorldGenSettings
var _data: WorldData
var _builder: WorldBuilder


func before() -> void:
	_settings = load(FIXTURE_PATH) as WorldGenSettings
	_data = WorldGenerator.generate(12345, _settings)
	_builder = WorldBuilder.new()
	add_child(_builder)
	_builder.build(_data, _settings)


func after() -> void:
	_builder.free()


func test_builds_one_node_per_poi() -> void:
	var pois: Node = _builder.get_node("POIs")
	assert_int(pois.get_child_count()).is_equal(_data.pois.size())
	for i: int in _data.pois.size():
		var node: Node3D = pois.get_child(i) as Node3D
		assert_vector(node.position).is_equal_approx(_data.pois[i].position, Vector3.ONE * 0.001)


func test_multimesh_instances_match_vegetation() -> void:
	var per_layer: Dictionary[StringName, int] = {}
	for child: Node in _builder.get_node("Vegetation").get_children():
		var mmi: MultiMeshInstance3D = child as MultiMeshInstance3D
		var layer_id: StringName = StringName(String(mmi.name).get_slice("_", 0))
		per_layer[layer_id] = per_layer.get(layer_id, 0) + mmi.multimesh.instance_count
	for l: int in _settings.vegetation_layers.size():
		var expected: int = _data.vegetation[l].size() / VegetationPhase.STRIDE
		assert_int(per_layer.get(_settings.vegetation_layers[l].id, 0)).is_equal(expected)


func test_terrain_heights_match_data() -> void:
	for poi: PoiPlacement in _data.pois:
		var h: float = _builder.terrain.data.get_height(poi.position)
		assert_float(h).is_equal_approx(poi.position.y, 0.01)


func test_biome_color_image_size() -> void:
	var image: Image = WorldBuilder.biome_color_image(_data, _settings)
	assert_int(image.get_width()).is_equal(_data.resolution)
	assert_int(image.get_height()).is_equal(_data.resolution)
