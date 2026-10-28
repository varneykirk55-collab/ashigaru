class_name Musket
extends RefCounted
const RELOAD_TIME := 5.0
var loaded := true
var reserve := 18
var remaining := 0.0
func tick(delta: float) -> bool:
	if remaining <= 0: return false
	remaining = maxf(0, remaining - delta)
	if remaining == 0:
		loaded = true
		return true
	return false
func fire() -> bool:
	if not loaded or remaining > 0: return false
	loaded = false
	return true
func reload() -> bool:
	if loaded or remaining > 0 or reserve <= 0: return false
	reserve -= 1
	remaining = RELOAD_TIME
	return true
