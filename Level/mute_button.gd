extends Button
## Each menu owns its connection, so closing a menu releases it immediately.

func _ready() -> void:
	var session: Node = get_node("/root/ReleaseSession")
	session.mute_changed.connect(_update_caption)
	_update_caption(session.muted)

func _update_caption(muted: bool) -> void:
	text = "Unmute" if muted else "Mute"
