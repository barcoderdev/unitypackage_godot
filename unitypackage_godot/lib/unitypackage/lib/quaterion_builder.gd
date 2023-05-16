#----------------------------------------

class_name QuaternionBuilder

#----------------------------------------

var cache: Dictionary = {}

#----------------------------------------

func update(ufile_id: String, target: Node3D, mod: Dictionary) -> bool:
	var prop = (mod.propertyPath as String).split(".")
	if prop[0] != "m_LocalRotation":
		return false

	if !cache.has(ufile_id):
		cache[ufile_id] = [target, Vector4(0, 0, 0, 1)]

	var f = float(mod.value)
	match prop[1]:
		"x": cache[ufile_id][1].x = f # QUAT-FIX: BELOW! NOT HERE
		"y": cache[ufile_id][1].y = f
		"z": cache[ufile_id][1].z = f
		"w": cache[ufile_id][1].w = f
		_:
			push_error("QuaternionBuilder::Update::UnexpectedProperty::%s" % mod)
			return false

	return true

#----------------------------------------

func apply() -> void:
	for key in cache:
		var node = cache[key][0]
		var v4 = cache[key][1]
		var quat = Quaternion(
			v4.x * -1.0, # Handedness Adjustment
			v4.y,
			v4.z,
			v4.w * -1.0 # Handedness Adjustment
		)
		node.quaternion = quat

#----------------------------------------
