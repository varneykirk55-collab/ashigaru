class_name SpawnManager
extends RefCounted
var counter := [0,0]
func location(team: int) -> Vector3:
	var i: int = counter[team] % 4
	counter[team] += 1
	return Vector3(-14 + i*3.0,0.1,14) if team == 0 else Vector3(14-i*3.0,0.1,-14)
