class_name Garden
extends Node3D

## Owns everything the watering can has grown. A pour lands on the ground in
## front of the boy: if a plant is already there it drinks, otherwise a new
## stalk pushes out of the dust. Plants ride the growing planet like props do.

const MERGE_RADIUS: float = 0.9
const MAX_PLANTS: int = 24

var planet: Planet

var _plants: Array[PumpkinPlant] = []


func setup(p_planet: Planet) -> void:
	planet = p_planet
	if planet != null and not planet.radius_changed.is_connected(_on_radius_changed):
		planet.radius_changed.connect(_on_radius_changed)


func get_plants() -> Array[PumpkinPlant]:
	return _plants


func get_plant_count() -> int:
	return _plants.size()


func find_plant(spot: Vector3) -> PumpkinPlant:
	var nearest: PumpkinPlant = null
	var best: float = MERGE_RADIUS
	for plant: PumpkinPlant in _plants:
		if not is_instance_valid(plant):
			continue
		var distance: float = plant.global_position.distance_to(spot)
		if distance <= best:
			best = distance
			nearest = plant
	return nearest


## Returns the plant that drank. A pour with no water still makes a dry sprout
## only when it lands somewhere new and the caller actually spent water.
func pour(spot: Vector3, water: float) -> PumpkinPlant:
	if planet == null:
		return null
	var plant: PumpkinPlant = find_plant(spot)
	if plant == null:
		if water <= 0.0:
			return null
		plant = _sprout(spot)
	if plant == null:
		return null
	plant.water(water)
	return plant


func _sprout(spot: Vector3) -> PumpkinPlant:
	if planet == null:
		return null
	while _plants.size() >= MAX_PLANTS:
		var oldest: PumpkinPlant = _plants.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var dir: Vector3 = (spot - planet.get_center()).normalized()
	var plant := PumpkinPlant.new()
	plant.name = "Plant%d" % _plants.size()
	add_child(plant)
	plant.setup(planet, dir)
	_plants.append(plant)
	return plant


func _on_radius_changed(new_radius: float) -> void:
	if planet == null:
		return
	for plant: PumpkinPlant in _plants:
		if not is_instance_valid(plant):
			continue
		plant.ground_dir = plant.ground_dir.normalized()
		plant.global_position = planet.get_center() + plant.ground_dir * new_radius
