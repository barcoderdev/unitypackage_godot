#----------------------------------------

# This wraps the individual yaml documents in the {guid}/asset file
# if {guid}/asset is a yaml file in the package
# All converted to a dictionary

class_name CompDoc extends CompDocBase

#----------------------------------------

const breakpoints_enabled: bool = false

#----------------------------------------

func comp_doc_scene(root_node: Node3D, parent: Node3D) -> Node3D:
	match data.type:
		"Transform":
			if is_stripped_transform():
				return comp_doc_stripped_transform(root_node, parent)
			else:
				return comp_doc_transform(root_node, parent)
		"MeshFilter":
			return comp_doc_mesh_filter(root_node, parent)
		"Prefab":
			return comp_doc_prefab(root_node, parent)
		"PrefabInstance":
			return comp_doc_prefab_instance(root_node, parent)
		_:
			push_error("CompDoc::Scene::UnsupportedType::%s" % data.type)
			return null

#----------------------------------------

func comp_doc_transform(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("Transform", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	trace("Transform", "Building", Color.GREEN)
	
	var gameobject_doc = get_comp_doc_by_ref(data.content.m_GameObject)

	var transform_node = Node3D.new()
	if parent != null:
		parent.add_child(transform_node)
		transform_node.owner = choose_correct_owner(root_node, parent)
	if root_node == null:
		root_node = transform_node

	transform_node.scale = to_scale(data.content.m_LocalScale)
	transform_node.position = to_position(data.content.m_LocalPosition)
	transform_node.quaternion = to_quaternion(data.content.m_LocalRotation)
	set_created_by(transform_node, "CompDoc::Transform")
	append_ufile_ids(transform_node, [self._ufile_id], "CompDocTransform")

	gameobject_doc.apply_component(root_node, parent, transform_node)

	for comp_ref in data.content.m_Children:
		var comp_doc = get_comp_doc_by_ref(comp_ref)
		comp_doc.comp_doc_scene(root_node, transform_node)

	if transform_node == null:
		push_error("CompDoc::Transform::BuildFailed")
		return null

	return transform_node

#----------------------------------------

func comp_doc_stripped_transform(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("StrippedTransform", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	var prefab_doc
	var prefab_asset

	if data.content.has("m_PrefabInstance"):
		prefab_doc = get_comp_doc_by_ref(data.content.m_PrefabInstance)
		
		if breakpoints_enabled && !prefab_doc.content.has("m_SourcePrefab") || prefab_doc.content.m_SourcePrefab.fileID != "100100000":
			breakpoint
		prefab_asset = upack.get_asset(prefab_doc.content.m_SourcePrefab.guid)
	elif data.content.has("m_PrefabInternal"):
		prefab_doc = get_comp_doc_by_ref(data.content.m_PrefabInternal)
		if breakpoints_enabled && !prefab_doc.content.has("m_ParentPrefab") || prefab_doc.content.m_ParentPrefab.fileID != "100100000":
			breakpoint
		prefab_asset = upack.get_asset(prefab_doc.content.m_ParentPrefab.guid)
	else:
		if breakpoints_enabled:
			breakpoint
		return null

	if not prefab_asset is Asset:
		push_error("CompDoc::StrippedTransform::PrefabAssetMissing::%s" % self)
		return null

	var prefab = prefab_asset.asset_scene(root_node, parent)
	_apply_modifications(parent, prefab, prefab_doc)

	var child_prefabs = asset.docs.filter(func(doc: CompDoc):
		if !doc.is_prefab() && !doc.is_prefab_instance():
			return false
		# Prefab.m_Modification.m_TransformParent
		var prefab_parent = doc.content.m_Modification.m_TransformParent
		return prefab_parent.fileID == data._file_id
	) as Array[CompDoc]

	for child_doc in child_prefabs:
		# Find transform that has this prefab child
		var child_transform_docs = asset.docs.filter(func(doc: CompDoc):
			if !is_stripped_transform():
				return false
			if doc.content.has("m_PrefabInternal"):
				return doc.content.m_PrefabInternal.fileID == child_doc._file_id
			if doc.content.has("m_PrefabInstance"):
				return doc.content.m_PrefabInstance.fileID == child_doc._file_id
			return false
		) as Array[CompDoc]

		var child_transform_count = child_transform_docs.size()
		if child_transform_count == 0:
			# leaf node, just build it
			child_doc.comp_doc_scene(root_node, prefab)
		elif child_transform_count == 1:
			# build the transform for it since it may contain children
			child_transform_docs.front().comp_doc_scene(root_node, prefab)
		else:
			push_error("CompDoc::StrippedTransform::TooManyChildPrefabTransform::%s" % self)
			if breakpoints_enabled:
				breakpoint

	return prefab

#----------------------------------------

func comp_doc_prefab(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("Prefab", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	trace("Prefab", "Building", Color.GREEN)

	var prefab_doc = upack.get_asset_by_ref(data.content.m_ParentPrefab)
	if not prefab_doc is Asset:
		return null

	var node = prefab_doc.asset_scene(root_node, parent)

	set_created_by(node, "CompDoc::Prefab")
	append_ufile_ids(node, [self._ufile_id], "CompDocPefab")
	_apply_modifications(parent, node, self)

	return node

#----------------------------------------

func comp_doc_prefab_instance(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("PrefabInstance", "%s::%s" % [
		str(self),
		"ROOT" if root_node == null else "CHILD"
	], Color.ORANGE)

	trace("PrefabInstance", "Building", Color.GREEN)

	var prefab_doc = upack.get_asset_by_ref(data.content.m_SourcePrefab)
	if prefab_doc == null:
		push_error("CompDoc::PrefabInstance::SourcePrefabMissing::%s" % self)
		return null
	var node = prefab_doc.asset_scene(root_node, parent)

	set_created_by(node, "CompDoc::PrefabInstance")
	append_ufile_ids(node, [self._ufile_id], "CompDocPrefabInstance")
	_apply_modifications(parent, node, self)

	return node

#----------------------------------------

func comp_doc_mesh_filter(root_node: Node3D, parent: Node3D) -> Node3D:
	trace("MeshFilter")

	if upack.enable_memcache && data.has("_memcache_mesh_filter"):
		trace("MeshFilter", "FromMemCache", Color.GREEN)
		return duplicate(
			root_node,
			parent,
			data._memcache_mesh_filter,
			"MeshFilter 1"
		)

	var mesh_ref = data.content.m_Mesh
	var new_node: Node3D = Node3D.new()

	if not mesh_ref.guid is String && mesh_ref.guid == 0 && mesh_ref.fileID == "10209":
		_comp_doc_mesh_filter__plane(root_node, parent, new_node)
	else:
		_comp_doc_mesh_filter__mesh_from_ref(root_node, parent, new_node, mesh_ref)

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
# TODO: This can probably be removed after more testing, using the "false" logic
const use_pivot_wrapper: bool = false

#----------------------------------------

func _comp_doc_mesh_filter__plane(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
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

func _comp_doc_mesh_filter__mesh_from_ref(root_node: Node3D, parent: Node3D, transform_node: Node3D, mesh_ref: Dictionary) -> void:
	var mesh_asset = upack.get_asset_by_ref(mesh_ref)
	if mesh_asset == null:
		push_error("CompDoc::MeshFilter::GetAssetFailed:%s" % mesh_ref)
		return

	var mesh_name: Variant = _comp_doc_mesh_filter__mesh_from_ref__find_mesh_name(mesh_asset, mesh_ref)
	var scene: Node = _comp_doc_mesh_filter__mesh_from_ref__gltf_scene(mesh_asset)
	var mesh_save_name = ""

	if scene == null:
		push_error("CompDoc::MeshFilter::GltfSceneFailed::%s::%s" % [
			mesh_asset,
			mesh_ref
		])
		return

	var mesh
	var search
	if mesh_name != null && mesh_name != "":
		search = search_for_node(scene, func(n):
			if mesh_name == n.name && n is MeshInstance3D:
				return n
			return
		)
		if search == null && mesh_name.begins_with("//"):
			# Try searching without the prefixed "//"
			mesh_name = mesh_name.substr(2)
			search = search_for_node(scene, func(n):
				if mesh_name == n.name && n is MeshInstance3D:
					if breakpoints_enabled:
						breakpoint
					return n
				return
			)
		if search == null:
			push_error("CompDoc::MeshFilter::MeshNameSearchFailed::%s::%s" % [
				mesh_name,
				mesh_ref
			])
			return

		mesh = search.mesh
		mesh_save_name = mesh_name
	else: # mesh_name == null
		var str_fileID = str(mesh_ref.fileID)
		search = search_for_node(scene, func(n):
			if not n is MeshInstance3D:
				return

			# https://forum.unity.com/threads/how-to-control-fileid-using-custom-scriptedimporter.1384596/
			# https://forum.unity.com/threads/fbx-submesh-fileids.948882/
			# xxhash(`Type:${obj.GetType().Name}->${id}0`)
			var hash_text = "Type:Mesh->%s0" % original_name(n.name)
			var hash_val: String = upack.xxhash64(hash_text)
			# print("%s | %s == %s" % [hash_text, hash_val, str_fileID])

			if hash_val == str_fileID:
				mesh_save_name = original_name(n.name)
				return n

			if hash_val.left(-4) == str_fileID.left(-4):
				# This should have been resolved by the fileID as String fix
				# TODO: Remove this at some point
				push_error("CompDoc::MeshFilter::PrecisionIssue::%s::%s" % [
					hash_val,
					str_fileID
				])
				if breakpoints_enabled:
					breakpoint
		)
		if search == null:
			push_error("CompDoc::MeshFilter::MeshXXHashSearchFailed::%s" % mesh_ref)
			return

		mesh = search.mesh
		mesh_name = search.name
	if upack.enable_disk_storage:
		var asset_storage_path = mesh_asset.disk_storage_path()
		var mesh_storage_path = "%s%s/%s_%s.tscn" % [
			asset_storage_path.get_basename(),
			"_mesh",
			mesh_save_name, # TODO: Sanitize for filesystem
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
	set_created_by(instance, "CompDoc::MeshFilter")

	# Wrap the mesh instance
	if use_pivot_wrapper && search.position != Vector3.ZERO:
		# The rotation goes on the pivot_offset wrapper
		instance.quaternion = Quaternion.IDENTITY

		# Mesh instance goes into pivot_offset, offset by pivot position
		# amount set on the node by GLTF PivotFixer.
		# This allows pivot_offset to be translated/rotated
		# without being affected by the mesh instance offset.
		# Using this wrapper can make fixing issues easier after import.
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
		transform_node.add_child(instance)
		instance.owner = choose_correct_owner(root_node, parent, transform_node)

#----------------------------------------

func _comp_doc_mesh_filter__mesh_from_ref__find_mesh_name(mesh_asset: Asset, mesh_ref: Dictionary):
	var mesh_name: Variant

	if mesh_asset.meta.content.has("fileIDToRecycleName"):
		mesh_name = (mesh_asset
			.meta
			.content
			.fileIDToRecycleName
			.get(str(mesh_ref.fileID), "")
		)
		if mesh_name == null:
			push_error("CompDoc::MeshFilter::fileIDToRecycleName::MissingMeshName::%s" % mesh_ref)
			return null
	elif mesh_asset.meta.content.has("internalIDToNameTable"):
		var entry = (mesh_asset
			.meta
			.content
			.internalIDToNameTable
			.filter(func(item):
				var key = item.first.keys().front()
				return str(item.first[key]) == mesh_ref.fileID
		))
		if entry.size() > 0:
			mesh_name = entry[0].second
		if mesh_name == null:
			return null
	else:
		push_error("CompDoc::MeshFilter::MissingMeshLookupDict::%s" % mesh_asset)
		push_error("...LookingFor::%s" % mesh_ref)
		return null

	return mesh_name

#----------------------------------------

func _comp_doc_mesh_filter__mesh_from_ref__gltf_scene(mesh_asset: Asset):
	if mesh_asset.upack.enable_memcache && data.has("_memcache_gltf_scene"):
		return mesh_asset.data._memcache_gltf_scene

	# Full thing has not been loaded yet
	var buffer = mesh_asset.load_binary()
	if buffer == null:
		push_error("CompDoc::MeshFilter::BufferEmpty")
		return null

	var doc = GLTFDocument.new()
	var state = GLTFState.new()

	var result
	if mesh_asset.data.has("_disk_storage_binary_path"):
		result = doc.append_from_file(mesh_asset.data._disk_storage_binary_path, state)
	else:
		result = doc.append_from_buffer(buffer, "", state)

	if result != OK:
		push_error("CompDoc::MeshFilter::AppendFromBufferFailed::%d" % result)
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
		"Light":
			_apply_component__light(root_node, parent, transform_node)
		"Camera":
			_apply_component__camera(root_node, parent, transform_node)
		"BoxCollider", "CapsuleCollider", "MeshCollider", "SphereCollider":
			# TODO
			trace("ApplyComponent", "TODO::%s" % self)
		"Animator", "Animation", "AudioListener", "Behaviour", "MonoBehaviour", "ReflectionProbe", "CharacterController", "NavMeshAgent", "LODGroup", "Terrain", "TerrainCollider":
			# Don't need?
			trace("ApplyComponent", "Skipping::%s" % self)
		"ParticleSystem", "ParticleSystemRenderer":
			# Heh
			trace("ApplyComponent", "UnlikelyTODO::%s" % self)
		_:
			push_error("CompDoc::Apply::UnsupportedType::%s" % data.type)

#----------------------------------------

func _apply_component__game_object(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyGameObject", "%s::%s" % [
		data.content.m_Name,
		self
	], Color.CYAN)

	if self.content.m_Name == null:
		push_warning("CompDoc::BuildGameObject::NoName::%s" % self)
	else:
		transform_node.name = data.content.m_Name

	transform_node.visible = data.content.m_IsActive == 1

	append_ufile_ids(transform_node, [self._ufile_id], "ApplyComponentGameObject::%s" % self)

	var component_refs = data.content.m_Component as Array
	# Sort to mesh filter becomes before mesh renderer, etc
	component_refs.sort_custom(_helper_sort_component_ref)

	for comp_ref in component_refs:
		if !comp_ref.component.has("guid") && comp_ref.component.fileID == self._file_id:
			# Avoid recursion
			trace("SkippingSelfReference", str(comp_ref), Color.ORANGE_RED)
			push_warning("CompDoc::BuildGameObject::SkippingSelfReference::%s::%s" % [
				self,
				comp_ref
			])
			continue

		var comp = get_comp_doc_by_ref(comp_ref.component)
		
		if comp == null:
			push_warning("CompDoc::BuildGameObject::ComponentDocNotFound::%s" % comp_ref)
			continue
		
		if comp.type == "Transform":
			# This is the transform that is applying this game object doc
			continue

		# trace("ApplyGameObjectComponent", str(comp_ref), Color.MEDIUM_SLATE_BLUE)

		append_ufile_ids(transform_node, [comp._ufile_id], "ApplyComponentGameObject::Component::%s" % comp)
		comp.apply_component(root_node, parent, transform_node)

#----------------------------------------

func _apply_component__camera(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_Camera")

	# TODO: More attributes
	var camera = Camera3D.new()
	camera.name = "_Camera"
	camera.fov = data.content["field of view"]
	camera.rotate_y(deg_to_rad(180.0))
	transform_node.add_child(camera)
	camera.owner = choose_correct_owner(root_node, parent, transform_node)

#----------------------------------------

enum UnityLightType {
	Spot = 0,
	Directional = 1,
	Point = 2,
	Area = 3,
}

func _apply_component__light(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_Light")

	# TODO: More attributes
	var light: Light3D
	var light_type = data.content.m_Type as UnityLightType
	match light_type:
		UnityLightType.Spot:
			light = SpotLight3D.new()
			light.name = "_Spot"
			light.spot_angle = data.content.m_SpotAngle
		UnityLightType.Directional:
			light = DirectionalLight3D.new()
			light.name = "_Directional"
		UnityLightType.Point:
			light = OmniLight3D.new()
			light.name = "_Point"
			light.omni_range = data.content.m_Range
		UnityLightType.Area:
			light = OmniLight3D.new()
			light.name = "_Area"

	if light != null:
		light.light_energy = data.content.m_Intensity
		light.visible = data.content.m_Enabled == 1
		light.light_color = to_color(data.content.m_Color)
		transform_node.add_child(light)
		light.owner = choose_correct_owner(root_node, parent, transform_node)
		light.rotate_y(deg_to_rad(180.0))

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

	# Skinned mesh transforms are controlled by animations
	# Reset them here since they might be defaulted to odd values
	transform_node.position = Vector3.ZERO
	transform_node.scale = Vector3.ONE
	for_all_nodes(transform_node, func(node):
		if node is MeshInstance3D: # Only the meshes & parent transforms, not skeleton
			node.position = Vector3.ZERO
			node.scale = Vector3.ONE
			var p = node.get_parent()
			p.position = Vector3.ZERO
			p.scale = Vector3.ONE
	)

	# TODO: Skeleton, attachments

#----------------------------------------

func _apply_component__mesh_filter(root_node: Node3D, parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_MeshFilter")

	var mesh_ref = data.content.m_Mesh
	var guid = str(mesh_ref.get("guid", "0"))
	if guid == "0" && mesh_ref.fileID == "10209":
		_comp_doc_mesh_filter__plane(root_node, parent, transform_node)
	else:
		_comp_doc_mesh_filter__mesh_from_ref(root_node, parent, transform_node, mesh_ref)

#----------------------------------------

func _apply_component__mesh_renderer(_root_node: Node3D, _parent: Node3D, transform_node: Node3D) -> void:
	trace("ApplyComponent_MeshRenderer")

	var materials = data.content.m_Materials.map(func(mat_ref):
		if !mat_ref.has("guid"):
			push_warning("CompDoc::ApplyComponentMeshRenderer::MatRefMissingGuid::%s" % mat_ref)
			# TODO: Check why GUID would be missing: { fileID: "0" } only
			if breakpoints_enabled:
				breakpoint
			return StandardMaterial3D.new()
		elif mat_ref.guid == BUILT_IN_SHADER_GUID:
			return StandardMaterial3D.new()
		else:
			var material = upack.get_asset_by_ref(mat_ref)
			if material == null:
				push_warning("CompDoc::ApplyComponentMeshRenderer::AssetNotFound::%s" % mat_ref)
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

const COMPONENT_PROCESSING_SEQUENCE = {
	"Transform": 0,
	"MeshRenderer": 30,
	"MeshFilter": 20
}

func _helper_sort_component_ref(a, b):
	var comp_a = get_comp_doc_by_ref(a.component)
	var comp_b = get_comp_doc_by_ref(b.component)
	if comp_a == null:
		push_warning("CompDoc::HelperSort::CompANotFound::%s" % a)
		return false
	if comp_b == null:
		push_warning("CompDoc::HelperSort::CompBNotFound::%s" % b)
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

	var mat_asset = upack.get_asset_by_ref(mat_ref)
	if mat_asset == null:
		return

	var material = mat_asset.asset_material()

	for_all_nodes(node, func(child: Node):
		if child is MeshInstance3D && index < child.get_surface_override_material_count():
			child.set_surface_override_material(index, material)
	)

#----------------------------------------

func _apply_modifications(parent: Node3D, node: Node3D, prefab_doc: CompDoc):
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
			"m_StaticEditorFlags":			continue

		if !m.target.has("guid") || !m.target.has("fileID"):
			push_error("CompDoc::ApplyModifications::InvalidTarget::%s::%s" % [
				m.target,
				prefab_doc
			])
			continue
		if not m.target.guid is String:
			push_error("CompDoc::ApplyModifications::InvalidTargetGuid::%s::%s" % [
				m.target,
				prefab_doc
			])
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
				push_warning("CompDoc::ApplyModifications::MultipleTargets::%s" % m)
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
			if false: push_warning("CompDoc::ApplyModifications::TargetMissing::%s" % m)
			continue

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

		# Stop these from generating TargetMissing warnings
		# TODO: Implement at some point
		match propertyPaths[0]:
			"InitialModule":	continue
			"NoiseModule":		continue
			"EmissionModule":	continue
			"ShapeModule":		continue
			"ColorModule":		continue

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
				push_warning("CompDoc::ApplyModifications::UnexpectedPropertyPath::%s" % m)

	quat_builder.apply()

	return

#----------------------------------------

func _appends_mods(node: Node3D, mod: Dictionary):
	var mods = node.get_meta("mods", []) as Array
	mods.push_back(mod)
	node.set_meta("mods", mods)

#----------------------------------------
