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
var interaction_enabled := true
var drag_active := false
var drag_start := Vector2.ZERO
var last_pointer := Vector2.ZERO
var pointer_moved := false
var rotation_velocity := Vector2.ZERO
var zoom_distance := 7.6
var target_zoom_distance := 7.6
var globe_mesh: MeshInstance3D
var detail_patch: MeshInstance3D
var detail_material: ShaderMaterial
var cloud_layer: MeshInstance3D
var country_labels: Array[Label3D] = []
var city_labels: Array[Label3D] = []
var country_lock_labels: Array[Label3D] = []
var country_order_labels: Array[Label3D] = []
const DETAIL_LON_MIN := -9.0
const DETAIL_LON_MAX := 16.0
const DETAIL_LAT_MIN := 18.0
const DETAIL_LAT_MAX := 38.0

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
    # Keep the designed Algeria-first route, then append every remaining country
    # in a stable alphabetical ISO-code order (never dictionary iteration order).
    var remaining: Array[String] = []
    for code_variant in features_by_code.keys():
        var code := str(code_variant)
        if not country_route.has(code):
            remaining.append(code)
    remaining.sort()
    for code in remaining:
        country_route.append(code)

func _build_globe() -> void:
    globe_mesh = MeshInstance3D.new()
    globe_mesh.mesh = _create_earth_mesh(192, 96)
    var ocean: Material
    if ResourceLoader.exists("res://assets/earth_surface.jpg"):
        var earth_texture := load("res://assets/earth_surface.jpg") as Texture2D
        var earth_shader := Shader.new()
        earth_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap;
void fragment() {
    vec3 source = texture(earth_texture, UV).rgb;
    // Keep the original satellite land texture and replace only strongly blue ocean pixels.
    float max_land = max(source.r, source.g);
    float blue_excess = source.b - max_land;
    float ocean_mask = smoothstep(0.008, 0.060, blue_excess);
    float water_depth = clamp((source.b - source.r) * 2.4 + 0.45, 0.0, 1.0);
    vec3 deep_ocean = vec3(0.012, 0.055, 0.125);
    vec3 open_ocean = vec3(0.025, 0.145, 0.255);
    vec3 shallow_water = vec3(0.055, 0.30, 0.38);
    vec3 sea_colour = mix(deep_ocean, open_ocean, water_depth);
    sea_colour = mix(sea_colour, shallow_water, smoothstep(0.55, 0.92, water_depth) * 0.28);
    vec3 natural_land = source * vec3(1.04, 1.02, 0.98);
    ALBEDO = mix(natural_land, sea_colour, ocean_mask);
    ROUGHNESS = 0.96;
}
"""
        var earth_material := ShaderMaterial.new()
        earth_material.shader = earth_shader
        earth_material.set_shader_parameter("earth_texture", earth_texture)
        ocean = earth_material
    else:
        var fallback_ocean := StandardMaterial3D.new()
        fallback_ocean.albedo_color = Color("#31566a")
        fallback_ocean.roughness = 0.94
        fallback_ocean.cull_mode = BaseMaterial3D.CULL_DISABLED
        ocean = fallback_ocean
    globe_mesh.material_override = ocean
    add_child(globe_mesh)
    # Keep one seamless global surface; regional overlays caused visible rectangular seams.

    var atmosphere := MeshInstance3D.new()
    atmosphere.mesh = _create_earth_mesh(96, 48, GLOBE_RADIUS * 1.022)
    var halo_mat := StandardMaterial3D.new()
    halo_mat.albedo_color = Color(0.92, 0.78, 0.52, 0.035)
    halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
    halo_mat.emission_enabled = true
    halo_mat.emission = Color(0.12, 0.085, 0.035)
    halo_mat.emission_energy_multiplier = 0.08
    atmosphere.material_override = halo_mat
    add_child(atmosphere)

    _load_country_geometry()
    _append_remaining_countries()
    _build_country_borders()
    _create_country_labels()
    _create_country_lock_labels()

    var light := OmniLight3D.new()
    light.position = Vector3(-4.0, 4.0, 6.0)
    light.light_color = Color(0.98, 0.99, 1.0)
    light.light_energy = 1.65
    light.omni_range = 16.0
    add_child(light)
    _build_cloud_layer()
    _build_north_africa_detail_patch()


func _build_north_africa_detail_patch() -> void:
    # NASA GIBS MODIS true-colour regional mosaic, bundled for offline country-level zoom.
    var texture_path := "res://assets/north_africa_detail.jpg"
    if not ResourceLoader.exists(texture_path):
        return
    var image_texture := load(texture_path) as Texture2D
    if image_texture == null:
        return

    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    const LON_SEGMENTS := 96
    const LAT_SEGMENTS := 52
    for y in range(LAT_SEGMENTS + 1):
        var v := float(y) / float(LAT_SEGMENTS)
        var latitude := DETAIL_LAT_MAX - v * (DETAIL_LAT_MAX - DETAIL_LAT_MIN)
        for x in range(LON_SEGMENTS + 1):
            var u := float(x) / float(LON_SEGMENTS)
            var longitude := DETAIL_LON_MIN + u * (DETAIL_LON_MAX - DETAIL_LON_MIN)
            var vertex := _geo_to_sphere(longitude, latitude, GLOBE_RADIUS * 1.004)
            vertices.append(vertex)
            normals.append(vertex.normalized())
            uvs.append(Vector2(u, v))
    for y in range(LAT_SEGMENTS):
        for x in range(LON_SEGMENTS):
            var a := y * (LON_SEGMENTS + 1) + x
            var b := a + LON_SEGMENTS + 1
            var c := a + 1
            var d := b + 1
            indices.append_array(PackedInt32Array([a, b, c, c, b, d]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var patch_mesh := ArrayMesh.new()
    patch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    detail_patch = MeshInstance3D.new()
    detail_patch.name = "OfflineNorthAfricaSatelliteDetail"
    detail_patch.mesh = patch_mesh
    var detail_shader := Shader.new()
    detail_shader.code = """shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;
