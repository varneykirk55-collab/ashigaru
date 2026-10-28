class_name SoundBank
extends Node
var volume := 0.7
func play_sound(kind: String, pos: Vector3 = Vector3.INF) -> void:
	if pos == Vector3.INF:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.stream=load("res://assets/audio/"+kind+".wav")
		p.volume_db=linear_to_db(maxf(0.001,volume))
		p.finished.connect(p.queue_free)
		p.play()
	else:
		var p := AudioStreamPlayer3D.new()
		add_child(p)
		p.global_position=pos
		p.stream=load("res://assets/audio/"+kind+".wav")
		p.max_distance=50
		p.volume_db=linear_to_db(maxf(0.001,volume))
		p.finished.connect(p.queue_free)
		p.play()

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream=null
