class_name SpawnManager
extends RefCounted
var counter := [0,0]
func location(team: int, actors: Array = []) -> Vector3:
	var base := Vector3(-57,0.12,40) if team==0 else Vector3(57,0.12,-40)
	var best := base; var best_score := -INF
	for slot in range(9):
		var p := base+Vector3((slot%3-1)*3,0,(slot/3-1)*3)
		var nearest := 999.0
		for actor in actors:
			if not is_instance_valid(actor) or actor.health.value<=0: continue
			var distance: float=p.distance_to(actor.global_position)
			nearest=minf(nearest,distance*(1 if actor.team!=team else 3))
		var score: float= nearest+(0.2 if slot==counter[team]%9 else 0)
		if score>best_score: best_score=score; best=p
	counter[team]+=1
	return best
