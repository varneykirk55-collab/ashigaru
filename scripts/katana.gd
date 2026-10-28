class_name Katana
extends RefCounted
const RANGE := 2.7
const DAMAGE := 55.0
const COOLDOWN := 0.8
var cooldown := 0.0
func tick(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
func attack() -> bool:
	if cooldown > 0: return false
	cooldown = COOLDOWN
	return true
