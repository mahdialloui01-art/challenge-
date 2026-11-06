extends SceneTree

const WorldGlobe = preload("res://scripts/world_globe.gd")

func _initialize() -> void:
    var globe = WorldGlobe.new()
    root.add_child(globe)
    await process_frame
    if str(globe.get_route_country_name(0)) != "الجزائر":
        push_error("World globe route did not start in Algeria")
        quit(1)
        return
    if str(globe.get_route_country_name(1)) != "تونس":
        push_error("World globe second country is not Tunisia")
        quit(1)
        return
    if not ResourceLoader.exists("res://assets/earth_surface.jpg"):
        push_error("NASA satellite Earth texture was not packaged")
        quit(1)
        return
    var earth := globe.get_child(0) as MeshInstance3D
    if earth == null or not (earth.mesh is ArrayMesh):
        push_error("Earth globe is not using the custom geographic UV mesh")
        quit(1)
        return
    var earth_material := earth.material_override as StandardMaterial3D
    if earth_material == null or earth_material.albedo_texture == null:
        push_error("Satellite texture was not assigned to the Earth material")
        quit(1)
        return
    var clouds := globe.get_node_or_null("AnimatedCloudShell") as MeshInstance3D
    if clouds == null or clouds.material_override == null:
        push_error("Animated cloud shell was not created")
        quit(1)
        return
    if globe.detail_patch == null or globe.detail_material == null:
        push_error("Expanded North Africa satellite detail layer was not created")
        quit(1)
        return
    print("WORLD_GLOBE_SATELLITE_TEXTURE_OK")
    print("WORLD_GLOBE_CLOUD_LAYER_OK")
    print("WORLD_GLOBE_REGIONAL_DETAIL_OK")
    print("WORLD_GLOBE_SMOKE_OK")
    quit()
