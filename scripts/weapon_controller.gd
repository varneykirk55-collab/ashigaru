class_name WeaponController
extends Node3D
var actor: CharacterBody3D
var musket := Musket.new()
var katana := Katana.new()
var selected := 0
var gun_model: Node3D
var sword_model: Node3D
var animation := 0.0
var recoil := 0.0
func setup(owner_actor: CharacterBody3D) -> void:
	actor=owner_actor
	gun_model=Geometry.weapon(self,false)
	sword_model=Geometry.weapon(self,true)
	sword_model.visible=false
func tick(delta: float) -> void:
	if musket.tick(delta): actor.game.sounds.play_sound("reload",actor.global_position)
	katana.tick(delta)
	recoil=move_toward(recoil,0,delta*4)
	animation=maxf(0,animation-delta)
	gun_model.position=Vector3(0, -0.1*sin(musket.remaining*2) if musket.remaining>0 else 0,recoil*0.18)
	gun_model.rotation.z=0.35 if musket.remaining>0 else 0.0
	sword_model.rotation=Vector3(-animation*1.7,0,animation*2.5)
func switch_weapon() -> void:
	selected=1-selected
	gun_model.visible=selected==0
	sword_model.visible=selected==1
func reload() -> void:
	if musket.reload(): actor.game.sounds.play_sound("reload",actor.global_position)
func attack(origin: Vector3, direction: Vector3) -> bool:
	if actor.health.value<=0 or not actor.game.match_state.active: return false
	if selected == 0:
		if not musket.fire():
			reload()
			return false
		recoil=1
		actor.game.sounds.play_sound("shot",origin)
		actor.game.muzzle(origin+direction*1.0)
		var result := DamageSystem.trace(actor,origin,direction,90)
		if result and DamageSystem.hit(result.collider,100,actor): actor.game.feedback(actor,"HIT",true)
		elif result: actor.game.impact(result.position)
		return true
	if not katana.attack(): return false
	animation=0.65
	actor.game.sounds.play_sound("swing",origin)
	var result := DamageSystem.trace(actor,origin,direction,Katana.RANGE)
	if result and DamageSystem.hit(result.collider,Katana.DAMAGE,actor):
		actor.game.feedback(actor,"CUT",true)
		actor.game.sounds.play_sound("impact",result.position)
	return true
