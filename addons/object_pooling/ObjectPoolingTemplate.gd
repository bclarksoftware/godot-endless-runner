extends Node

# THIS FILE IS AUTOMATICALLY GENERATED
# DO NOT EDIT

var is_debug #%**-

var scenes #%**--

# which stores all inactive scene instances
var object_pool = {}

# stores all active scene instances
var used_object_pool = {}

# records scene instances, which had to be created at runtime
var pool_miss = {}
var debug_timer = 5.0
var is_starting = true
var instances_count = 0
var debug_pool_miss_timer = 30.0

func _ready():
	# create all instances foreach scene
	for scene_path in scenes:
		for i in range(0, scenes[scene_path]):
			create_instance(scene_path)
	is_starting = false
	print_status()
	set_process(is_debug)

# displays debug informatio if debug is toggled in the UI
func _process(delta):
	debug_timer -= delta
	debug_pool_miss_timer -= delta
	if debug_timer < 0:
		print_status()
		debug_timer = 5.0
	if debug_pool_miss_timer < 0:
		print_pool_miss()
		debug_pool_miss_timer = 30.0

# loads an instance from the pool if it is available
# or creates a new instance if it is not inside the pool
func load_from_pool(scene_path):
	if object_pool.has(scene_path):
		# pool miss
		if object_pool[scene_path].instances.size() < 1:
			if !is_starting:
				if !pool_miss.has(scene_path):
					pool_miss[scene_path] = 0
				pool_miss[scene_path] += 1
			return create_and_use_instance(scene_path)
		else:
			# return inactive instance, and toggle it active
			var instance = object_pool[scene_path].instances[0]
			object_pool[scene_path].instances.erase(instance)
			use_instance(scene_path, instance)
			return instance
	else:
		# scene is not registered with the object pooler UI
		# create it regardless at runtime
		return create_and_use_instance(scene_path)

# creates an inactive instance and assigns it to the array of the scene path
func create_instance(scene_path):
	if !object_pool.has(scene_path):
		object_pool[scene_path] = {
			instances = [],
			props = {}
		}
	var instance = load(scene_path).instantiate()
	instance.set_meta("scene_path", scene_path)
	
	# record the initial state of the instance
	if instance is Node3D:
		object_pool[scene_path].props = {
			transform = get_prop(instance, "global_transform", instance.transform)
		}
	
	if instance is Node2D:
		object_pool[scene_path].props = {
			transform = get_prop(instance, "global_position", instance.position)
		}
		
	if instance is Control:
		object_pool[scene_path].props = {
			position = get_prop(instance, "global_position", instance.position),
			rotation = instance.rotation,
			scale = instance.scale,
			size = instance.size
		}
	
	object_pool[scene_path].instances.push_back(instance)
	instances_count += 1
	return instance
	
# wrapper to create and set the instance as active
func create_and_use_instance(scene_path):
	var instance = create_instance(scene_path)
	object_pool[scene_path].instances.erase(instance)
	use_instance(scene_path, instance)
	return instance
	
# adds the instance to the used pool and sets it as active
func use_instance(scene_path, instance):
	if !used_object_pool.has(scene_path):
		used_object_pool[scene_path] = []
	toggle_instance_activation(instance, true)
	used_object_pool[scene_path].push_back(instance)

# deactivates the instance
func queue_free_instance(instance):
	toggle_instance_activation(instance, false)
	if instance.has_meta("scene_path"):
		if used_object_pool.has(instance.get_meta("scene_path")):
			used_object_pool[instance.get_meta("scene_path")].erase(instance)
		object_pool[instance.get_meta("scene_path")].instances.push_back(instance)
	
# sets the instance's initial state or deactivates it, 
# while removing it from the scene tree
func toggle_instance_activation(instance, activate):
	recursively_activate(instance, activate)
	if instance.has_method("on_object_pooling_reset"):
		instance.on_object_pooling_reset(activate)
	if !activate:
		instance.get_parent().call_deferred("remove_child", instance)
		
		if instance.has_meta("scene_path"):
			if instance is Node3D:
				instance.global_transform = object_pool[instance.get_meta("scene_path")].props.transform
			
			if instance is Node2D:
				instance.global_transform = object_pool[instance.get_meta("scene_path")].props.transform
		
			if instance is Control:
				instance.global_position = object_pool[instance.get_meta("scene_path")].props.position
				instance.rotation = object_pool[instance.get_meta("scene_path")].props.rotation
				instance.scale = object_pool[instance.get_meta("scene_path")].props.scale
				instance.size = object_pool[instance.get_meta("scene_path")].props.size
	instance.visible = activate
	
# (de-)activate all physics related objects in the node hierarchy
func recursively_activate(instance, activate):
	for child_node in instance.get_children():
		recursively_activate(child_node, activate)
	if instance is CollisionShape3D:
		instance.disabled = !activate
		return
	if instance is CollisionShape2D:
		instance.disabled = !activate
		return
	if instance is CollisionPolygon2D:
		instance.disabled = !activate
		return
	if instance is CollisionPolygon3D:
		instance.disabled = !activate
		return
	
func get_prop(instance, prop, default):
	if instance.is_inside_tree():
		return instance[prop]
	return default
	
func format_memory_usage(val):
	var b = val
	var kb = b / 1024
	var mb = kb / 1204
	if mb > 1:
		return str(mb) + "MB"
	if kb > 1:
		return str(kb) + "KB"
	return str(b) + "B"
	
func print_status():
	if is_debug:
		var mem_usage_static = Performance.get_monitor(Performance.Monitor.MEMORY_STATIC)
		var mem_usage_peak = Performance.get_monitor(Performance.Monitor.MEMORY_MESSAGE_BUFFER_MAX)
		print("ObjectPooling: [%3s] instances spawned [Stat: %s, Peak: %s]" % [instances_count, format_memory_usage(mem_usage_static), format_memory_usage(mem_usage_peak)])

func print_pool_miss():
	if pool_miss.keys().size() > 0:
		print("\nObjectPooling: [miss] Pool misses for %-50s" % ["scene_path"])
		print("-----------------------------------------------------------------------")
	for miss in pool_miss.keys():
		print("ObjectPooling: [%4s] Pool misses for %-50s" % [pool_miss[miss], miss])
	if pool_miss.keys().size() > 0:
		print("-----------------------------------------------------------------------")
		print("Tweak the numbers\n")
