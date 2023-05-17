# UnityPackage Godot

- Requires [barcoderdev/FBX2glTF](https://github.com/barcoderdev/FBX2glTF) at `res://FBX2glTF`
  - Download latest version at: https://github.com/barcoderdev/FBX2glTF/actions/runs/4994628239 (Login to Github first)
- Requires [barcoderdev/unitypackage_util](https://github.com/barcoderdev/unitypackage_util) at `res://unitypackage_util`
  - Download latest version at: https://github.com/barcoderdev/unitypackage_util/actions/runs/4997846696 (Login to Github first)
- Make sure you can run `./FBX2glTF --help` and `./unitypackage_util --help` from command line, to check permissions
- Config in `res://unitypackage_godot_config.tres`

## Notes

- This has only been tested with Godot 4.0.2 on macOS
- Main scene in `res://unitypackage_godot/scenes/main.tscn`
- Uncheck `Immediate Load Assets` in `res://unitypackage_godot_config.tres` to only load what is opened in the UI
- `*.unity` files are converted if they are manually loaded in the UI
- Each node is tagged with a meta named `ufile_ids`, containing a list of `{guid}:{component}` values mapping back to the original Unity component.

## How it works

- `OS.execute` is used to call `unitypackage_util`
- `unitypackage_util {PACKAGE} dump` retrieves all the packed file data
- `unitypackage_util {PACKAGE} extract {GUID} --json` is used to extract individual yaml files as json
- `unitypackage_util {PACKAGE} extract {GUID} --fbx2gltf --base64` is used to extract fbx files, converted to glb, in base64 format
- Assets in the UI are tracked by GUID and extracted
- JSON data is walked to rebuild in native format, extracting more files as necessary
- Models, meshes, images, materials, scenes(?? *.unity files), prefabs, are saved to disk as they are loaded/converted
- FBX2glTF was modified to allow stdin/stdout, and to store pivot/transform-origin on each node
- PivotFixer(GLTFDocumentExtension) uses this extra stored data to apply transform origin, later used when building the MeshInstance3D nodes
- Left-to-right hand conversions are handled by -X positions and -X/-W quaternions

## Currently Implemented

Components:

- GameObject
- MeshFilter
- MeshRenderer (partially, needs more attributes mapped)
- SkinnedMeshRenderer (partially, needs Skeleton3D)
- Transform
- Stripped Transform

Importers:

- DefaultImporter
- ModelImporter
- NativeFormatImporter
- PrefabImporter
- TextureImporter

## Todo

Components:

- Skeleton3D on SkinnedMeshRenderer
- BoxCollider
- CapsuleCollider
- MeshCollider
- SphereCollider

Misc:

- Import audio assets
- More material properties
- Convert unitypackage_util to GDExtension: https://github.com/godot-rust/gdext
   - with fbx2gltf included: https://docs.rs/cxx/latest/cxx/
