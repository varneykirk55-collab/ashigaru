class_name HUD
extends CanvasLayer
var game: Node3D
var root: Control
var status: Label
var score: Label
var prompt: Label
var feed: Label
var hit: Label
var reload_bar: ProgressBar
var damage_overlay: ColorRect
var confirmation: Label
var confirm_text := ""
var hurt := 0.0
var hit_time := 0.0
var feed_time := 0.0
func setup(g: Node3D) -> void:
	game=g
	root=Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.hide(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	damage_overlay=ColorRect.new(); root.add_child(damage_overlay)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	score=label("",26,Vector2(390,26),Vector2(500,60)); score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label("PALACE OF ASH  /  TEAM DEATHMATCH",13,Vector2(40,30),Vector2(340,30))
	status=label("",23,Vector2(40,620),Vector2(600,80))
	prompt=label("",20,Vector2(390,510),Vector2(500,70)); prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	confirmation=label("",18,Vector2(440,398),Vector2(400,38)); confirmation.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	feed=label("",17,Vector2(870,105),Vector2(370,90)); feed.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hit=label("+",28,Vector2(620,337),Vector2(40,40)); hit.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label("WASD MOVE   SHIFT SPRINT   CAPS AUTO-SPRINT   CTRL CROUCH\nSPACE JUMP   LMB ATTACK   RMB AIM\nR RELOAD   Q / WHEEL SWITCH   ESC PAUSE",13,Vector2(675,634),Vector2(580,65))
	reload_bar=ProgressBar.new(); root.add_child(reload_bar)
	reload_bar.position=Vector2(40,606); reload_bar.size=Vector2(300,5); reload_bar.show_percentage=false; reload_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
func label(text: String, size: int, pos: Vector2, extent: Vector2) -> Label:
	var l := Label.new(); root.add_child(l)
	l.text=text; l.position=pos; l.size=extent; l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	l.add_theme_constant_override("shadow_offset_x",1)
	l.add_theme_constant_override("shadow_offset_y",2)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("e5dac1"))
	return l
func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		root.hide(); return
	root.visible=game.match_state.active and not game.paused
	if not root.visible: return
	var p: PlayerController=game.player
	var m: Musket=p.weapons.musket
	score.text="%02d   SAMURAI     /     RŌNIN   %02d\n%02d:%02d  ·  FIRST TO %d" % [game.match_state.scores[0],game.match_state.scores[1],int(game.match_state.time_left)/60,int(game.match_state.time_left)%60,game.match_state.score_limit]
	status.text="%03d  HEALTH     /     %s\n%s" % [int(p.health.value),"SAMURAI" if p.team==0 else "RŌNIN",("MUSKET    %d / %d" % [1 if m.loaded else 0,m.reserve]) if p.weapons.selected==0 else "KATANA    /    CLOSE QUARTERS"]
	reload_bar.visible=m.remaining>0
	reload_bar.value=(1-m.remaining/Musket.RELOAD_TIME)*100
	prompt.text="RESPAWNING IN %d" % ceili(p.dead_time) if p.health.value<=0 else ("RELOADING  %.1fs" % m.remaining if m.remaining>0 else ("R  ·  RELOAD" if not m.loaded and m.reserve>0 else ("OUT OF POWDER  ·  Q FOR KATANA" if m.reserve==0 and not m.loaded else "")))
	if p.health.protection>0 and p.health.value>0: prompt.text="SPAWN SHIELD %.1fs · FIRING ENDS PROTECTION" % p.health.protection
	hurt=maxf(0,hurt-delta); hit_time=maxf(0,hit_time-delta);
	confirmation.text=confirm_text if hit_time>0 else ""
	feed_time=maxf(0,feed_time-delta)
	damage_overlay.color=Color(0.55,0.05,0.02,hurt*0.6)
	hit.text="◇" if "HEADSHOT" in confirm_text and hit_time>0 else ("×" if hit_time>0 else "+")
	hit.modulate=Color("e4a45d") if hit_time>0 else Color(1,1,1,0.65*(1-p.weapons.viewmodel.ads))
	feed.visible=feed_time>0
func message(text: String) -> void:
	feed.text=text; feed_time=4

func confirm(kind: String) -> void:
	confirm_text=kind
	hit_time=0.7 if "KILL" in kind else 0.35
