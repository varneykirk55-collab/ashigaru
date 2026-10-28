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
var switch_time := 0.0
var shown_weapon := 0
var hands: Node3D
var hit_kind := ""
var viewmodel: FirstPersonViewmodel
func setup(owner_actor: CharacterBody3D) -> void:
	actor=owner_actor
	gun_model=Geometry.weapon(self,false)
	sword_model=Geometry.weapon(self,true)
	sword_model.visible=false
	if actor is PlayerController: _build_hands()
func tick(delta: float) -> void:
	if musket.tick(delta): actor.game.sounds.play_sound("reload",actor.global_position)
	katana.tick(delta)
	recoil=move_toward(recoil,0,delta*5)
	animation=maxf(0,animation-delta)
	if switch_time>0:
		switch_time=maxf(0,switch_time-delta)
		if switch_time<=0.18 and shown_weapon!=selected:
			shown_weapon=selected; gun_model.visible=selected==0; sword_model.visible=selected==1
	if is_instance_valid(viewmodel):
		viewmodel.update(delta)
		return
	var dip := sin(clampf(switch_time/0.36,0,1)*PI)*0.45
	var loading := musket.remaining>0 and selected==0
	var progress := 1-musket.remaining/Musket.RELOAD_TIME if loading else 0.0
	var envelope := sin(progress*PI) if loading else 0.0
	var gait_speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	var bob := sin(Time.get_ticks_msec()*0.001*(11 if gait_speed>5 else 7))*minf(gait_speed,7)*0.0018 if actor is PlayerController else 0.0
	var gun_pos := Vector3(0,-dip-envelope*0.15+bob,recoil*0.19)
	var gun_rot := Vector3(-recoil*0.09,envelope*0.12,envelope*0.65)
	var attack_phase := (0.65-animation)/0.65
	var slash := sin(attack_phase*PI) if animation>0 else 0.0
	var sword_rot := Vector3(-slash*0.9,-slash*0.75,slash*1.5)
	var weight := 1-exp(-24*delta)
	gun_model.position=gun_model.position.lerp(gun_pos,weight)
	gun_model.rotation=gun_model.rotation.lerp(gun_rot,weight)
	sword_model.position=sword_model.position.lerp(Vector3(-slash*0.1,-dip,-0.25),weight)
	sword_model.rotation=sword_model.rotation.lerp(sword_rot,weight)
func switch_weapon() -> void:
	if switch_time>0 or actor.health.value<=0: return
	selected=1-selected
	switch_time=0.36
func _build_hands() -> void:
	viewmodel=FirstPersonViewmodel.new(); add_child(viewmodel); viewmodel.setup(self)
	hands=viewmodel.rig
func reload() -> void:
	if musket.reload(): actor.game.sounds.play_sound("reload",actor.global_position)
func attack(origin: Vector3, direction: Vector3) -> bool:
	if actor.health.value<=0 or not actor.game.match_state.active or switch_time>0: return false
	if selected == 0:
		if not musket.fire():
			reload()
			return false
		actor.health.protection=0
		recoil=1
		if is_instance_valid(viewmodel): viewmodel.update(0.0)
		actor.game.sounds.play_sound("shot",origin)
		var flash_origin := origin+direction*1.0
		if is_instance_valid(viewmodel): flash_origin=actor.camera.global_transform*(gun_model.transform*Vector3(0,0.065,-1.49))
		actor.game.muzzle(flash_origin)
		var result := DamageSystem.trace(actor,origin,direction,90)
		if result and DamageSystem.hit(result.collider,100,actor):
			var headshot: bool = result.get("headshot",false)
			hit_kind="HEADSHOT" if headshot else "HIT"
			if result.collider.health.value<=0: hit_kind="HEADSHOT · KILL" if headshot else "KILL"
			actor.game.feedback(actor,hit_kind,true)
		elif result: actor.game.impact(result.position)
		reload()
		return true
	if not katana.attack(): return false
	actor.health.protection=0
	animation=0.65
	actor.game.sounds.play_sound("swing",origin)
	var result := DamageSystem.trace(actor,origin,direction,Katana.RANGE)
	if result and DamageSystem.hit(result.collider,Katana.DAMAGE,actor):
		hit_kind="MELEE KILL" if result.collider.health.value<=0 else "MELEE HIT"
		actor.game.feedback(actor,hit_kind,true)
		actor.game.sounds.play_sound("impact",result.position)
	return true
