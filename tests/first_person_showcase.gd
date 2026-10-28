extends SceneTree
## Deterministic staged demonstration recorded by Godot's Movie Maker, not a live FPS benchmark.
var game: Node3D
var caption: Label
var frame := 0
func _initialize(): call_deferred("run")
func run():
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 await process_frame; game.start_match(0)
 for actor in game.actors: actor.set_physics_process(false); actor.position=Vector3(50,0.05,50)
 var p: PlayerController=game.player
 p.position=Vector3(0,0.05,26); p.rotation=Vector3.ZERO; p.camera.rotation=Vector3.ZERO
 game.hud.set_process(false); game.hud.root.hide()
 var layer := CanvasLayer.new(); root.add_child(layer); layer.layer=4
 caption=Label.new(); layer.add_child(caption); caption.position=Vector2(32,28); caption.add_theme_font_size_override("font_size",21); caption.add_theme_constant_override("shadow_offset_x",2); caption.add_theme_constant_override("shadow_offset_y",2)
 caption.text="ASHIGARU / FIRST-PERSON COMBAT\nActual Godot capture · staged presentation · original skinned arms"
 for i in range(30): p.weapons.viewmodel.update(1.0/30); await process_frame
 var w: WeaponController=p.weapons
 for i in range(780):
  frame=i
  if i==60: Input.action_press("aim"); caption.text="TRUE ADS / rear notch + front blade\nReticle hidden; eye-line hitscan unchanged"
  if i==125:
   caption.text="FIRE / kick, muzzle flash and recovery\nOriginal 100 damage and five-second reload"
   w.attack(p.camera.global_position,-p.camera.global_basis.z)
  if i==135: Input.action_release("aim")
  if i==155: caption.text="RELOAD / pouch → load → mechanism → ready\nArticulated support hand follows the ammunition timer"
  if i==305: caption.text="MUSKET / ready again after five seconds"
  if i==345: w.attack(p.camera.global_position,-p.camera.global_basis.z)
  if i==373: w.switch_weapon(); caption.text="SWITCH / draw katana during background reload\nAmmo timer continues independently"
  if i==408 or i==438: w.attack(p.camera.global_position,-p.camera.global_basis.z)
  if i==470: w.switch_weapon(); caption.text="RETURN / resume current reload stage\nNo timer reset on weapon switching"
  if i==515: Input.action_press("aim"); caption.text="AIM / smooth return to iron sights"
  if i==565: Input.action_press("crouch"); caption.text="CROUCH + ADS / camera-relative sights remain aligned"
  if i==615: Input.action_release("crouch"); Input.action_release("aim"); w.switch_weapon(); caption.text="KATANA / two-handed ready stance and slash\nExisting reach, damage and attack cadence"
  if i==660 or i==695 or i==730: w.attack(p.camera.global_position,-p.camera.global_basis.z)
  p._physics_process(1.0/30)
  await process_frame
 Input.action_release("aim"); Input.action_release("crouch")
 game.free(); layer.free(); await process_frame; quit()
