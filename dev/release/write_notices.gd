extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write engine notices")
		quit(1)
		return
	output.store_string("Godot Engine license\n\n" + Engine.get_license_text())
	output.store_string("\n\nThird-party copyright notices\n\n" + JSON.stringify(Engine.get_copyright_info(), "\t"))
	output.store_string("\n\nThird-party license texts\n\n" + JSON.stringify(Engine.get_license_info(), "\t"))
	output.close()
	quit()
