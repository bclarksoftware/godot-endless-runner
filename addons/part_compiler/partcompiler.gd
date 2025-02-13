@tool
extends EditorPlugin

var menu

func _enter_tree():
	menu = Button.new()
	menu.text = "Compute Parts"
	menu.connect("pressed", Callable(self, "on_compute_parts"))
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, menu)

func _exit_tree():
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, menu)

func on_compute_parts():
	var root = get_tree().get_edited_scene_root()
	
	# If there is a node with OBJECT_LAYOUTS, we will write the layout to a file.
	if root.has_node("OBJECT_LAYOUTS"):
		var layouts = {}
		# Loop through all children of the OBJECT_LAYOUTS node
		for node in root.get_node("OBJECT_LAYOUTS").get_children():
			# Record each layout, grouping by type based on node name
			var s = node.name.split('_')
			var type = s[0]
			if !layouts.has(type):
				layouts[type] = []
			layouts[type].push_back(_extract_layout_from_node(node))
		
		# Create a new resource and store the layouts (as JSON data in a "data" property)
		var compiled_resource = Resource.new()
		compiled_resource.data = layouts  # Dynamically add a property "data" with the layouts
		
		# Save the resource to a file using ResourceSaver
		var err = ResourceSaver.save(compiled_resource, "res://compiled_parts.tres")
		if err != OK:
			push_error("Failed to save resource: %s" % err)
		
		# Remove the temporary OBJECT_LAYOUTS node from the edited scene
		root.remove_child(root.get_node("OBJECT_LAYOUTS"))
	else:
		var resource = ResourceLoader.load("res://compiled_parts.tres")
		var json_text: String = JSON.stringify(resource.data)

		# now parse the JSON text
		var json := JSON.new()
		var json_result := json.parse(json_text)
		if json_result != OK:
			push_error("Failed to parse JSON: %s" % json_result)
			return

		var layouts = json.data
		var layouts_node = null
		if !root.has_node("OBJECT_LAYOUTS"):
			layouts_node = Node3D.new()
			layouts_node.name = "OBJECT_LAYOUTS"
			root.add_child(layouts_node)
			layouts_node.set_owner(root)
		else:
			layouts_node = root.get_node("OBJECT_LAYOUTS")
		
		# loop over layouts and instance the related scenes at those positions
		for part in layouts.values():
			print(part)
			for layout in part:
				print(layout.name)
				var s = Node3D.new()
				s.name = layout.name
				s.visible = false
				layouts_node.add_child(s)
				s.set_owner(root)
				for item in layout.children:
					var n = item.name.split('_')
					var p = null
					print(item.name)
					if item.name.begins_with("COIN"):
						p = load("res://scenes/coin.tscn").instantiate()
					elif item.name.begins_with("MAGNET"):
						p = load("res://scenes/magnet.tscn").instantiate()
					elif item.name.begins_with("SHIELD"):
						p = load("res://scenes/shield.tscn").instantiate()
					elif item.name.begins_with("SPEED"):
						p = load("res://scenes/speed.tscn").instantiate()
					elif item.name.begins_with("TOKEN"):
						p = load("res://scenes/token.tscn").instantiate()
					else:
						p = load("res://scenes/obstacles/" + n[0].to_lower() + ".tscn").instantiate()
					p.name = item.name
					p.transform.origin = Vector3(item.x, item.y, item.z)
					p.rotation = Vector3(item.rx, item.ry, item.rz)
					s.add_child(p)
					p.set_owner(root)

func _extract_layout_from_node(node: Node) -> Dictionary:
	var layout = {
		"name": node.name,
		"children": []
	}
	for item in node.get_children():
		var v = item.transform.origin
		layout["children"].append({
			"name": item.name,
			"x": v.x,
			"y": v.y,
			"z": v.z,
			"rx": item.rotation.x,
			"ry": item.rotation.y,
			"rz": item.rotation.z
		})
	return layout
