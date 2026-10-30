extends Node2D
## Manual collision and controller-isolation sandbox; not a level progression system.

@onready var _key_1: WindingObjectController = $WindingKey1
@onready var _key_2: WindingObjectController = $WindingKey2
@onready var _barrier: StaticBody2D = $Barrier
@onready var _barrier_label: Label = $HUD/BarrierStatus
@onready var _key_1_button: Button = $HUD/Key1Button
@onready var _key_2_button: Button = $HUD/Key2Button
@onready var _winding_amount: HSlider = $HUD/WindingAmount
@onready var _amount_label: Label = $HUD/AmountLabel

var _barrier_enabled: bool = true


func _ready() -> void:
	_key_1_button.pressed.connect(_release_key.bind(_key_1))
	_key_2_button.pressed.connect(_release_key.bind(_key_2))
	$HUD/BarrierButton.pressed.connect(_toggle_barrier)
	$HUD/ResetButton.pressed.connect(_reset_test)
	_key_1.phase_changed.connect(_update_key_buttons)
	_key_2.phase_changed.connect(_update_key_buttons)
	_update_key_buttons()
	_update_barrier()


func _process(_delta: float) -> void:
	_update_key_buttons()
	_amount_label.text = "WIND: %d / 270 DEG" % roundi(_winding_amount.value)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			_release_key(_key_1)
		KEY_2:
			_release_key(_key_2)
		KEY_SPACE:
			_toggle_barrier()
		KEY_R:
			_reset_test()


func _release_key(key: WindingObjectController) -> void:
	key.start_motion(_winding_amount.value / WinderDrag.MAX_WINDING_DEGREES)


func _toggle_barrier() -> void:
	_barrier_enabled = not _barrier_enabled
	_update_barrier()


func _reset_test() -> void:
	_key_1.reset_objects()
	_key_2.reset_objects()
	_barrier_enabled = true
	_update_barrier()


func _update_key_buttons(_phase: int = 0) -> void:
	_update_key_button(_key_1_button, _key_1, 1)
	_update_key_button(_key_2_button, _key_2, 2)


func _update_key_button(button: Button, key: WindingObjectController, number: int) -> void:
	button.disabled = key.phase != WindingObjectController.MotionPhase.IDLE
	match key.phase:
		WindingObjectController.MotionPhase.MOVING:
			button.text = "%d   Unwinding" % number
		WindingObjectController.MotionPhase.COOLDOWN:
			button.text = "%d   Wait %.1f s" % [number, key.get_cooldown_remaining()]
		_:
			button.text = "%d   Release Key %d" % [number, number]


func _update_barrier() -> void:
	_barrier.collision_layer = 1 if _barrier_enabled else 0
	_barrier.modulate.a = 1.0 if _barrier_enabled else 0.15
	_barrier_label.text = "BARRIER CLOSED" if _barrier_enabled else "BARRIER OPEN"
