extends TestCase

## CameraDirector : base, plans, fin d'une séquence et d'une cinématique,
## priorités, coupure, zoom entier.

var _camera: Camera2D
var _director: CameraDirector


func before_each() -> void:
	_camera = add_test_node(Camera2D.new()) as Camera2D
	_director = CameraDirector.new()
	_camera.add_child(_director)
	_director.set_base(Vector2(100.0, 50.0), Vector2.ONE)


func _sequence(frames: Array[Rect2], hold: float, cutscene: bool = false) -> CameraSequence:
	var sequence: CameraSequence = CameraSequence.new()
	for frame: Rect2 in frames:
		sequence.shots.append(CameraShot.make(frame, 0.0, hold))
	sequence.takes_control = cutscene
	sequence.release_time = 0.0
	return sequence


func test_base_applied_when_idle() -> void:
	assert_eq(_camera.position, Vector2(100.0, 50.0))
	_director.set_base(Vector2(10.0, 20.0), Vector2(2.0, 2.0))
	assert_eq(_camera.position, Vector2(10.0, 20.0))
	assert_eq(_camera.zoom, Vector2(2.0, 2.0))


func test_finds_director_of_camera() -> void:
	assert_eq(CameraDirector.of(_camera), _director)
	assert_null(CameraDirector.of(null))


func test_sequence_holds_last_shot_until_stopped() -> void:
	var frame: Rect2 = Rect2(400.0, 300.0, 200.0, 100.0)
	var sequence: CameraSequence = _sequence([frame], 0.0)
	assert_true(_director.play(sequence))
	assert_eq(_camera.position, frame.get_center(), "on the shot at once (blend 0)")
	assert_eq(_camera.zoom, _director.view_for(frame)["zoom"])
	await seconds(0.5)
	assert_true(_director.is_playing(sequence), "hold 0 on the last shot: stays")
	assert_false(_director.play(sequence), "already playing")
	_director.stop(sequence)
	assert_false(_director.is_playing(sequence))
	assert_eq(_camera.position, Vector2(100.0, 50.0), "back to base")


func test_shots_advance_and_sequence_ends() -> void:
	var first: Rect2 = Rect2(0.0, 0.0, 100.0, 100.0)
	var second: Rect2 = Rect2(500.0, 0.0, 100.0, 100.0)
	var sequence: CameraSequence = _sequence([first, second], 0.1)
	var shots: Array[int] = []
	_director.shot_changed.connect(func(_s: CameraSequence, index: int) -> void: shots.append(index))
	_director.play(sequence)
	assert_true(await until(func() -> bool: return not _director.is_playing(sequence), 2.0), "ends after its holds")
	assert_eq(shots, [0, 1] as Array[int])
	assert_eq(_camera.position, Vector2(100.0, 50.0))


func test_cutscene_takes_and_gives_back_control() -> void:
	var changes: Array[bool] = []
	_director.control_changed.connect(func(taken: bool) -> void: changes.append(taken))
	var cutscene: CameraSequence = _sequence([Rect2(0.0, 0.0, 50.0, 50.0)], 0.0, true)
	_director.play(cutscene)
	assert_true(_director.is_control_taken())
	assert_true(await until(func() -> bool: return not _director.is_playing(cutscene), 1.0), "a cutscene always ends, even with hold 0")
	assert_false(_director.is_control_taken())
	assert_eq(changes, [true, false] as Array[bool])


func test_higher_priority_leads_then_hands_back() -> void:
	var low_frame: Rect2 = Rect2(0.0, 0.0, 100.0, 100.0)
	var high_frame: Rect2 = Rect2(900.0, 0.0, 100.0, 100.0)
	var low: CameraSequence = _sequence([low_frame], 0.0)
	var high: CameraSequence = _sequence([high_frame], 0.0)
	high.priority = 1
	_director.play(high)
	_director.play(low)
	assert_eq(_director.leading(), high, "priority wins over arrival")
	assert_eq(_camera.position, high_frame.get_center())
	_director.stop(high)
	assert_eq(_director.leading(), low)
	assert_eq(_camera.position, low_frame.get_center(), "the waiting one resumes")


func test_disabled_refuses_play() -> void:
	_director.enabled = false
	assert_false(_director.play(_sequence([Rect2(0.0, 0.0, 10.0, 10.0)], 0.0)))
	assert_false(_director.play(CameraSequence.new()), "empty sequence")


func test_refuses_3d_shots() -> void:
	var sequence: CameraSequence = _sequence([Rect2(0.0, 0.0, 10.0, 10.0)], 0.0)
	sequence.shots.append(CameraShot3D.make(Transform3D.IDENTITY, 60.0, 0.0, 0.0))
	assert_false(_director.play(sequence), "a 2D director cannot play a 3D shot")
	assert_false(_director.is_playing(sequence))


func test_joins_the_directors_group() -> void:
	assert_true(_director.is_in_group(CameraDirectorBase.GROUP))
	assert_has(CameraDebug.directors(_director.get_tree()), _director)


func test_integer_zoom_rounds_down() -> void:
	var view: Vector2 = _camera.get_viewport_rect().size
	var frame: Rect2 = Rect2(Vector2.ZERO, view / 2.5)
	assert_almost(_director.view_for(frame)["zoom"].x, 2.5, 0.001)
	_director.integer_zoom = true
	assert_eq(_director.view_for(frame)["zoom"], Vector2(2.0, 2.0))
	var wide: Rect2 = Rect2(Vector2.ZERO, view * 2.0)
	assert_almost(_director.view_for(wide)["zoom"].x, 0.5, 0.001, "under 1: kept")


func test_stop_all_snaps_back() -> void:
	var cutscene: CameraSequence = _sequence([Rect2(0.0, 0.0, 50.0, 50.0)], 5.0, true)
	cutscene.release_time = 2.0
	_director.play(cutscene)
	_director.play(_sequence([Rect2(0.0, 0.0, 80.0, 80.0)], 0.0))
	_director.stop_all()
	assert_true(_director.active().is_empty())
	assert_false(_director.is_control_taken())
	assert_eq(_camera.position, Vector2(100.0, 50.0))
	assert_eq(_director.describe(), "base")


func test_blend_moves_over_time() -> void:
	var frame: Rect2 = Rect2(1000.0, 0.0, 100.0, 100.0)
	var sequence: CameraSequence = CameraSequence.new()
	sequence.shots.append(CameraShot.make(frame, 0.3, 0.0))
	_director.play(sequence)
	assert_eq(_camera.position, Vector2(100.0, 50.0), "starts where it was")
	assert_true(await until(func() -> bool: return _camera.position.is_equal_approx(frame.get_center()), 1.0), "arrives after the blend")
