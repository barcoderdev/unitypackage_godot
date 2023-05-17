#----------------------------------------

class_name UPackGDConfig
extends Resource

#----------------------------------------

@export var unitypackage_util_path: String = "res://unitypackage_util"
@export var fbx2gltf_path: String = "res://FBX2glTF"
@export var extract_path: String = "res://imports/"

@export var debug_log: bool = true

@export var immediate_load_assets: bool = true

@export var default_open_path: String = ""

#----------------------------------------

var enable_disk_storage: bool = true
var enable_memcache: bool = true

#----------------------------------------
