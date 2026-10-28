class_name MatchManager
extends Node
signal ended
var scores := [0,0]
var time_left := 240.0
var score_limit := 20
var active := false
func tick(delta: float) -> void:
	if not active: return
	time_left = maxf(0,time_left-delta)
	if time_left <= 0: finish()
func kill(team: int) -> void:
	if not active: return
	scores[team] += 1
	if scores[team] >= score_limit: finish()
func finish() -> void:
	if not active: return
	active=false
	ended.emit()
