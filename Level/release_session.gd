extends Node
## One recording and one mute setting for the entire application session.

const THEME: AudioStream = preload("res://dev/winder_test_1_time_scroll/assets/thatgamejam_theme_mp3_medium_audio_track.mp3")
const CREDITS: String = "Lilith — Writing, concept, hand-drawn art\nGitHub: https://github.com/Anthropo7874\nitch.io: https://anthrop0.itch.io/\nThreads: @uanranu\n\nChris (Ninja Pirate Robot Alien) — Programming and technical setup\nGitHub: https://github.com/cbtechny\nitch.io: https://ninjapiraterobotalien.itch.io/\n\nPacky — Production, coordination, technical art, animation\nGitHub: https://github.com/n374500601\n\nTheme music composed by Jason Grace.\nProvided recording used unmodified for thatgamejam #02\n\nPainted background ornament cutouts: AI-assisted edits\nof contributor-supplied hand-painted artwork.\n\nMade with Godot Engine (MIT license)\ngodotengine.org/license"
const CONTROLS: String = "LEVEL 1 — THE KEY\nDrag the glowing crank to lift the key. Press Space to release it into the fan. Time the release to meet the moving piece: the pieces join automatically when their ends touch. If you miss, press R to restart with a quick fade.\n\nLEVELS 2 & 3 — THE TIDE\nDrag the crank to set the tide. Press Space or click Fire fan to launch from the current platform. Time each shot so the drifting board meets the key when it lands. Cross the pier by day and the breakwater by night; watch the independent lighthouse sweep.\n\nA missed landing ends the run: press R or choose Retry from shore.\n\nEsc: pause / resume   •   Tab / arrows: menu focus\nEnter: choose focused button   •   Mute: all game audio"

signal mute_changed(muted: bool)

var muted: bool = false
var music: AudioStreamPlayer
var _quitting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	music = AudioStreamPlayer.new()
	music.name = "JamTheme"
	music.stream = THEME
	music.volume_db = -16.0
	music.finished.connect(music.play)
	add_child(music)
	music.play()

func _process(_delta: float) -> void:
	# Keep the playhead across scenes; pause never starts a second player.
	if not _quitting:
		music.stream_paused = get_tree().paused

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	mute_changed.emit(muted)

func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	music.stop()
	music.stream = null
	get_tree().paused = false
	# Let the mixer release the MP3 playback before tearing down the engine.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
