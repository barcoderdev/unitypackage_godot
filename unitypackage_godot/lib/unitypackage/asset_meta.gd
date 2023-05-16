#----------------------------------------

class_name AssetMeta

#----------------------------------------

# Do not store anything on this
# Store it on data for persistence

var uurs: UPackRS
var asset: Asset
var data: Dictionary

#----------------------------------------

func _init(_uurs: UPackRS, _asset: Asset, _data: Dictionary):
	uurs = _uurs
	asset = _asset
	data = _data

#----------------------------------------

func _to_string():
	return "[AssetMeta] %s | %s | %s | Folder: %s" % [
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
