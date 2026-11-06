extends Node3D

signal country_tapped(country_index: int, country_code: String, country_name: String, unlocked: bool)

const DATA_PATH := "res://data/countries_world.json"
const GLOBE_RADIUS := 3.0
var country_route: Array[String] = [
    "DZA", "TUN", "LBY", "EGY", "MAR", "MRT", "NER", "MLI", "TCD", "SDN",
    "SEN", "GHA", "NGA", "ETH", "KEN", "ZAF", "ESP", "FRA", "ITA", "TUR",
    "SAU", "JOR", "ARE", "IND", "CHN", "JPN", "BRA", "USA", "CAN", "AUS"
]
const ARABIC_NAMES := {
    "DZA":"الجزائر", "TUN":"تونس", "LBY":"ليبيا", "EGY":"مصر", "MAR":"المغرب",
    "MRT":"موريتانيا", "NER":"النيجر", "MLI":"مالي", "TCD":"تشاد", "SDN":"السودان",
    "SEN":"السنغال", "GHA":"غانا", "NGA":"نيجيريا", "ETH":"إثيوبيا", "KEN":"كينيا",
    "ZAF":"جنوب إفريقيا", "ESP":"إسبانيا", "FRA":"فرنسا", "ITA":"إيطاليا", "TUR":"تركيا",
    "SAU":"السعودية", "JOR":"الأردن", "ARE":"الإمارات", "IND":"الهند", "CHN":"الصين",
    "JPN":"اليابان", "BRA":"البرازيل", "USA":"الولايات المتحدة", "CAN":"كندا", "AUS":"أستراليا"
}

var features_by_code: Dictionary = {}
var unlocked_index := 0
var drag_active := false
var drag_start := Vector2.ZERO
var last_pointer := Vector2.ZERO
var pointer_moved := false
var rotation_velocity := Vector2.ZERO
var globe_mesh: MeshInstance3D

func _ready() -> void:
    set_process_input(true)
    set_process(true)
    _build_globe()

func set_progress(index: int) -> void:
    unlocked_index = clampi(index, 0, country_route.size() - 1)

func get_country_name(code: String) -> String:
    if ARABIC_NAMES.has(code):
        return str(ARABIC_NAMES[code])
    if features_by_code.has(code):
        return str(features_by_code[code].get("n", code))
    return code

func get_route_country_name(index: int) -> String:
    if index >= 0 and index < country_route.size():
        return get_country_name(country_route[index])
    return "اكتملت الرحلة"

func _append_remaining_countries() -> void:
    for code_variant in features_by_code.keys():
        var code := str(code_variant)
        if not country_route.has(code):
            country_route.append(code)

func _build_globe() -> void:
    var sphere := SphereMesh.new()
    sphere.radius = GLOBE_RADIUS
    sphere.height = GLOBE_RADIUS * 2.0
    sphere.radial_segments = 96
    sphere.rings = 64
    globe_mesh = MeshInstance3D.new()
    globe_mesh.mesh = sphere
    var ocean := StandardMaterial3D.new()
    ocean.albedo_color = Color("#092e58")
    ocean.metallic = 0.18
    ocean.roughness = 0.34
    ocean.emission_enabled = true
    ocean.emission = Color("#06244b")
    ocean.emission_energy_multiplier = 0.35
    globe_mesh.material_override = ocean
    add_child(globe_mesh)

    var atmosphere := MeshInstance3D.new()
    var halo := SphereMesh.new()
    halo.radius = GLOBE_RADIUS * 1.035
    halo.height = GLOBE_RADIUS * 2.07
    halo.radial_segments = 64
    halo.rings = 32
    atmosphere.mesh = halo
    var halo_mat := StandardMaterial3D.new()
    halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo_mat.albedo_color = Color(0.15, 0.62, 1.0, 0.10)
    halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_mat.no_depth_test = true
    atmosphere.material_override = halo_mat
    add_child(atmosphere)

    _load_country_geometry()
    _append_remaining_countries()

    var light := OmniLight3D.new()
    light.position = Vector3(-4.0, 4.0, 6.0)
    light.light_color = Color("#9bcfff")
    light.light_energy = 2.2
    light.omni_range = 16.0
    add_child(light)

    var rim := MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 3.16
    ring.outer_radius = 3.19
    rim.mesh = ring
    rim.rotation_degrees.x = 90.0
    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.albedo_color = Color("#38aaff")
    ring_mat.emission_enabled = true
    ring_mat.emission = Color("#147dff")
    rim.material_override = ring_mat
    add_child(rim)

func _load_country_geometry() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Missing offline country boundaries: " + DATA_PATH)
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not parsed is Dictionary:
        push_error("Invalid country boundary data")
        return
    var features: Array = parsed.get("features", [])
    var line_material := StandardMaterial3D.new()
    line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    line_material.albedo_color = Color("#8ddcff")
    line_material.emission_enabled = true
    line_material.emission = Color("#267dbd")
    line_material.emission_energy_multiplier = 0.65
    for feature in features:
        if not feature is Dictionary:
            continue
        var code := str(feature.get("i", ""))
        if code.is_empty():
            continue
        features_by_code[code] = feature
        var country_lines := MeshInstance3D.new()
        var immediate := ImmediateMesh.new()
        var polygons: Array = feature.get("g", [])
        for polygon in polygons:
            for ring in polygon:
                if not ring is Array or ring.size() < 4:
                    continue
                immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_material)
                for coord in ring:
                    immediate.surface_add_vertex(_geo_to_sphere(float(coord[0]), float(coord[1]), GLOBE_RADIUS + 0.012))
                immediate.surface_end()
        country_lines.mesh = immediate
        country_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(country_lines)

    _add_country_labels()