uniform sampler2D detail_texture : source_color, filter_linear_mipmap;
uniform float detail_alpha = 0.0;
void fragment() {
    vec2 edge_distance = min(UV, vec2(1.0) - UV);
    float edge = min(edge_distance.x, edge_distance.y);
    float feather = smoothstep(0.0, 0.075, edge);
    ALBEDO = texture(detail_texture, UV).rgb;
    ALPHA = feather * detail_alpha * 0.92;
    ROUGHNESS = 1.0;
}
"""
    detail_material = ShaderMaterial.new()
    detail_material.shader = detail_shader
    detail_material.set_shader_parameter("detail_texture", image_texture)
    detail_material.set_shader_parameter("detail_alpha", 0.0)
    detail_patch.material_override = detail_material
    detail_patch.visible = false
    add_child(detail_patch)

func _build_cloud_layer() -> void:
    cloud_layer = MeshInstance3D.new()
    cloud_layer.name = "AnimatedCloudShell"
    cloud_layer.mesh = _create_earth_mesh(160, 80, GLOBE_RADIUS * 1.008)
    var cloud_shader := Shader.new()
    cloud_shader.code = """shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
    vec2 p = UV * vec2(22.0, 11.0);
    p.x += TIME * 0.018;
    float n = noise2(p) * 0.58 + noise2(p * 2.1) * 0.29 + noise2(p * 4.2) * 0.13;
    float cloud = smoothstep(0.55, 0.72, n);
    ALBEDO = vec3(0.86, 0.92, 1.0);
    ALPHA = cloud * 0.16;
}
"""
    var cloud_material := ShaderMaterial.new()
    cloud_material.shader = cloud_shader
    cloud_layer.material_override = cloud_material
    add_child(cloud_layer)

func _load_country_geometry() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Missing offline country boundaries: " + DATA_PATH)
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not parsed is Dictionary:
        push_error("Invalid country boundary data")
        return
    var features: Array = parsed.get("features", [])
    for feature in features:
        if not feature is Dictionary:
            continue
        var code := str(feature.get("i", ""))
        if code.is_empty():
            continue
        features_by_code[code] = feature
        # The satellite texture carries the country outlines. GeoJSON is kept for accurate selection.


func _build_country_borders() -> void:
    # Draw georeferenced borders above both the base globe and the satellite detail overlay.
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    for feature_variant in features_by_code.values():
        var feature: Dictionary = feature_variant
        for polygon in feature.get("g", []):
            for ring in polygon:
                if ring.size() < 2:
                    continue
                for point_index in range(ring.size() - 1):
                    var a = ring[point_index]
                    var b = ring[point_index + 1]
                    var lon_a := float(a[0])
                    var lon_b := float(b[0])
                    if absf(lon_b - lon_a) > 180.0:
                        continue
                    var base_index := vertices.size()
                    vertices.append(_geo_to_sphere(lon_a, float(a[1]), GLOBE_RADIUS * 1.006))
                    vertices.append(_geo_to_sphere(lon_b, float(b[1]), GLOBE_RADIUS * 1.006))
                    indices.append(base_index)
                    indices.append(base_index + 1)
    if vertices.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    var border_mesh := ArrayMesh.new()
    border_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    var border_instance := MeshInstance3D.new()
    border_instance.name = "AccurateGeographicCountryBorders"
    border_instance.mesh = border_mesh
    var border_material := StandardMaterial3D.new()
    border_material.albedo_color = Color(0.86, 0.82, 0.72, 0.62)
    border_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    border_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    border_instance.material_override = border_material
    add_child(border_instance)

func _create_country_labels() -> void:
    # One compact label per country, anchored at the geographic centroid of its
    # largest land polygon instead of the midpoint of its bounding rectangle.
    for code in country_route:
        if not features_by_code.has(code):
            continue
        var feature: Dictionary = features_by_code[code]
        var geometry: Array = feature.get("g", [])
        var anchor := _get_country_label_anchor(geometry)
        if anchor.size() < 2:
            continue
        var label := Label3D.new()
        label.name = "CountryLabel_" + code
        label.text = get_country_name(code)
        var name_length := label.text.length()
        label.font_size = 18 if name_length <= 7 else (15 if name_length <= 11 else 12)
        label.pixel_size = 0.00245
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        label.shaded = false
        label.modulate = Color(0.96, 0.92, 0.82, 0.94)
        label.outline_size = 5
        label.outline_modulate = Color(0.025, 0.024, 0.019, 0.94)
        label.position = _geo_to_sphere(float(anchor[0]), float(anchor[1]), GLOBE_RADIUS * 1.012)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        add_child(label)
        country_labels.append(label)
    _create_city_labels()


func _get_country_label_anchor(geometry: Array) -> Array:
    var best_area := 0.0
    var best_anchor: Array = []
    for polygon in geometry:
        if polygon.is_empty():
            continue
        var ring: Array = polygon[0]
        if ring.size() < 4:
            continue
        var twice_area := 0.0
        var centroid_x := 0.0
        var centroid_y := 0.0
        var average_x := 0.0
        var average_y := 0.0
        var count := ring.size() - 1 if ring.size() > 1 else ring.size()
        for i in range(count):
            var current: Array = ring[i]
            var next: Array = ring[(i + 1) % count]
            var x1 := float(current[0])
            var y1 := float(current[1])
            var x2 := float(next[0])
            var y2 := float(next[1])
            var cross := x1 * y2 - x2 * y1
            twice_area += cross
            centroid_x += (x1 + x2) * cross
            centroid_y += (y1 + y2) * cross
            average_x += x1
            average_y += y1
        var area := absf(twice_area) * 0.5
        if area <= best_area or count == 0:
            continue
        var candidate_lon := average_x / float(count)
        var candidate_lat := average_y / float(count)
        if absf(twice_area) > 0.000001:
            candidate_lon = centroid_x / (3.0 * twice_area)
            candidate_lat = centroid_y / (3.0 * twice_area)
        # Concave or crescent-shaped countries can have an exterior centroid.
        if not _point_in_ring(candidate_lon, candidate_lat, ring):
            candidate_lon = average_x / float(count)
            candidate_lat = average_y / float(count)
        best_area = area
        best_anchor = [candidate_lon, candidate_lat]
    return best_anchor

func _create_country_lock_labels() -> void:
    # Every locked destination gets its own visible lock marker.
    # Markers are hidden only when they are on the far side of the globe.
    for code in country_route:
        if not features_by_code.has(code):
            continue
        var feature: Dictionary = features_by_code[code]
        var anchor := _get_country_label_anchor(feature.get("g", []))
        if anchor.size() < 2:
            continue
        var lock_label := Label3D.new()
        lock_label.name = "CountryLock_" + code
        lock_label.text = "🔒"
        lock_label.font_size = 58
        lock_label.pixel_size = 0.0054
        lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        lock_label.no_depth_test = true
        lock_label.shaded = false
        # Neutral metallic gray: unmistakable locked state, not a gold decoration.
        lock_label.modulate = Color(0.76, 0.79, 0.83, 1.0)
        lock_label.outline_size = 10
        lock_label.outline_modulate = Color(0.035, 0.040, 0.050, 1.0)
        lock_label.position = _geo_to_sphere(float(anchor[0]), float(anchor[1]), GLOBE_RADIUS * 1.042)
        lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        var route_index := country_route.find(code)
        lock_label.set_meta("route_index", route_index)
        add_child(lock_label)
        country_lock_labels.append(lock_label)

        # A compact sequence number sits just below the large lock so players
        # can read the exact unlock order at a glance.
        var order_label := Label3D.new()
        order_label.name = "CountryLockOrder_%s" % code
        order_label.text = "%02d" % (route_index + 1)
        order_label.font_size = 19
        order_label.pixel_size = 0.0032
        order_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        order_label.no_depth_test = true
        order_label.shaded = false
        order_label.modulate = Color(0.82, 0.85, 0.89, 1.0)
        order_label.outline_size = 7
        order_label.outline_modulate = Color(0.025, 0.030, 0.040, 1.0)
        order_label.position = lock_label.position + Vector3(0.0, -0.17, 0.0)
        order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        order_label.set_meta("route_index", route_index)
        add_child(order_label)
        country_order_labels.append(order_label)

func _create_city_labels() -> void:
    # Accurate geographic anchors for the first playable region; labels appear only at close zoom.
    var cities: Array[Dictionary] = [
        {"name":"الجزائر العاصمة", "lon":3.0588, "lat":36.7538, "tier":1},
        {"name":"وهران", "lon":-0.6308, "lat":35.6971, "tier":1},
        {"name":"قسنطينة", "lon":6.6147, "lat":36.3650, "tier":1},
        {"name":"عنابة", "lon":7.7667, "lat":36.9000, "tier":1},
        {"name":"سطيف", "lon":5.4100, "lat":36.1900},
        {"name":"باتنة", "lon":6.1700, "lat":35.5500},
        {"name":"بجاية", "lon":5.0600, "lat":36.7500},
        {"name":"تلمسان", "lon":-1.3200, "lat":34.8800},
        {"name":"بسكرة", "lon":5.7300, "lat":34.8500},
        {"name":"غرداية", "lon":3.6700, "lat":32.4900},
        {"name":"ورقلة", "lon":5.3300, "lat":31.9500},
        {"name":"تمنراست", "lon":5.5200, "lat":22.7900},
        {"name":"أدرار", "lon":-0.2900, "lat":27.8700},
        {"name":"بشار", "lon":-2.2200, "lat":31.6200},
        {"name":"الوادي", "lon":6.8600, "lat":33.3700},
        {"name":"تونس", "lon":10.1815, "lat":36.8065, "tier":1},
        {"name":"صفاقس", "lon":10.7603, "lat":34.7406, "tier":1},
        {"name":"سوسة", "lon":10.6370, "lat":35.8256, "tier":1},
        {"name":"قابس", "lon":10.0975, "lat":33.8881, "tier":2},
        {"name":"تيزي وزو", "lon":4.0459, "lat":36.7118, "tier":2},
        {"name":"جيجل", "lon":5.7667, "lat":36.8167, "tier":2},
        {"name":"سكيكدة", "lon":6.9063, "lat":36.8762, "tier":2},
        {"name":"قالمة", "lon":7.4333, "lat":36.4667, "tier":2},
        {"name":"الشلف", "lon":1.3333, "lat":36.1653, "tier":2},
        {"name":"مستغانم", "lon":0.0892, "lat":35.9311, "tier":2},
        {"name":"تيارت", "lon":1.3167, "lat":35.3667, "tier":2},
        {"name":"الجلفة", "lon":3.2500, "lat":34.6667, "tier":2},
        {"name":"الأغواط", "lon":2.8833, "lat":33.8000, "tier":2},
        {"name":"المسيلة", "lon":4.5500, "lat":35.7000, "tier":2},
        {"name":"تبسة", "lon":8.1200, "lat":35.4042, "tier":2},
        {"name":"خنشلة", "lon":7.1433, "lat":35.4358, "tier":2},
        {"name":"الوطن القبلي", "lon":10.7333, "lat":36.4500, "tier":2},
        {"name":"بنزرت", "lon":9.8739, "lat":37.2744, "tier":2},
        {"name":"القيروان", "lon":10.0963, "lat":35.6781, "tier":2},
        {"name":"المنستير", "lon":10.8262, "lat":35.7770, "tier":2},
        {"name":"مدنين", "lon":10.5055, "lat":33.3549, "tier":2}
    ]
    for city in cities:
        var label := Label3D.new()
        label.name = "CityLabel_" + str(city.name)
        label.text = str(city.name)
        label.font_size = 27 if int(city.get("tier", 2)) == 1 else 23
        label.set_meta("zoom_tier", int(city.get("tier", 2)))
        label.pixel_size = 0.0032
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        label.shaded = false
        label.modulate = Color(0.98, 0.86, 0.62, 0.98)
        label.outline_size = 8
        label.outline_modulate = Color(0.025, 0.022, 0.016, 0.98)
        label.position = _geo_to_sphere(float(city.lon), float(city.lat), GLOBE_RADIUS * 1.018)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        add_child(label)
        city_labels.append(label)

func _update_country_label_visibility() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var camera_local := global_transform.affine_inverse() * camera.global_position
    for label in country_labels:
        if not is_instance_valid(label):
            continue
        var normal := label.position.normalized()
        var code := label.name.trim_prefix("CountryLabel_")
        var overview_countries := ["DZA", "TUN", "LBY", "EGY", "MAR", "MRT", "NER", "MLI", "TCD", "SDN", "NGA", "ETH", "KEN", "ZAF", "ESP", "FRA", "DEU", "ITA", "GBR", "RUS", "TUR", "SAU", "IND", "CHN", "JPN", "BRA", "USA", "CAN", "AUS"]
        var zoom_visible := zoom_distance <= 6.4 or overview_countries.has(code)
        label.visible = zoom_visible and normal.dot(camera_local.normalized()) > 0.12
    for label in city_labels:
        if not is_instance_valid(label):
            continue
        var normal := label.position.normalized()
        var tier := int(label.get_meta("zoom_tier", 2))
        var tier_visible := zoom_distance <= 5.45 or (tier == 1 and zoom_distance <= 6.15)
        label.visible = tier_visible and normal.dot(camera_local.normalized()) > 0.18
    for lock_label in country_lock_labels:
        if not is_instance_valid(lock_label):
            continue
        var route_index := int(lock_label.get_meta("route_index", -1))
        var normal := lock_label.position.normalized()
        var marker_visible := route_index > unlocked_index and normal.dot(camera_local.normalized()) > 0.12
        lock_label.visible = marker_visible
    for order_label in country_order_labels:
        if not is_instance_valid(order_label):
            continue
        var route_index := int(order_label.get_meta("route_index", -1))
        var normal := order_label.position.normalized()
        order_label.visible = route_index > unlocked_index and normal.dot(camera_local.normalized()) > 0.12

func _create_earth_mesh(longitude_segments: int, latitude_segments: int, radius: float = GLOBE_RADIUS) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    for y in range(latitude_segments + 1):
        var v := float(y) / float(latitude_segments)
        var latitude := 90.0 - v * 180.0
        for x in range(longitude_segments + 1):
            var u := float(x) / float(longitude_segments)
            var longitude := u * 360.0 - 180.0
            var vertex := _geo_to_sphere(longitude, latitude, radius)
            vertices.append(vertex)
            normals.append(vertex.normalized())
            # Collapse pole UVs to one meridian sample to prevent polar starburst artifacts.
            var pole_u := 0.5 if y == 0 or y == latitude_segments else u
            uvs.append(Vector2(pole_u, v))
    for y in range(latitude_segments):
        for x in range(longitude_segments):
            var a := y * (longitude_segments + 1) + x
            var b := a + longitude_segments + 1
            var c := a + 1
            var d := b + 1
            indices.append_array(PackedInt32Array([a, b, c, c, b, d]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _geo_to_sphere(longitude: float, latitude: float, radius: float) -> Vector3:
    var lon := deg_to_rad(longitude)
    var lat := deg_to_rad(latitude)
    return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * radius

func _process(delta: float) -> void:
    _update_country_label_visibility()
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        zoom_distance = lerpf(zoom_distance, target_zoom_distance, minf(1.0, delta * 4.2))
        if absf(camera.position.z - zoom_distance) > 0.001:
            camera.position.z = zoom_distance
    if detail_patch != null and detail_material != null:
        # Regional imagery fades in only during a deliberate close zoom, never on the overview globe.
        var detail_alpha := 1.0 - smoothstep(4.8, 6.0, zoom_distance)
        detail_patch.visible = detail_alpha > 0.01
        detail_material.set_shader_parameter("detail_alpha", detail_alpha)
    if not drag_active and rotation_velocity.length() > 0.001:
        rotate_y(rotation_velocity.x * delta)
        rotate_x(rotation_velocity.y * delta)
        rotation_velocity = rotation_velocity.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))
    if not drag_active:
        rotate_y(delta * 0.0018)

func _input(event: InputEvent) -> void:
    if not interaction_enabled:
        return
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
    elif event is InputEventMagnifyGesture:
        _apply_zoom(event.factor)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _apply_zoom(1.12)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _apply_zoom(0.89)

func _apply_zoom(factor: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var gentle_factor := lerpf(1.0, factor, 0.22)
    target_zoom_distance = clampf(target_zoom_distance / gentle_factor, 3.28, 14.0)

func _begin_drag(position: Vector2) -> void:
    if position.y > 1060.0:
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
    rotate_y(relative.x * 0.00085)
    rotate_x(relative.y * 0.00085)
    rotation.x = clampf(rotation.x, -1.25, 1.25)
    rotation_velocity = Vector2(relative.x * 0.00115, relative.y * 0.00115).limit_length(0.22)
    last_pointer = position

func _end_drag(position: Vector2) -> void:
    if not drag_active:
        return
    drag_active = false
    if not pointer_moved and position.distance_to(drag_start) < 14.0 and position.y <= 1060.0:
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
