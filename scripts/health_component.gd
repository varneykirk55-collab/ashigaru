class_name HealthComponent
extends Node
signal changed(value: float)
signal died(attacker: Node)
var value := 100.0
func damage(amount: float, attacker: Node) -> void:
	if value <= 0: return
	value = maxf(0, value - amount)
	changed.emit(value)
	if value <= 0: died.emit(attacker)
func reset() -> void:
	value = 100
	changed.emit(value)
