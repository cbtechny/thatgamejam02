extends Control

func _ready() -> void:
	get_tree().paused = false
	theme = preload("res://Level/music_box_theme.gd").create()
	var background := TextureRect.new()
	background.texture = preload("res://Art/Textures/T_Boxexterior.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.35, 0.4, 0.55)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var label := Label.new()
	label.text = "THE MUSIC BOX REMEMBERS\n\nAcross the tide, through the night.\nEvery piece has found its way home.\n\nLilith — Writing, concept, hand-drawn art\nGitHub: https://github.com/Anthropo7874 | itch.io: https://anthrop0.itch.io/ | Threads: @uanranu\n\nChris (Ninja Pirate Robot Alien) — Programming and technical setup\nGitHub: https://github.com/cbtechny | itch.io: https://ninjapiraterobotalien.itch.io/\n\nPacky — Production, coordination, technical art, animation\nGitHub: https://github.com/n374500601\nTheme music composed by Jason Grace.\n\nThank you for playing."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	column.add_child(label)
	var menu := preload("res://Level/campaign_menu.gd").new()
	add_child(menu)
	var session: Node = get_node("/root/ReleaseSession")
	menu.completed = true
	var restart: Button = menu.add_button(column, "Play Again", func(): menu.go("res://Level/level_1_music_box.tscn"))
	menu.add_button(column, "Return to Title", func(): menu.go("res://Level/title_menu.tscn"))
	var credits: Button = menu.add_button(column, "Full Credits", func(): menu.show_information("Credits", session.CREDITS, restart))
	credits.name = "CreditsButton"
	menu.add_release_controls(column)
	restart.grab_focus()
