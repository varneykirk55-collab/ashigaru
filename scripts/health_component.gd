class_name HealthComponent
extends Node
signal changed(value: float)
signal died(attacker: Node)
var value := 100.0
var protection := 0.0
func tick(delta: float) -> void:
	protection=maxf(0,protection-delta)
func damage(amount: float, attacker: Node) -> void:
	if value <= 0 or protection>0: return
	value = maxf(0, value - amount)
	changed.emit(value)
	if value <= 0: died.emit(attacker)
func reset() -> void:
	value = 100
	changed.emit(value)
