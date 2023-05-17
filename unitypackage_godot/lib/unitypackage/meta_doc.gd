#----------------------------------------

# This wraps the {guid}/asset.meta yaml file as a dictionary

class_name MetaDoc

#----------------------------------------

# Do not store anything on this
# Store it on data for persistence

var upack: UPackGD
var asset: Asset
var data: Dictionary

#----------------------------------------

func _init(_upack: UPackGD, _asset: Asset, _data: Dictionary):
	upack = _upack
	asset = _asset
	data = _data

#----------------------------------------

func _to_string():
	return "[MetaDoc] %s | %s | %s | Folder: %s" % [
		asset.pathname,
		data.type,
		"Yes" if data.folderAsset == true else "No",
		data.guid
	]

#----------------------------------------

func _get(property: StringName):
	if data == null || !data.has(property):
		return null

	return data.get(property)

#----------------------------------------
