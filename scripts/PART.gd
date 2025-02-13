
extends Node3D

var visited = false
@export var type: String

# unload the part if it is marked as visited
func _process(_delta):
	if visited:
		visited = false
		ObjectPooling.queue_free_instance(self)
		Globals.emit_signal("on_unload_part", self)

# remove all active obstacles inside this part
func on_object_pooling_reset(activate):
	if !activate:
		visited = false
		for obstacle in $OBSTACLES.get_children():
			ObjectPooling.queue_free_instance(obstacle)
