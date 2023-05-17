#----------------------------------------

# This wraps the individual yaml documents in the {guid}/asset file
# if {guid}/asset is a yaml file in the package
# All converted to a dictionary

class_name AssetDoc extends AssetDocBase

#----------------------------------------

const COMPONENT_PROCESSING_SEQUENCE = {
	"Transform": 0,
	"MeshRenderer": 30,
	"MeshFilter": 20
}

#----------------------------------------

func asset_doc_scene(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("DocScene", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)
 
	match data.type:
		"Transform":
			if is_stripped_transform():
				return asset_doc_stripped_transform(root_node, parent)
			else:
				return asset_doc_transform(root_node, parent)
		"MeshFilter":
			return asset_doc_mesh_filter(root_node, parent)
		"Prefab":
			return asset_doc_prefab(root_node, parent)
		"PrefabInstance":
			return asset_doc_prefab_instance(root_node, parent)
		_:
			push_error("AssetDoc::DocScene::UnsupportedType::%s" % data.type)
			return null

#----------------------------------------

func asset_doc_transform(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("Transform", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	trace("Transform", "Building", Color.GREEN)
	
	var gameobject_doc = get_asset_doc_by_ref(data.content.m_GameObject)

	if gameobject_doc.content.m_Name == "Root_M":
		breakpoint

	var transform_node = Node3D.new()
	if parent != null:
		parent.add_child(transform_node)
		transform_node.owner = choose_correct_owner(root_node, parent)
	if root_node == null:
		root_node = transform_node

	transform_node.scale = to_scale(data.content.m_LocalScale)
	transform_node.position = to_position(data.content.m_LocalPosition)
	transform_node.quaternion = to_quaternion(data.content.m_LocalRotation)
	set_created_by(transform_node, "AssetDoc::Transform")
	append_ufile_ids(transform_node, [self._ufile_id], "AssetDocTransform")

	gameobject_doc.apply_component(root_node, parent, transform_node)

	for comp_ref in data.content.m_Children:
		var comp_doc = get_asset_doc_by_ref(comp_ref)
		comp_doc.asset_doc_scene(root_node, transform_node)

	if transform_node == null:
		push_error("AssetDoc::Transform::BuildFailed")
		return null

	return transform_node

#----------------------------------------

func asset_doc_stripped_transform(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("StrippedTransform", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	var prefab_doc
	var prefab_asset

	if data.content.has("m_PrefabInstance"):
		prefab_doc = get_asset_doc_by_ref(data.content.m_PrefabInstance)
		if !prefab_doc.content.has("m_SourcePrefab") || prefab_doc.content.m_SourcePrefab.fileID != 100100000:
			breakpoint
		prefab_asset = uurs.get_asset(prefab_doc.content.m_SourcePrefab.guid)
	elif data.content.has("m_PrefabInternal"):
#		if data.content.m_PrefabInternal.fileID == 1724041162:
#			breakpoint
		prefab_doc = get_asset_doc_by_ref(data.content.m_PrefabInternal)
		if !prefab_doc.content.has("m_ParentPrefab") || prefab_doc.content.m_ParentPrefab.fileID != 100100000:
			breakpoint
		prefab_asset = uurs.get_asset(prefab_doc.content.m_ParentPrefab.guid)
	else:
		breakpoint
		return null

	if not prefab_asset is Asset:
		breakpoint
		return null

	var node = _asset_doc_stripped_transform__build(root_node, parent, prefab_asset, prefab_doc)

	return node

#----------------------------------------

func _asset_doc_stripped_transform__build(root_node: Node3D, parent: Node3D, prefab_asset: Asset, prefab_doc: AssetDoc) -> Node3D:
	trace("_StrippedTransform", "Building", Color.GREEN)

	var child_prefabs = asset.docs.filter(func(doc: AssetDoc):
		if !doc.is_prefab():
			return false
		# Prefab.m_Modification.m_TransformParent
		var prefab_parent = doc.content.m_Modification.m_TransformParent
		return prefab_parent.fileID == data._file_id
	) as Array[AssetDoc]

	var prefab = prefab_asset.asset_scene(root_node, parent)
	_apply_modifications(parent, prefab, prefab_doc)

	for child_doc in child_prefabs:
		child_doc.asset_doc_scene(root_node, prefab)

	return prefab

#----------------------------------------

func asset_doc_prefab(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("Prefab", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	trace("Prefab", "Building", Color.GREEN)

	var prefab_doc = uurs.get_asset_by_ref(data.content.m_ParentPrefab)
	var node = prefab_doc.asset_scene(root_node, parent)

	set_created_by(node, "AssetDoc::Prefab")
	append_ufile_ids(node, [self._ufile_id], "AssetDocPefab")
	_apply_modifications(parent, node, self)

	return node

#----------------------------------------

func asset_doc_prefab_instance(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("PrefabInstance", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	trace("PrefabInstance", "Building", Color.GREEN)

	var prefab_doc = uurs.get_asset_by_ref(data.content.m_SourcePrefab)
	var node = prefab_doc.asset_scene(root_node, parent)

	set_created_by(node, "AssetDoc::PrefabInstance")
	append_ufile_ids(node, [self._ufile_id], "AssetDocPrefabInstance")
	_apply_modifications(parent, node, self)

	return node

#----------------------------------------

func asset_doc_mesh_filter(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("MeshFilter")

	if uurs.enable_memcache && data.has("_memcache_mesh_filter"):
		trace("MeshFilter", "FromMemCache", Color.GREEN)
		return duplicate(
			root_node,
			parent,
			data._memcache_mesh_filter,
			"MeshFilter 1"
		)

	var mesh_ref = data.content.m_Mesh
	var new_node: Node3D = Node3D.new()

	if not mesh_ref.guid is String && mesh_ref.guid == 0 && mesh_ref.fileID == 10209:
		_asset_doc_mesh_filter__plane(root_node, parent, new_node)
	else:
		_asset_doc_mesh_filter__mesh_from_ref(root_node, parent, new_node, mesh_ref)

	data._memcache_mesh_filter = new_node
	return duplicate(
		root_node,
		parent,
		data._memcache_mesh_filter,
		"MeshFilter 2"
	)

#----------------------------------------

# Using the wrapper can resolve issues with scaling and rotation
# Without using the wrapper, to fix any scaling issues also apply the fix to the position
const use_pivot_wrapper: bool = false

#----------------------------------------

func _asset_doc_mesh_filter__plane(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("MeshFilter", "PlaneMesh::%s" % self, Color.WHITE)

	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(10, 10)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.name = "PlaneMesh"

	if use_pivot_wrapper:
		# Mesh goes inside pivot_offset here to be consistent with mesh_from_ref
		# See notes about pivot_offset there
		var pivot_offset = Node3D.new()

		pivot_offset.name = "Plane Wrapper"
		pivot_offset.add_child(mesh_instance)

		transform_node.add_child(pivot_offset)

		pivot_offset.owner = choose_correct_owner(root_node, parent, transform_node)
		mesh_instance.owner = choose_correct_owner(root_node, parent, transform_node)
	else:
		# Use transform origin for offset
		transform_node.add_child(mesh_instance)
		mesh_instance.owner = choose_correct_owner(root_node, parent, transform_node)

#----------------------------------------

func _asset_doc_mesh_filter__mesh_from_ref(root_node: Node3D, parent: Node3D, transform_node: Node3D, mesh_ref: Dictionary) -> void:
	var mesh_asset = uurs.get_asset_by_ref(mesh_ref)
	if mesh_asset == null:
		push_error("AssetDoc::MeshFilter::GetAssetFailed:%s" % mesh_ref)
		return

	var mesh_name: Variant = _asset_doc_mesh_filter__mesh_from_ref__find_mesh_name(mesh_asset, mesh_ref)
	var scene: Node = _asset_doc_mesh_filter__mesh_from_ref__gltf_scene(mesh_asset)

	if scene == null:
		push_error("AssetDoc::MeshFilter::GltfSceneFailed")
		return

	var mesh
	var search
	if mesh_name != null:
		if mesh_name == "":
			mesh_name = mesh_asset.pathname.get_file().get_basename()

		search = search_for_node(scene, func(n):
			if mesh_name == n.name && n is MeshInstance3D:
				return n
			return
		)
		if search == null && mesh_name.begins_with("//"):
			mesh_name = mesh_name.substr(2)
			search = search_for_node(scene, func(n):
				if mesh_name == n.name && n is MeshInstance3D:
					return n
				return
			)
		if search == null:
			search = search_for_node(scene, func(n):
				if n is MeshInstance3D:
					return n
				return
			)

		if search == null:
			push_error("AssetDoc::MeshFilter::MeshSearchFailed1")
			search = scene
			pass

		mesh = search.mesh
	else:
		mesh_name = mesh_asset.pathname.get_file().get_basename()
		search = search_for_node(scene, func(n):
			if n is MeshInstance3D:
				return n
			return
		)
		if search == null:
			push_error("AssetDoc::MeshFilter::MeshSearchFailed2")
			search = scene
			pass
		mesh = search.mesh

	if uurs.enable_disk_storage:
		var asset_storage_path = mesh_asset.disk_storage_path()
		var mesh_storage_path = "%s%s/%d.tscn" % [
			asset_storage_path.get_basename(),
			"_mesh",
			mesh_ref.fileID
		]
		var mesh_save_file = "%s.mesh" % mesh_storage_path.get_basename()
		if !FileAccess.file_exists(mesh_save_file):
			DirAccess.make_dir_recursive_absolute(mesh_save_file.get_base_dir())
			ResourceSaver.save(search.mesh, mesh_save_file)
		mesh = load(mesh_save_file)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = search.position
	instance.scale = search.scale
	instance.name = "_mesh" # mesh_name
	set_created_by(instance, "AssetDoc::MeshFilter")

	# Wrap the mesh instance
	if use_pivot_wrapper && search.position != Vector3.ZERO:
		# The rotation goes on the pivot_offset wrapper
		instance.quaternion = Quaternion.IDENTITY

		# Mesh instance goes into pivot_offset, offset by pivot position
		# amount set on the node by GLTF PivotFixer.
		# This allows pivot_offset to be translated/rotated
		# without being affected by the mesh instance offset.
		# This would not be needed if the pivot can be set separately
		# on the mesh instance.
		var pivot_offset = Node3D.new()

		# Use a parent node for offset
		pivot_offset.add_child(instance)
		transform_node.add_child(pivot_offset)

		transform_node.name = mesh_name
		pivot_offset.name = "_offset" #mesh_name

		pivot_offset.owner = choose_correct_owner(root_node, parent, transform_node)
		instance.owner = choose_correct_owner(root_node, parent, transform_node)
	else:
		# Use transform origin for offset
		instance.transform.origin = search.position
		scifi_fix(instance, mesh_name)
		transform_node.add_child(instance)
		instance.owner = choose_correct_owner(root_node, parent, transform_node)

#----------------------------------------

func scifi_fix(node: Node, node_name: String):
	# Temporary Scale fix for SciFi City
	var rescale = ["SM_Sign_Billboard_Large_", "SM_Prop_Posters_", "SM_Prop_Cables_"]
	for r in rescale:
		if (node_name as String).contains(r):
			node.scale *= 0.1
			node.position *= 0.1
			return

#----------------------------------------

func _asset_doc_mesh_filter__mesh_from_ref__find_mesh_name(mesh_asset: Asset, mesh_ref: Dictionary):
	var mesh_name: Variant

	if mesh_asset.meta.content.has("fileIDToRecycleName"):
		mesh_name = (mesh_asset
			.meta
			.content
			.fileIDToRecycleName
			.get(str(mesh_ref.fileID), "")
		)
		if mesh_name == null:
			push_error("AssetDoc::MeshFilter::fileIDToRecycleName::MissingMeshName::%s" % mesh_ref)
			return null
	elif mesh_asset.meta.content.has("internalIDToNameTable"):
		var entry = (mesh_asset
			.meta
			.content
			.internalIDToNameTable
			.filter(func(item):
				var key = item.first.keys().front()
				return item.first[key] == mesh_ref.fileID
		))
		if entry.size() > 0:
			mesh_name = entry[0].second
		if mesh_name == null:
			push_error("AssetDoc::MeshFilter::internalIDToNameTable::MissingMeshName::%s" % mesh_ref)
			return null
	else:
		push_error("AssetDoc::MeshFilter::MissingMeshLookupDict::%s" % mesh_asset)
		push_error("...LookingFor::%s" % mesh_ref)
		return null

	return mesh_name

#----------------------------------------

func _asset_doc_mesh_filter__mesh_from_ref__gltf_scene(mesh_asset: Asset):
	if mesh_asset.uurs.enable_memcache && data.has("_memcache_gltf_scene"):
		return mesh_asset.data._memcache_gltf_scene

	# Full thing has not been loaded yet
	var buffer = mesh_asset.load_binary()
	if buffer == null:
		push_error("AssetDoc::MeshFilter::BufferEmpty")
		return null

	var doc = GLTFDocument.new()
	var state = GLTFState.new()

	var result
	if mesh_asset.data.has("_disk_storage_binary_path"):
		result = doc.append_from_file(mesh_asset.data._disk_storage_binary_path, state)
	else:
		result = doc.append_from_buffer(buffer, "", state)

	if result != OK:
		push_error("AssetDoc::MeshFilter::AppendFromBufferFailed::%d" % result)
		return null

	# force PivotFixer to run
	var scene = doc.generate_scene(state)

	mesh_asset.data._memcache_gltf_scene = scene

	return mesh_asset.data._memcache_gltf_scene

#----------------------------------------

func apply_component(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	match data.type:
		"GameObject":
			_apply_component__game_object(root_node, parent, transform_node)
		"MeshRenderer":
			_apply_component__mesh_renderer(root_node, parent, transform_node)
		"MeshFilter":
			_apply_component__mesh_filter(root_node, parent, transform_node)
		"Transform":
			_apply_component__transform(root_node, parent, transform_node)
		"SkinnedMeshRenderer":
			_apply_component__skinned_mesh_renderer(root_node, parent, transform_node)
		"BoxCollider", "CapsuleCollider", "MeshCollider", "SphereCollider":
			# TODO
			trace("ApplyComponent", "TODO::%s" % self)
		"Animator", "AudioListener", "Behaviour", "Camera", "Light", "MonoBehaviour", "ReflectionProbe", "CharacterController", "NavMeshAgent":
			# Don't need?
			trace("ApplyComponent", "Skipping::%s" % self)
		"ParticleSystem", "ParticleSystemRenderer":
			# Heh
			trace("ApplyComponent", "UnlikelyTODO::%s" % self)
		_:
			push_error("AssetDoc::Apply::UnsupportedType::%s" % data.type)

#----------------------------------------

func _apply_component__game_object(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyGameObject", "%s::%s" % [
		data.content.m_Name,
		self
	], Color.CYAN)

	if self.content.m_Name == null:
		push_warning("AssetDoc::BuildGameObject::NoName::%s" % self)
	else:
		transform_node.name = data.content.m_Name

	transform_node.visible = data.content.m_IsActive == 1

	append_ufile_ids(transform_node, [self._ufile_id], "ApplyComponentGameObject::%s" % self)

	var component_refs = data.content.m_Component as Array
	# Sort to mesh filter becomes before mesh renderer, etc
	component_refs.sort_custom(_helper_sort_component_ref)

	for comp_ref in component_refs:
		var comp = get_asset_doc_by_ref(comp_ref.component)
		
		if comp == null:
			push_warning("AssetDoc::BuildGameObject::ComponentDocNotFound::%s" % comp_ref)
			continue
		
		if comp.type == "Transform":
			# This is the transform that is applying this game object doc
			continue

		append_ufile_ids(transform_node, [comp._ufile_id], "ApplyComponentGameObject::Component::%s" % comp)
		comp.apply_component(root_node, parent, transform_node)

#----------------------------------------

func _apply_component__transform(_root_node: Node3D, _parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_Transform")

	transform_node.scale = to_scale(data.content.m_LocalScale)
	transform_node.position = to_position(data.content.m_LocalPosition)
	transform_node.quaternion = to_quaternion(data.content.m_LocalRotation)

#----------------------------------------

func _apply_component__skinned_mesh_renderer(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_SkinnedMeshrenderer")

	_apply_component__mesh_filter(root_node, parent, transform_node)
	_apply_component__mesh_renderer(root_node, parent, transform_node)
	# TODO: Skeleton

#----------------------------------------

func _apply_component__mesh_filter(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_MeshFilter")

	var mesh_ref = data.content.m_Mesh
	if not mesh_ref.guid is String && mesh_ref.guid == 0 && mesh_ref.fileID == 10209:
		_asset_doc_mesh_filter__plane(root_node, parent, transform_node)
	else:
		_asset_doc_mesh_filter__mesh_from_ref(root_node, parent, transform_node, mesh_ref)

#----------------------------------------

func _apply_component__mesh_renderer(_root_node: Node3D, _parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_MeshRenderer")

	var materials = data.content.m_Materials.map(func(mat_ref):
		# TODO: Figure out what this guid represents
		if mat_ref.guid == "0000000000000000f000000000000000":
			return StandardMaterial3D.new()
		else:
			var material = uurs.get_asset_by_ref(mat_ref)
			if material == null:
				push_warning("AssetDoc::ApplyComponentMeshRenderer::AssetNotFound::%s" % mat_ref)
				return StandardMaterial3D.new()
			var mat = material.asset_material()
			return mat
	) as Array

	for_all_nodes(transform_node, func(child: Node):
#		print("Surfaces: %d, Materials: %d" % [
#			child.get_surface_override_material_count(),
#			materials.size()
#		])
		if child is MeshInstance3D:
			for index in child.get_surface_override_material_count():
				if index < materials.size():
					child.set_surface_override_material(index, materials[index])
	)

#----------------------------------------

func _helper_sort_component_ref(a, b):
	var comp_a = get_asset_doc_by_ref(a.component)
	var comp_b = get_asset_doc_by_ref(b.component)
	if comp_a == null:
		push_warning("AssetDoc::HelperSort::CompANotFound::%s" % a)
		return false
	if comp_b == null:
		push_warning("AssetDoc::HelperSort::CompBNotFound::%s" % b)
		return false
	var x = COMPONENT_PROCESSING_SEQUENCE.get(comp_a.type, 100)
	var y = COMPONENT_PROCESSING_SEQUENCE.get(comp_b.type, 100)
	return x < y

#----------------------------------------

# mat_ref:
# "objectReference": {
#   "fileID": 2100000,
#   "guid": "a2897c3aeeb53764a92e472c8e73d76d",
#   "type": 2
# }
func _apply_modifications__material(_parent: Node3D, node: Node3D, slot: String, mat_ref: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)?(\\[(\\d+)\\])?") # ex: foo, or foo[10]

	var result = regex.search(slot)
	if result == null:
		return

	var key = result.get_string(1)
	var index = int(result.get_string(3))

	# print("%s = %d" % [key, index])

	if !mat_ref.has("guid") || not mat_ref.guid is String || mat_ref.guid == "0000000000000000f000000000000000":
		return

	var mat_asset = uurs.get_asset_by_ref(mat_ref)
	if mat_asset == null:
		return

	var material = mat_asset.asset_material()

	for_all_nodes(node, func(child: Node):
		if child is MeshInstance3D && index < child.get_surface_override_material_count():
			child.set_surface_override_material(index, material)
	)

#----------------------------------------

func _apply_modifications(parent: Node3D, node: Node3D, prefab_doc: AssetDoc):
	trace("ApplyModifications", "%s::%s" % [
		prefab_doc,
		self
	])

	var quat_builder = QuaternionBuilder.new()

	var made_editable: bool = false

	for m in prefab_doc.content.m_Modification.m_Modifications:
		# Stop these from generating TargetMissing warnings
		# TODO: Implement at some point

		match m.propertyPath:
			"m_Controller":					continue
			"m_RootOrder":					continue
			"m_CastShadows":				continue
			"m_ReceiveShadows":				continue
			"m_Layer":						continue
			"Params.maxConvexHulls":		continue
#			"m_LocalEulerAnglesHint.x":		continue
#			"m_LocalEulerAnglesHint.y":		continue
#			"m_LocalEulerAnglesHint.z":		continue
			"randomSeed":					continue
			"simulationSpeed":				continue
			"m_Mesh":						continue
			"m_Convex":						continue
			"prewarm":						continue

		if !m.target.has("guid") || !m.target.has("fileID"):
			push_error("AssetDoc::ApplyModifications::InvalidTarget::%s" % m.target)
			continue
		if not m.target.guid is String:
			push_error("AssetDoc::ApplyModifications::InvalidTargetGuid::%s" % m.target)
			continue

		var cache_key = "%s:%s" % [m.target.guid, m.target.fileID]

		var target

		var test_for_many = false
		if test_for_many:
			# This is mainly to debug incorrect ufile_ids
			# A valid case for multiple to be found is a prefab with a copy of itself as a child
			target = find_nodes_by_ufile_id(cache_key, node) as Array[Node3D]
			if target.size() == 1:
				target = target[0]
			elif target.size() > 1:
				push_warning("AssetDoc::ApplyModifications::MultipleTargets::%s" % m)
				target = target[0]
			else: # == 0
				target = null
		else:
			# Only apply to the first one, hopefully it's correct, and not a nested one
			# This logic might be incorrect
			target = find_node_by_ufile_id(cache_key, node)

		if target == null:
			# https://forum.unity.com/threads/m_modification-doesnt-clear-old-references-when-the-prefab-is-modified.761219/
			# Subject: m_Modification doesn't clear old references when the prefab is modified
			# Unity Response: It's not a bug, but we're aware the design has some issues.			
			if false: push_warning("AssetDoc::ApplyModifications::TargetMissing::%s" % m)
			continue

#		if m.target.fileID == 4287472177597850 && m.propertyPath == "m_LocalPosition.x":
#			breakpoint

		if quat_builder.update(cache_key, target, m):
			continue

		var propertyPaths = (m.propertyPath as String).split(".")
		if propertyPaths[0] == "m_Materials":
			if !made_editable:
				made_editable = true
				# Allow more than position/name to be edited, including properties of child nodes
				parent.set_editable_instance(node, true)

#			m_Materials.Array.data[0]
#			m_Materials.Array.data[1]
			assert(propertyPaths.size() == 3)
			assert(propertyPaths[1] == "Array")

			assert(m.has("objectReference"))
			_apply_modifications__material(parent, node, propertyPaths[2], m.objectReference)
			continue

		# _appends_mods(target, m)
		match m.propertyPath:
			"m_IsActive":				target.visible = int(m.value) == 1
			"m_LocalPosition.x":		target.position.x = float(m.value) * -1.0 # Handedness Adjustment
			"m_LocalPosition.y":		target.position.y = float(m.value)
			"m_LocalPosition.z":		target.position.z = float(m.value)

			"m_LocalScale.x":			target.scale.x = float(m.value)
			"m_LocalScale.y":			target.scale.y = float(m.value)
			"m_LocalScale.z":			target.scale.z = float(m.value)

			"m_LocalEulerAnglesHint.x":	target.rotation.x = deg_to_rad(float(m.value))
			"m_LocalEulerAnglesHint.y":	target.rotation.y = deg_to_rad(float(m.value))
			"m_LocalEulerAnglesHint.z":	target.rotation.z = deg_to_rad(float(m.value))

			"m_Name":					target.name = m.value
			"m_Enabled":				target.visible = int(m.value) == 1
			_:
				push_warning("AssetDoc::ApplyModifications::UnexpectedPropertyPath::%s" % m)

	quat_builder.apply()

	return

#----------------------------------------

func _appends_mods(node: Node3D, mod: Dictionary):
	var mods = node.get_meta("mods", []) as Array
	mods.push_back(mod)
	node.set_meta("mods", mods)

#----------------------------------------
