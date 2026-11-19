extends Node

## Small global audio service. It owns exactly one thing: the soundtrack and
## the flat (non-positional) SFX pool. World sounds are spawned by the nodes
## that make them, which keeps positional audio tied to the scene.

signal volumes_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const MUSIC_PATH: String = "res://assets/audio/ambient_space.ogg"
const SFX_PATHS: Dictionary[String, String] = {
	"footstep_1": "res://assets/audio/footstep_1.wav",
	"footstep_2": "res://assets/audio/footstep_2.wav",
	"jump": "res://assets/audio/jump.wav",
	"land": "res://assets/audio/land.wav",
	"catch": "res://assets/audio/catch.wav",
	"smear": "res://assets/audio/smear.wav",
	"grow": "res://assets/audio/grow.wav",
	"whoosh": "res://assets/audio/whoosh.wav",
	"stake_plant": "res://assets/audio/stake_plant.wav",
	"stake_pull": "res://assets/audio/stake_pull.wav",
	"ping": "res://assets/audio/ping.wav",
	"freeze": "res://assets/audio/freeze.wav",
	"ui_click": "res://assets/audio/ui_click.wav",
	"wind": "res://assets/audio/wind.wav",
	"sprout": "res://assets/audio/sprout.wav",
	"mature": "res://assets/audio/mature.wav",
	"water_pour": "res://assets/audio/water_pour.wav",
	"spit": "res://assets/audio/spit.wav",
	"acid_hit": "res://assets/audio/acid_hit.wav",
	"death_caterpillar": "res://assets/audio/death_caterpillar.wav",
	"death_hydralisk": "res://assets/audio/death_hydralisk.wav",
	"death_ragnos": "res://assets/audio/death_ragnos.wav",
	"death_zodd": "res://assets/audio/death_zodd.wav",
}
const SFX_POOL_SIZE: int = 8

var music_volume: float = 0.62
var sfx_volume: float = 0.82

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _streams: Dictionary[String, AudioStream] = {}
var _next_player: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_players()
	_load_streams()
	if DisplayServer.get_name() != "headless":
		play_music()


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null
	for player: AudioStreamPlayer in _pool:
		player.stop()
		player.stream = null
	_streams.clear()


func _build_players() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)
	_apply_volumes()


func _load_streams() -> void:
	for key: String in SFX_PATHS.keys():
		var stream: AudioStream = load(SFX_PATHS[key]) as AudioStream
		if stream != null:
			_streams[key] = stream


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)


func _apply_volumes() -> void:
	if _music != null:
		_music.volume_db = _linear_to_db(music_volume)
	for player: AudioStreamPlayer in _pool:
		player.volume_db = _linear_to_db(sfx_volume)


func _linear_to_db(value: float) -> float:
	if value <= 0.0001:
		return -80.0
	return linear_to_db(value)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()
	volumes_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()
	volumes_changed.emit()


func play_music() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _music == null:
		return
	if _music.stream == null:
		var stream: AudioStream = load(MUSIC_PATH) as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_music.stream = stream
	if not _music.playing:
		_music.play()


func play_sfx(key: String, pitch_jitter: float = 0.0, extra_db: float = 0.0) -> void:
	if not _streams.has(key) or _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	player.stream = _streams[key]
	player.volume_db = _linear_to_db(sfx_volume) + extra_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func play_sfx_3d(
	key: String, position: Vector3, parent: Node, extra_db: float = 0.0, unit_size: float = 7.0
) -> AudioStreamPlayer3D:
	if not _streams.has(key) or parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = _streams[key]
	player.volume_db = _linear_to_db(sfx_volume) + extra_db
	player.unit_size = unit_size
	player.max_distance = 90.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	return player