func _add_country_labels() -> void:
    for code in country_route:
        if not features_by_code.has(code):
            continue
        var feature: Dictionary = features_by_code[code]
        var bounds := _feature_bounds(feature)
        var label := Label3D.new()
        label.text = get_country_name(code)
        label.font_size = 32
        label.pixel_size = 0.0045
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.modulate = Color("#f3fbff")
        label.outline_size = 6
        label.outline_modulate = Color("#08213c")
        label.position = _geo_to_sphere(bounds.x, bounds.y, GLOBE_RADIUS + 0.045)
        label.no_depth_test = false
        add_child(label)

func _feature_bounds(feature: Dictionary) -> Vector2:
    var min_lon := 180.0
    var max_lon := -180.0
    var min_lat := 90.0
    var max_lat := -90.0
    for polygon in feature.get("g", []):
        if polygon.is_empty():
            continue
        for point in polygon[0]:
            min_lon = minf(min_lon, float(point[0]))
            max_lon = maxf(max_lon, float(point[0]))
            min_lat = minf(min_lat, float(point[1]))
            max_lat = maxf(max_lat, float(point[1]))
    return Vector2((min_lon + max_lon) * 0.5, (min_lat + max_lat) * 0.5)

func _geo_to_sphere(longitude: float, latitude: float, radius: float) -> Vector3:
    var lon := deg_to_rad(longitude)
    var lat := deg_to_rad(latitude)
    return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * radius

func _process(delta: float) -> void:
    if not drag_active and rotation_velocity.length() > 0.001:
        rotate_y(rotation_velocity.x * delta)
        rotate_x(rotation_velocity.y * delta)
        rotation_velocity = rotation_velocity.lerp(Vector2.ZERO, minf(1.0, delta * 2.8))
    if not drag_active:
        rotate_y(delta * 0.018)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _begin_drag(event.position)
        else:
            _end_drag(event.position)
    elif event is InputEventScreenDrag:
        _move_drag(event.position, event.relative)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_drag(event.position)
        else:
            _end_drag(event.position)
    elif event is InputEventMouseMotion and drag_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _move_drag(event.position, event.relative)

func _begin_drag(position: Vector2) -> void:
    if position.y < 210.0 or position.y > 1060.0:
        return
    drag_active = true
    drag_start = position
    last_pointer = position
    pointer_moved = false
    rotation_velocity = Vector2.ZERO

func _move_drag(position: Vector2, relative: Vector2) -> void:
    if not drag_active:
        return
    if position.distance_to(drag_start) > 8.0:
        pointer_moved = true
    rotate_y(relative.x * 0.008)
    rotate_x(relative.y * 0.008)
    rotation.x = clampf(rotation.x, -1.25, 1.25)
    rotation_velocity = Vector2(relative.x * 0.42, relative.y * 0.42)
    last_pointer = position

func _end_drag(position: Vector2) -> void:
    if not drag_active:
        return
    drag_active = false
    if not pointer_moved and position.distance_to(drag_start) < 14.0:
        _pick_country(position)

func _pick_country(screen_position: Vector2) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var inverse := global_transform.affine_inverse()
    var local_origin: Vector3 = inverse * origin
    var local_direction: Vector3 = (inverse.basis * direction).normalized()
    var b := 2.0 * local_origin.dot(local_direction)
    var c := local_origin.length_squared() - GLOBE_RADIUS * GLOBE_RADIUS
    var discriminant := b * b - 4.0 * c
    if discriminant < 0.0:
        return
    var distance := (-b - sqrt(discriminant)) * 0.5
    if distance < 0.0:
        distance = (-b + sqrt(discriminant)) * 0.5
    if distance < 0.0:
        return
    var hit := (local_origin + local_direction * distance).normalized()
    var latitude := rad_to_deg(asin(clampf(hit.y, -1.0, 1.0)))
    var longitude := rad_to_deg(atan2(hit.x, hit.z))
    var code := _find_country(longitude, latitude)
    if code.is_empty():
        return
    var index := country_route.find(code)
    var feature: Dictionary = features_by_code.get(code, {})
    var name := get_country_name(code)
    country_tapped.emit(index, code, name, index >= 0 and index <= unlocked_index)

func _find_country(longitude: float, latitude: float) -> String:
    for code in country_route:
        if not features_by_code.has(code):
            continue
        var feature: Dictionary = features_by_code[code]
        for polygon in feature.get("g", []):
            if polygon.is_empty():
                continue
            if _point_in_ring(longitude, latitude, polygon[0]):
                var inside_hole := false
                for hole_index in range(1, polygon.size()):
                    if _point_in_ring(longitude, latitude, polygon[hole_index]):
                        inside_hole = true
                        break
                if not inside_hole:
                    return code
    return ""

func _point_in_ring(lon: float, lat: float, ring: Array) -> bool:
    var inside := false
    var j := ring.size() - 1
    for i in range(ring.size()):
        var xi := float(ring[i][0])
        var yi := float(ring[i][1])
        var xj := float(ring[j][0])
        var yj := float(ring[j][1])
        # Wrap longitudes around the selected point to handle the date line.
        xi = lon + wrapf(xi - lon, -180.0, 180.0)
        xj = lon + wrapf(xj - lon, -180.0, 180.0)
        if ((yi > lat) != (yj > lat)) and (lon < (xj - xi) * (lat - yi) / (yj - yi + 0.000001) + xi):
            inside = not inside
        j = i
    return inside
