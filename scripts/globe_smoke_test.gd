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
    # The Earth uses a ShaderMaterial so the satellite image can retain
    # its land detail while the shader recolours only ocean pixels.
    var earth_material := earth.material_override as ShaderMaterial
    if earth_material == null:
        push_error("Earth globe is missing its satellite ShaderMaterial")
        quit(1)
        return
    var satellite_texture := earth_material.get_shader_parameter("earth_texture") as Texture2D
    if satellite_texture == null:
        push_error("Satellite texture was not assigned to the Earth shader")
        quit(1)
        return
    var earth_arrays := earth.mesh.surface_get_arrays(0)
    var earth_uvs: PackedVector2Array = earth_arrays[Mesh.ARRAY_TEX_UV]
    for x in range(193):
        if absf(earth_uvs[x].x - 0.5) > 0.0001:
            push_error("North pole UVs are not collapsed; polar texture streaks may appear")
            quit(1)
            return
    var south_pole_start := 96 * 193
    for x in range(193):
        if absf(earth_uvs[south_pole_start + x].x - 0.5) > 0.0001:
            push_error("South pole UVs are not collapsed; polar texture streaks may appear")
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
    if not (globe.detail_material is ShaderMaterial):
        push_error("Regional detail layer is missing its feathered blend shader")
        quit(1)
        return
    if globe.detail_patch.visible:
        push_error("Regional detail overlay must stay hidden at overview zoom")
        quit(1)
        return
    if globe.city_labels.size() < 15:
        push_error("Close-zoom city label layer is incomplete")
        quit(1)
        return
    if globe.country_lock_labels.size() != globe.country_route.size():
        push_error("A lock marker is missing for one or more route countries")
        quit(1)
        return
    var locked_route_markers := 0
    for lock_label in globe.country_lock_labels:
        if int(lock_label.get_meta("route_index", -1)) > globe.unlocked_index:
            locked_route_markers += 1
    if locked_route_markers != globe.country_route.size() - globe.unlocked_index - 1:
        push_error("Locked route markers do not cover every locked destination")
        quit(1)
        return
    if globe.country_order_labels.size() != globe.country_route.size():
        push_error("A route sequence number is missing")
        quit(1)
        return
    for route_index in range(globe.country_route.size()):
        var code: String = globe.country_route[route_index]
        var lock: Node3D = globe.get_node_or_null("CountryLock_" + code)
        if lock == null:
            push_error("A 3D lock assembly is missing for a route destination")
            quit(1)
            return
        var body := lock.get_node_or_null("MetalBody") as MeshInstance3D
        var shackle := lock.get_node_or_null("Shackle") as MeshInstance3D
        var keyway := lock.get_node_or_null("IlluminatedKeyway") as MeshInstance3D
        var panel := lock.get_node_or_null("ElectronicPanel") as MeshInstance3D
        var status_led := lock.get_node_or_null("StatusLED") as MeshInstance3D
        var circuit := lock.get_node_or_null("CircuitAccent") as MeshInstance3D
        var order := lock.get_node_or_null("SequenceNumber") as Label3D
        var number_frame := lock.get_node_or_null("SequenceNumberFrame") as MeshInstance3D
        var number_plate := lock.get_node_or_null("SequenceNumberPlate") as MeshInstance3D
        var number_accent := lock.get_node_or_null("SequenceNumberAccent") as MeshInstance3D
        if body == null or shackle == null or keyway == null or panel == null or status_led == null or circuit == null:
            push_error("Electronic lock is missing its shell, shackle, glass panel, sensor, or LED details")
            quit(1)
            return
        if lock.scale.x > 0.21 or lock.scale.y > 0.21 or lock.scale.z > 0.21:
            push_error("Electronic lock is too large and may cover the country map")
            quit(1)
            return
        var body_material := body.material_override as StandardMaterial3D
        if body_material == null or body_material.metallic < 0.75:
            push_error("Lock body is missing its metallic finish")
            quit(1)
            return
        var gray := body_material.albedo_color
        if absf(gray.r - gray.g) > 0.12 or absf(gray.g - gray.b) > 0.12:
            push_error("Lock body is not a neutral metallic gray")
            quit(1)
            return
        if number_frame == null or number_plate == null or number_accent == null:
            push_error("Futuristic sequence number badge is missing its frame, plate, or cyan accent")
            quit(1)
            return
        if order == null or order.text != "%02d" % (route_index + 1) or order.scale.x < 2.39:
            push_error("Country lock sequence number is incorrect")
            quit(1)
            return
    for route_index in range(1, 30):
        if globe.country_route[route_index] == globe.country_route[route_index - 1]:
            push_error("Route contains a repeated consecutive country")
            quit(1)
            return
    if globe.get_node_or_null("AccurateGeographicCountryBorders") == null:
        push_error("Accurate country border overlay was not created")
        quit(1)
        return
    print("WORLD_GLOBE_SATELLITE_TEXTURE_OK")
    print("WORLD_GLOBE_CLOUD_LAYER_OK")
    print("WORLD_GLOBE_REGIONAL_DETAIL_BLEND_OK")
    print("WORLD_GLOBE_POLAR_UV_OK")
    print("WORLD_GLOBE_CITY_LABELS_OK")
    print("WORLD_GLOBE_COMPACT_LOCKS_OK")
    print("WORLD_GLOBE_FUTURISTIC_SEQUENCE_BADGES_OK")
    print("WORLD_GLOBE_BORDER_OVERLAY_OK")
    print("WORLD_GLOBE_SMOKE_OK")
    quit()
