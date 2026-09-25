# Tests de los autoloads del core: autoridad del host, sesión y rutas de guardado.
extends GdUnitTestSuite

const TEST_PORT: int = 24670


func after_test() -> void:
	GameState.end_session()
	NetManager.close()


func test_autoloads_are_registered() -> void:
	for autoload_name: String in ["EventBus", "NetManager", "GameState", "SaveSystem"]:
		assert_bool(get_tree().root.has_node(autoload_name)).override_failure_message(
			"Falta el autoload '%s'" % autoload_name).is_true()


func test_single_player_is_host() -> void:
	NetManager.start_single_player()
	assert_bool(NetManager.is_host()).is_true()
	assert_int(multiplayer.get_unique_id()).is_equal(NetManager.HOST_PEER_ID)


func test_listen_server_is_host() -> void:
	assert_int(NetManager.host(TEST_PORT)).is_equal(OK)
	assert_bool(NetManager.is_host()).is_true()


func test_client_is_not_host() -> void:
	assert_int(NetManager.join("127.0.0.1", TEST_PORT + 1)).is_equal(OK)
	assert_bool(NetManager.is_host()).is_false()


func test_host_starts_session_and_emits_signal() -> void:
	NetManager.start_single_player()
	var monitor := monitor_signals(EventBus, false)
	assert_bool(GameState.start_session(1234)).is_true()
	assert_int(GameState.world_seed).is_equal(1234)
	assert_bool(GameState.is_session_active).is_true()
	await assert_signal(monitor).is_emitted("session_started", [1234])


func test_client_cannot_start_session() -> void:
	NetManager.join("127.0.0.1", TEST_PORT + 2)
	assert_bool(GameState.start_session(1234)).is_false()
	assert_bool(GameState.is_session_active).is_false()


func test_random_world_seed_varies() -> void:
	assert_int(GameState.random_world_seed()).is_not_equal(GameState.random_world_seed())


func test_save_dir_is_sanitized() -> void:
	assert_str(SaveSystem.get_save_dir("Mi partida")).is_equal("user://saves/Mi partida")
	assert_str(SaveSystem.get_save_dir("a/b:c")).is_equal("user://saves/a_b_c")
	assert_str(SaveSystem.get_save_dir("   ")).is_equal("user://saves/unnamed")
