class_name MainMenu
extends CanvasLayer
var game: Node3D
var root: Control
var content: VBoxContainer
var faction := 0
var short_match := false
func setup(g: Node3D) -> void:
	game=g
	root=Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.035,0.055,0.06,0.86)
	content=VBoxContainer.new(); root.add_child(content)
	content.position=Vector2(90,65); content.size=Vector2(570,580)
	content.add_theme_constant_override("separation",14)
	show_main()
func clear() -> void:
	for c in content.get_children(): content.remove_child(c); c.queue_free()
	root.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func text(s: String, size := 20) -> Label:
	var l := Label.new(); l.text=s; l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("e1cfa8")); content.add_child(l)
	return l
func button(s: String, action: Callable) -> Button:
	var b := Button.new(); b.text=s; b.custom_minimum_size=Vector2(450,48)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size",19)
	b.pressed.connect(action); content.add_child(b)
	return b
func show_main() -> void:
	clear()
	text("ASHIGARU   /   PLAYABLE FOUNDATION",15)
	text("SAMURAI\nWITH MUSKETS",58)
	text("One shot. Five seconds. Close the distance.",21)
	text("COURTYARD OF ASH\nA fictional clash of powder and steel.",17)
	button("PLAY  →",show_factions)
	button("SETTINGS",show_settings)
	button("QUIT",func(): game.get_tree().quit())
	text("WASD move  ·  Mouse aim  ·  Q switch weapons\nOriginal prototype environments and audio. Supplied weapon art.",14)
func show_factions() -> void:
	clear(); text("CHOOSE YOUR SIDE",36)
	text("Identical equipment and health. Different allegiances.",17)
	button("SAMURAI  /  Lacquered armor",func(): faction=0; show_deploy())
	button("RŌNIN  /  Black cloth",func(): faction=1; show_deploy())
	button("BACK",show_main)
func show_deploy() -> void:
	clear(); text("SAMURAI" if faction==0 else "RŌNIN",42)
	text("4 versus 4  ·  100 health\nMusket: one shot, 5-second reload\nKatana: two cuts to defeat an enemy\nRespawn: 3 seconds",21)
	button("MATCH: "+("QUICK  /  5 kills · 90 seconds" if short_match else "STANDARD  /  20 kills · 4 minutes"),func(): short_match=not short_match; show_deploy())
	button("ENTER THE COURTYARD  →",func(): root.hide(); game.start_match(faction,short_match))
	button("BACK",show_factions)
func show_settings() -> void:
	clear(); text("SETTINGS",38)
	text("Mouse sensitivity",20)
	var sensitivity := HSlider.new(); sensitivity.min_value=0.5; sensitivity.max_value=3; sensitivity.step=0.1; sensitivity.value=game.sensitivity*1000
	sensitivity.value_changed.connect(func(v): game.sensitivity=v/1000; game.save_settings())
	content.add_child(sensitivity)
	text("Sound volume",20)
	var volume := HSlider.new(); volume.min_value=0; volume.max_value=1; volume.step=0.05; volume.value=game.sounds.volume
	volume.value_changed.connect(func(v): game.sounds.volume=v; game.save_settings())
	content.add_child(volume)
	button("FULLSCREEN  /  TOGGLE",func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	button("BACK",show_main)
func show_pause() -> void:
	clear(); text("HOLD FIRE",42)
	text("The match is paused.",20)
	button("RESUME",func(): root.hide(); game.set_paused(false))
	button("RESTART MATCH",func(): root.hide(); game.start_match(game.player.team,short_match))
	button("RETURN TO MENU",func(): game.return_menu())
func show_results() -> void:
	clear()
	var s: Array=game.match_state.scores
	text("MATCH COMPLETE",18)
	text("DRAW" if s[0]==s[1] else ("SAMURAI VICTORY" if s[0]>s[1] else "RŌNIN VICTORY"),38)
	text("SAMURAI  %d    /    RŌNIN  %d" % [s[0],s[1]],27)
	text("Your kills: %d  ·  Deaths: %d" % [game.player_kills,game.player_deaths],20)
	button("FIGHT AGAIN  →",func(): root.hide(); game.start_match(game.player.team,short_match))
	button("RETURN TO MENU",func(): game.return_menu())
