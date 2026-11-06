extends Node3D

const WorldMapArt = preload("res://scripts/world_map_art.gd")
const WorldGlobe = preload("res://scripts/world_globe.gd")

const QUESTIONS_PATH := "res://data/questions.json"
const SAVE_PATH := "user://player_data.cfg"

var questions: Array = []
var question_order: Array[int] = []
var question_index := 0
var score := 0
var answered := false
var showing_results := false
var difficulty := "medium"
var vibration_enabled := false
var explanations_enabled := true
var best_score := 0
var games_played := 0
var unlocked_level := 1
var current_level := 1
var unlocked_country_index := 0
var current_country_index := 0
var current_country_code := "DZA"
var current_country_name := "الجزائر"
var question_pool: Array[int] = []
var world_globe
var world_camera: Camera3D
var correct_answers := 0
var question_timer: Timer
var time_label: Label
var time_limit := 20.0
var music_enabled := true
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var music_sample_index := 0
const MUSIC_RATE := 22050.0
const MUSIC_LOOP_SECONDS := 8.0

var content: VBoxContainer
var interface_root: Control
var interface_margin: Control
var globe_hud: Control
var footer_label: Label
var progress_label: Label
var score_label: Label
var question_label: Label
var category_label: Label
var feedback_label: Label
var next_button: Button

const DIFFICULTIES := {
    "easy": {"name": "سهل", "count": 5, "description": "5 أسئلة — بداية ممتعة"},
    "medium": {"name": "متوسط", "count": 10, "description": "10 أسئلة — تحدٍّ متوازن"},
    "hard": {"name": "صعب", "count": 20, "description": "كل الأسئلة — للمحترفين"}
}

func _ready() -> void:
    _build_3d_world()
    _setup_music()
    question_timer = Timer.new()
    question_timer.one_shot = true
    question_timer.timeout.connect(_on_question_timeout)
    add_child(question_timer)
    _load_questions()
    _load_player_data()
    if music_player != null:
        music_player.stream_paused = not music_enabled
    _build_interface()
    _show_main_menu()

func _setup_music() -> void:
    var generator := AudioStreamGenerator.new()
    generator.mix_rate = int(MUSIC_RATE)
    generator.buffer_length = 0.5
    music_player = AudioStreamPlayer.new()
    music_player.stream = generator
    music_player.volume_db = -8.0
    add_child(music_player)
    music_player.play()
    music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
    if music_enabled and music_playback != null:
        var frames := music_playback.get_frames_available()
        if frames > 0:
            var buffer := PackedVector2Array()
            buffer.resize(frames)
            for i in range(frames):
                var sample := _music_sample(music_sample_index)
                buffer[i] = Vector2(sample, sample)
                music_sample_index += 1
            music_playback.push_buffer(buffer)
    if question_timer != null and question_timer.time_left > 0.0 and time_label != null and is_instance_valid(time_label):
        time_label.text = "⏱  الوقت المتبقي: %d ثانية" % int(ceil(question_timer.time_left))
    for gem in get_tree().get_nodes_in_group("map_gems"):
        if is_instance_valid(gem):
            gem.rotate_y(delta * 0.9)
            gem.rotate_x(delta * 0.35)

func _music_sample(sample_index: int) -> float:
    var t := fposmod(float(sample_index) / MUSIC_RATE, MUSIC_LOOP_SECONDS)
    var beat_time := fposmod(t, 0.5)
    var beat := int(floor(t / 0.5))
    var step := int(floor(t / 0.25)) % 32
    var local_step := fposmod(t, 0.25)
    var kick := 0.0
    if beat % 4 == 0:
        kick = sin(TAU * (48.0 + 42.0 * exp(-beat_time * 24.0)) * beat_time) * exp(-beat_time * 13.0) * 0.72
    var snare := 0.0
    if beat % 4 == 2:
        var noise := sin(float(sample_index) * 12.9898) * 43758.5453
        noise = (noise - floor(noise)) * 2.0 - 1.0
        snare = noise * exp(-beat_time * 22.0) * 0.20
    var hat_phase := fposmod(t, 0.25)
    var hat_noise := sin(float(sample_index) * 78.233) * 12345.678
    hat_noise = (hat_noise - floor(hat_noise)) * 2.0 - 1.0
    var hats := hat_noise * exp(-hat_phase * 38.0) * 0.055
    var notes := [659.25, 783.99, 987.77, 783.99, 587.33, 698.46, 880.0, 698.46, 523.25, 659.25, 783.99, 659.25, 587.33, 698.46, 880.0, 987.77]
    var note_frequency: float = notes[step % notes.size()]
    var melody := sin(TAU * note_frequency * local_step) * exp(-local_step * 5.5) * 0.16
    var bass_notes := [110.0, 110.0, 146.83, 146.83, 98.0, 98.0, 130.81, 130.81]
    var bass_frequency: float = bass_notes[(beat / 2) % bass_notes.size()]
    var bass := sin(TAU * bass_frequency * t) * 0.13
    return clampf((kick + snare + hats + melody + bass) * 0.72, -0.95, 0.95)

func _build_3d_world() -> void:
    # A layered floating-island world map built from real 3D meshes.
    world_camera = Camera3D.new()
    world_camera.position = Vector3(0, 0, 12)
    world_camera.near = 0.02
    world_camera.far = 120.0
    world_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    world_camera.size = 15.5
    world_camera.current = true
    add_child(world_camera)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.012, 0.025, 0.085)
    sky_material.sky_horizon_color = Color(0.055, 0.12, 0.24)
    sky_material.ground_bottom_color = Color(0.012, 0.02, 0.06)
    sky_material.ground_horizon_color = Color(0.025, 0.07, 0.15)
    sky.sky_material = sky_material
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.34, 0.48, 0.78)
    env.ambient_light_energy = 0.8
    env.glow_enabled = true
    env.glow_intensity = 0.55
    environment.environment = env
    add_child(environment)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-42, -25, -18)
    key_light.light_energy = 1.65
    key_light.shadow_enabled = true
    add_child(key_light)

    var fill_light := OmniLight3D.new()
    fill_light.position = Vector3(-4, 4, 5)
    fill_light.light_color = Color(0.22, 0.62, 1.0)
    fill_light.light_energy = 2.0
    fill_light.omni_range = 18.0
    add_child(fill_light)

    # Distant stars and a subtle orbital halo.
    for i in range(64):
        var star := MeshInstance3D.new()
        var star_mesh := SphereMesh.new()
        star_mesh.radius = 0.018 if i % 4 else 0.032
        star_mesh.height = star_mesh.radius * 2.0
        star.mesh = star_mesh
        var star_mat := StandardMaterial3D.new()
        star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        star_mat.albedo_color = Color(0.48, 0.72, 1.0, 0.82)
        star_mat.emission_enabled = true
        star_mat.emission = Color(0.18, 0.42, 1.0)
        star.material_override = star_mat
        star.add_to_group("fantasy_map")
        var angle := float(i) * 2.399
        var radius := 5.0 + float((i * 7) % 9) * 0.48
        star.position = Vector3(cos(angle) * radius, sin(angle * 1.37) * 6.0, -5.0 - float(i % 5))
        add_child(star)

    var world_specs := [
        {"p": Vector3(-3.4, 3.0, 0), "c": Color(0.12, 0.65, 0.46), "name": "وادي المعرفة"},
        {"p": Vector3(2.9, 1.55, -0.2), "c": Color(0.18, 0.56, 0.32), "name": "غابة الألغاز"},
        {"p": Vector3(-2.8, -0.1, 0.1), "c": Color(0.15, 0.48, 0.78), "name": "مدينة العلوم"},
        {"p": Vector3(3.0, -1.8, 0), "c": Color(0.52, 0.34, 0.72), "name": "قلعة العباقرة"},
        {"p": Vector3(-0.1, -3.55, -0.2), "c": Color(0.82, 0.53, 0.20), "name": "قمة الأساطير"}
    ]
    for i in range(world_specs.size()):
        _add_map_island(world_specs[i]["p"], world_specs[i]["c"], i)

    # Glowing stepping-stone trail connecting the five floating worlds.
    for i in range(4):
        var a: Vector3 = world_specs[i]["p"]
        var b: Vector3 = world_specs[i + 1]["p"]
        for step in range(1, 5):
            var t := float(step) / 5.0
            var pebble := MeshInstance3D.new()
            var pebble_mesh := SphereMesh.new()
            pebble_mesh.radius = 0.075
            pebble_mesh.height = 0.10
            pebble.mesh = pebble_mesh
            pebble.position = a.lerp(b, t) + Vector3(0, 0, -0.45)
            var pebble_mat := StandardMaterial3D.new()
            pebble_mat.albedo_color = Color(0.22, 0.78, 1.0)
            pebble_mat.emission_enabled = true
            pebble_mat.emission = Color(0.08, 0.42, 1.0) * 1.8
            pebble.material_override = pebble_mat
            pebble.add_to_group("fantasy_map")
            add_child(pebble)

func _map_material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    if glow > 0.0:
        material.emission_enabled = true
        material.emission = color * glow
    return material

func _add_map_island(position: Vector3, tint: Color, world_index: int) -> void:
    var island := Node3D.new()
    island.add_to_group("fantasy_map")
    island.position = position
    add_child(island)

    var base := MeshInstance3D.new()
    var base_mesh := SphereMesh.new()
    base_mesh.radius = 1.48 if world_index == 4 else 1.30
    base_mesh.height = 1.10
    base.mesh = base_mesh
    base.scale = Vector3(1.18, 0.48, 0.82)
    base.position = Vector3(0, -0.38, 0)
    base.material_override = _map_material(Color(0.055, 0.12, 0.23))
    island.add_child(base)

    var top := MeshInstance3D.new()
    var top_mesh := CylinderMesh.new()
    top_mesh.top_radius = 1.25
    top_mesh.bottom_radius = 1.42
    top_mesh.height = 0.22
    top.mesh = top_mesh
    top.position = Vector3(0, -0.05, 0)
    top.material_override = _map_material(tint)
    island.add_child(top)

    var rim := MeshInstance3D.new()
    var rim_mesh := TorusMesh.new()
    rim_mesh.inner_radius = 1.17
    rim_mesh.outer_radius = 1.22
    rim.mesh = rim_mesh
    rim.position = Vector3(0, 0.08, 0)
    rim.material_override = _map_material(tint.lightened(0.28), 0.45)
    island.add_child(rim)

    # Landmark structure unique to each world.
    if world_index == 0 or world_index == 2:
        _add_map_tower(island, Vector3(0, 0.42, 0), tint, world_index == 2)
    elif world_index == 1:
        for tree_index in range(5):
            var angle := TAU * float(tree_index) / 5.0
            _add_map_tree(island, Vector3(cos(angle) * 0.78, 0.20, sin(angle) * 0.48))
    elif world_index == 3:
        _add_map_castle(island, tint)
    else:
        _add_map_tower(island, Vector3(0, 0.48, 0), tint, true)
        var crown := MeshInstance3D.new()
        var crown_mesh := PrismMesh.new()
        crown_mesh.size = Vector3(0.72, 0.62, 0.72)
        crown.mesh = crown_mesh
        crown.position = Vector3(0, 1.42, 0)
        crown.material_override = _map_material(Color(1.0, 0.76, 0.25), 1.1)
        island.add_child(crown)

    for gem_index in range(3):
        var gem := MeshInstance3D.new()
        var gem_mesh := SphereMesh.new()
        gem_mesh.radius = 0.095
        gem_mesh.height = 0.19
        gem.mesh = gem_mesh
        gem.position = Vector3(-0.72 + float(gem_index) * 0.72, 0.35, 0.55)
        gem.material_override = _map_material(Color(0.38, 0.86, 1.0), 1.6)
        gem.add_to_group("map_gems")
        island.add_child(gem)

func _add_map_tree(parent: Node3D, at: Vector3) -> void:
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.07
    trunk_mesh.bottom_radius = 0.11
    trunk_mesh.height = 0.48
    trunk.mesh = trunk_mesh
    trunk.position = at + Vector3(0, 0.24, 0)
    trunk.material_override = _map_material(Color(0.28, 0.13, 0.08))
    parent.add_child(trunk)

    var leaves := MeshInstance3D.new()
    var leaves_mesh := SphereMesh.new()
    leaves_mesh.radius = 0.30
    leaves_mesh.height = 0.58
    leaves.mesh = leaves_mesh
    leaves.position = at + Vector3(0, 0.62, 0)
    leaves.material_override = _map_material(Color(0.12, 0.52, 0.31), 0.18)
    parent.add_child(leaves)

func _add_map_tower(parent: Node3D, at: Vector3, tint: Color, crystal: bool) -> void:
    var pillar := MeshInstance3D.new()
    var pillar_mesh := CylinderMesh.new()
    pillar_mesh.top_radius = 0.28
    pillar_mesh.bottom_radius = 0.42
    pillar_mesh.height = 1.05
    pillar.mesh = pillar_mesh
    pillar.position = at + Vector3(0, 0.53, 0)
    pillar.material_override = _map_material(Color(0.72, 0.78, 0.91))
    parent.add_child(pillar)

    var cap := MeshInstance3D.new()
    var cap_mesh := PrismMesh.new()
    cap_mesh.size = Vector3(0.72, 0.62, 0.72)
    cap.mesh = cap_mesh
    cap.position = at + Vector3(0, 1.32, 0)
    cap.material_override = _map_material(tint.lightened(0.28), 0.35)
    parent.add_child(cap)

    if crystal:
        var shard := MeshInstance3D.new()
        var shard_mesh := PrismMesh.new()
        shard_mesh.size = Vector3(0.38, 0.72, 0.38)
        shard.mesh = shard_mesh
        shard.position = at + Vector3(0, 1.78, 0)
        shard.rotation_degrees = Vector3(0, 45, 0)
        shard.material_override = _map_material(Color(0.35, 0.9, 1.0), 1.8)
        shard.add_to_group("map_gems")
        parent.add_child(shard)

func _add_map_castle(parent: Node3D, tint: Color) -> void:
    var keep := MeshInstance3D.new()
    var keep_mesh := BoxMesh.new()
    keep_mesh.size = Vector3(0.9, 0.92, 0.7)
    keep.mesh = keep_mesh
    keep.position = Vector3(0, 0.58, 0)
    keep.material_override = _map_material(Color(0.62, 0.65, 0.82))
    parent.add_child(keep)
    for x in [-0.52, 0.52]:
        for z in [-0.34, 0.34]:
            var turret := MeshInstance3D.new()
            var turret_mesh := CylinderMesh.new()
            turret_mesh.top_radius = 0.12
            turret_mesh.bottom_radius = 0.18
            turret_mesh.height = 1.12
            turret.mesh = turret_mesh
            turret.position = Vector3(x, 0.62, z)
            turret.material_override = _map_material(tint.lightened(0.42))
            parent.add_child(turret)
            var roof := MeshInstance3D.new()
            var roof_mesh := PrismMesh.new()
            roof_mesh.size = Vector3(0.38, 0.38, 0.38)
            roof.mesh = roof_mesh
            roof.position = Vector3(x, 1.34, z)
            roof.material_override = _map_material(Color(0.95, 0.64, 0.26), 0.25)
            parent.add_child(roof)

func _load_questions() -> void:
    if not FileAccess.file_exists(QUESTIONS_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(QUESTIONS_PATH))
    if parsed is Dictionary and parsed.has("questions"):
        questions = parsed["questions"]

func _load_player_data() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) == OK:
        best_score = int(config.get_value("stats", "best_score", 0))
        games_played = int(config.get_value("stats", "games_played", 0))
        difficulty = str(config.get_value("settings", "difficulty", "medium"))
        vibration_enabled = bool(config.get_value("settings", "vibration", true))
        explanations_enabled = bool(config.get_value("settings", "explanations", true))
        unlocked_level = int(config.get_value("progress", "unlocked_level", 1))
        unlocked_country_index = int(config.get_value("country_progress", "unlocked_index", 0))
        music_enabled = bool(config.get_value("settings", "music", true))
    if not DIFFICULTIES.has(difficulty):
        difficulty = "medium"
    unlocked_level = clampi(unlocked_level, 1, 11)
    unlocked_country_index = clampi(unlocked_country_index, 0, 176)

func _save_player_data() -> void:
    var config := ConfigFile.new()
    config.set_value("stats", "best_score", best_score)
    config.set_value("stats", "games_played", games_played)
    config.set_value("settings", "difficulty", difficulty)
    config.set_value("settings", "vibration", vibration_enabled)
    config.set_value("settings", "explanations", explanations_enabled)
    config.set_value("settings", "music", music_enabled)
    config.set_value("progress", "unlocked_level", unlocked_level)
    config.set_value("country_progress", "unlocked_index", unlocked_country_index)
    config.save(SAVE_PATH)

func _build_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.layout_direction = Control.LAYOUT_DIRECTION_RTL
    layer.add_child(root)
    interface_root = root

    var tint := ColorRect.new()
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(0.018, 0.028, 0.075, 0.48)
    root.add_child(tint)

    var margin := MarginContainer.new()
    interface_margin = margin
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 30)
    margin.add_theme_constant_override("margin_right", 30)
    margin.add_theme_constant_override("margin_top", 38)
    margin.add_theme_constant_override("margin_bottom", 28)
    root.add_child(margin)

    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 14)
    margin.add_child(page)

    var brand := Label.new()
    brand.text = "✦ تَحَدّي العَباقِرَة ✦"
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.add_theme_font_size_override("font_size", 34)
    brand.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
    page.add_child(brand)

    var tagline := Label.new()
    tagline.text = "فكّر بذكاء… وتفوّق!"
    tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tagline.add_theme_font_size_override("font_size", 17)
    tagline.add_theme_color_override("font_color", Color(0.48, 0.78, 1.0))
    page.add_child(tagline)

    var separator := HSeparator.new()
    separator.add_theme_color_override("color", Color(0.25, 0.43, 0.75, 0.65))
    page.add_child(separator)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    scroll.add_child(content)

    footer_label = Label.new()
    footer_label.text = "◆ تعمل دون إنترنت  •  استمتع بالتحدّي ◆"
    footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer_label.add_theme_font_size_override("font_size", 14)
    footer_label.add_theme_color_override("font_color", Color(0.58, 0.68, 0.88))
    page.add_child(footer_label)

func _clear_content() -> void:
    if question_timer != null:
        question_timer.stop()
    time_label = null
    for child in content.get_children():
        child.queue_free()

func _add_heading(title_text: String, subtitle_text: String = "") -> void:
    var heading := Label.new()
    heading.text = title_text
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 29)
    heading.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
    content.add_child(heading)
    if not subtitle_text.is_empty():
        var subtitle := Label.new()
        subtitle.text = subtitle_text
        subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        subtitle.add_theme_font_size_override("font_size", 17)
        subtitle.add_theme_color_override("font_color", Color(0.64, 0.78, 1.0))
        content.add_child(subtitle)

func _add_stat_card(caption: String, value: String) -> void:
    var card := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.15, 0.31, 0.94)
    style.border_color = Color(0.25, 0.43, 0.78, 0.85)
    style.set_border_width_all(1)
    style.set_corner_radius_all(18)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    card.add_theme_stylebox_override("panel", style)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    card.add_child(box)
    var value_label := Label.new()
    value_label.text = value
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_label.add_theme_font_size_override("font_size", 27)
    value_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
    box.add_child(value_label)
    var caption_label := Label.new()
    caption_label.text = caption
    caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption_label.add_theme_font_size_override("font_size", 15)
    caption_label.add_theme_color_override("font_color", Color(0.78, 0.85, 1.0))
    box.add_child(caption_label)
    content.add_child(card)

func _show_main_menu() -> void:
    _set_globe_mode(false)
    _clear_content()
    _add_heading("مرحباً بك أيها العبقري!", "هل أنت مستعد لاختبار معلوماتك؟")
    _add_stat_card("أفضل نتيجة شخصية", "🏆  %d نقطة" % best_score)
    _add_stat_card("عدد الجولات المكتملة", "🎮  %d" % games_played)

    var play := _make_button("▶   ابدأ التحدّي")
    play.custom_minimum_size.y = 78
    play.pressed.connect(_show_world_map)
    content.add_child(play)

    var settings_button := _make_button("⚙   الإعدادات")
    settings_button.pressed.connect(_show_settings)
    content.add_child(settings_button)

    var achievements_button := _make_button("★   النجوم والإنجازات")
    achievements_button.pressed.connect(_show_achievements)
    content.add_child(achievements_button)

    var help_button := _make_button("؟   طريقة اللعب")
    help_button.pressed.connect(_show_help)
    content.add_child(help_button)

    var mode: Dictionary = DIFFICULTIES[difficulty]
    var mode_label := Label.new()
    mode_label.text = "الدول المفتوحة: %d / 177" % (unlocked_country_index + 1)
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_label.add_theme_font_size_override("font_size", 16)
    mode_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.78))
    content.add_child(mode_label)

func _show_settings() -> void:
    _clear_content()
    _add_heading("الإعدادات", "اضبط تجربتك كما تحب")
    var music_button := _make_button("الموسيقى الحماسية: %s" % ("مفعّلة" if music_enabled else "متوقفة"))
    music_button.pressed.connect(func():
        music_enabled = not music_enabled
        if music_player != null:
            music_player.stream_paused = not music_enabled
        _save_player_data()
        _show_settings()
    )
    content.add_child(music_button)

    var vibration_button := _make_button("اهتزاز عند الإجابة: %s" % ("مفعّل" if vibration_enabled else "متوقف"))
    vibration_button.pressed.connect(func():
        vibration_enabled = not vibration_enabled
        _save_player_data()
        _show_settings()
    )
    content.add_child(vibration_button)

    var explanation_button := _make_button("إظهار شرح الإجابات: %s" % ("مفعّل" if explanations_enabled else "متوقف"))
    explanation_button.pressed.connect(func():
        explanations_enabled = not explanations_enabled
        _save_player_data()
        _show_settings()
    )
    content.add_child(explanation_button)

    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _set_difficulty(value: String) -> void:
    difficulty = value
    _save_player_data()
    _show_settings()

func _show_achievements() -> void:
    _clear_content()
    _add_heading("النجوم والإنجازات", "كل إجابة صحيحة تقرّبك من لقب العبقري")
    _add_stat_card("أفضل نتيجة", "🏆  %d نقطة" % best_score)
    _add_stat_card("الجولات المكتملة", "🎮  %d جولة" % games_played)
    _add_stat_card("بداية الطريق", "⭐  %s" % ("مفتوح" if games_played >= 1 else "مغلق"))
    _add_stat_card("عبقري التحدّي", "🌟  %s" % ("مفتوح" if best_score >= 80 else "احصل على 80 نقطة"))
    _add_stat_card("أسطورة المعرفة", "👑  %s" % ("مفتوح" if best_score >= 100 else "احصل على 100 نقطة"))
    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _show_help() -> void:
    _clear_content()
    _add_heading("طريقة اللعب", "أثبت ذكاءك في مجموعة من الأسئلة المتنوعة")
    var rules := Label.new()
    rules.text = "١. تبدأ رحلتك من الجزائر، وكل دولة تمثل مرحلة مستقلة.\n\n٢. اسحب الكرة الأرضية بإصبعك لتدويرها واكتشاف البلدان.\n\n٣. اضغط على الجزائر لبدء أول تحدٍّ، ثم افتح الدولة التالية بعد النجاح.\n\n٤. تحتاج إلى 60٪ على الأقل لفتح البلد التالي.\n\n٥. الأسئلة متنوعة في التاريخ والجغرافيا والعلوم والثقافة وغيرها.\n\nتعمل اللعبة دون إنترنت وتحفظ تقدمك على الهاتف."
    rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules.add_theme_font_size_override("font_size", 19)
    rules.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
    rules.custom_minimum_size.y = 360
    content.add_child(rules)
    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _set_globe_mode(enabled: bool) -> void:
    if world_camera != null:
        if enabled:
            world_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
            world_camera.position = Vector3(0, 0, 7.6)
            world_camera.near = 0.02
            world_camera.far = 120.0
            world_camera.fov = 43.0
        else:
            world_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
            world_camera.position = Vector3(0, 0, 12)
            world_camera.size = 15.5
    for backdrop in get_tree().get_nodes_in_group("fantasy_map"):
        if is_instance_valid(backdrop):
            backdrop.visible = not enabled
    if world_globe != null:
        world_globe.visible = enabled
    if interface_margin != null:
        interface_margin.visible = not enabled
    if interface_root != null and interface_root.get_child_count() > 0:
        interface_root.get_child(0).visible = not enabled
    if globe_hud != null and is_instance_valid(globe_hud):
        globe_hud.visible = enabled

func _show_world_map() -> void:
    _clear_content()
    _set_globe_mode(true)
    if world_globe == null:
        world_globe = WorldGlobe.new()
        world_globe.country_tapped.connect(_on_country_tapped)
        add_child(world_globe)
    world_globe.set_progress(unlocked_country_index)
    world_globe.visible = true
    if globe_hud != null and is_instance_valid(globe_hud):
        globe_hud.queue_free()
    globe_hud = PanelContainer.new()
    globe_hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    globe_hud.offset_left = 22
    globe_hud.offset_right = -22
    globe_hud.offset_top = -206
    globe_hud.offset_bottom = -22
    globe_hud.mouse_filter = Control.MOUSE_FILTER_STOP
    var hud_style := StyleBoxFlat.new()
    hud_style.bg_color = Color(0.015, 0.045, 0.10, 0.88)
    hud_style.border_color = Color(0.25, 0.62, 0.86, 0.78)
    hud_style.set_border_width_all(1)
    hud_style.set_corner_radius_all(22)
    hud_style.content_margin_left = 18
    hud_style.content_margin_right = 18
    hud_style.content_margin_top = 12
    hud_style.content_margin_bottom = 12
    globe_hud.add_theme_stylebox_override("panel", hud_style)
    var hud_box := VBoxContainer.new()
    hud_box.add_theme_constant_override("separation", 7)
    globe_hud.add_child(hud_box)
    var title := Label.new()
    title.text = "🌍  رحلة العباقرة حول العالم"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 21)
    title.add_theme_color_override("font_color", Color("#f1f7ff"))
    hud_box.add_child(title)
    var next_country: String = str(world_globe.get_route_country_name(unlocked_country_index))
    var progress := Label.new()
    progress.text = "الوجهة المفتوحة: %s   •   %d / 177" % [next_country, unlocked_country_index + 1]
    progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress.add_theme_font_size_override("font_size", 16)
    progress.add_theme_color_override("font_color", Color("#82e7d2"))
    hud_box.add_child(progress)
    var hint := Label.new()
    hint.text = "اسحب للتدوير • قرّب بإصبعين لرؤية تفاصيل شمال إفريقيا • المس الدولة"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 14)
    hint.add_theme_color_override("font_color", Color("#c5d9f2"))
    hud_box.add_child(hint)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    hud_box.add_child(actions)
    var home := _make_button("⌂  الرئيسية")
    home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    home.custom_minimum_size.y = 54
    home.add_theme_font_size_override("font_size", 17)
    home.pressed.connect(_show_main_menu)
    actions.add_child(home)
    interface_root.add_child(globe_hud)

func _on_country_tapped(index: int, code: String, name: String, unlocked: bool) -> void:
    if unlocked and index >= 0 and index <= unlocked_country_index:
        _start_country(index, code, name)
    else:
        _show_country_locked(index, code, name)

func _show_country_locked(index: int, code: String, name: String) -> void:
    _clear_content()
    _add_heading(name, "مرحلة من رحلة العباقرة حول العالم")
    if index < 0:
        _add_stat_card("حالة الدولة", "ستُضاف إلى مسار الرحلة لاحقاً")
    elif index > unlocked_country_index:
        _add_stat_card("حالة الدولة", "🔒 مغلقة")
        var message := Label.new()
        message.text = "أكمل تحدّي %s أولاً حتى تفتح هذه الدولة." % world_globe.get_route_country_name(unlocked_country_index)
        message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        message.add_theme_font_size_override("font_size", 18)
        message.add_theme_color_override("font_color", Color("#ffd27a"))
        content.add_child(message)
    else:
        _add_stat_card("حالة الدولة", "✓ سبق أن فتحتها")
    var back := _make_button("🌍   العودة إلى الكرة الأرضية")
    back.pressed.connect(_show_world_map)
    content.add_child(back)


func _start_country(index: int, code: String = "DZA", name: String = "الجزائر") -> void:
    current_country_index = index
    current_country_code = code
    current_country_name = name
    _set_globe_mode(false)
    _play_country_arrival()

func _play_country_arrival() -> void:
    _clear_content()
    # Cinematic flight transition: the aircraft crosses the screen before landing.
    var flight_layer := Control.new()
    flight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flight_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    interface_root.add_child(flight_layer)

    var sky := ColorRect.new()
    sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sky.color = Color(0.008, 0.018, 0.052, 0.12)
    sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flight_layer.add_child(sky)

    var glow := ColorRect.new()
    glow.position = Vector2(0, 430)
    glow.size = Vector2(720, 3)
    glow.color = Color(0.18, 0.62, 1.0, 0.48)
    flight_layer.add_child(glow)

    var destination := Label.new()
    destination.text = "الوجهة القادمة\n" + current_country_name
    destination.position = Vector2(30, 145)
    destination.size = Vector2(660, 150)
    destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    destination.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    destination.add_theme_font_size_override("font_size", 34)
    destination.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
    flight_layer.add_child(destination)

    var flight_status := Label.new()
    flight_status.text = "✈  جارٍ التحليق نحو " + current_country_name
    flight_status.position = Vector2(25, 920)
    flight_status.size = Vector2(670, 55)
    flight_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    flight_status.add_theme_font_size_override("font_size", 20)
    flight_status.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0))
    flight_layer.add_child(flight_status)

    var aircraft := _make_cinematic_aircraft()
    aircraft.position = Vector3(-8.5, 1.8, 0.0)
    aircraft.rotation = Vector3(0.0, PI * 0.5, 0.0)
    aircraft.scale = Vector3(0.28, 0.28, 0.28)
    add_child(aircraft)

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(aircraft, "position", Vector3(1.8, -0.8, 0.6), 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(aircraft, "rotation", Vector3(0.12, PI * 0.5, -0.22), 1.2)
    tween.tween_property(aircraft, "scale", Vector3(0.72, 0.72, 0.72), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(world_camera, "position", Vector3(0.7, -0.2, 10.0), 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(glow, "modulate:a", 0.9, 1.0)
    tween.chain().tween_interval(0.25)
    tween.tween_callback(func():
        if is_instance_valid(flight_layer):
            flight_layer.queue_free()
        if is_instance_valid(aircraft):
            aircraft.queue_free()
        world_camera.position = Vector3(0, 0, 12)
        _show_country_briefing()
    )


func _make_cinematic_aircraft() -> Node3D:
    var plane := Node3D.new()
    plane.name = "CinematicAircraft"
    var silver := StandardMaterial3D.new()
    silver.albedo_color = Color("#dce8f2")
    silver.metallic = 0.62
    silver.roughness = 0.28
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("#253b56")
    dark.metallic = 0.48
    dark.roughness = 0.34
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color("#4badd8")
    glass.metallic = 0.25
    glass.roughness = 0.16
    glass.emission_enabled = true
    glass.emission = Color("#123c58")
    _aircraft_part(plane, BoxMesh.new(), Vector3(0, 0, 0), Vector3(0.22, 0.24, 2.45), silver)
    _aircraft_part(plane, BoxMesh.new(), Vector3(0, 0.03, -0.05), Vector3(2.5, 0.075, 0.72), silver)
    _aircraft_part(plane, BoxMesh.new(), Vector3(0, 0.11, -0.91), Vector3(0.95, 0.06, 0.38), silver)
    _aircraft_part(plane, BoxMesh.new(), Vector3(0, 0.45, -0.96), Vector3(0.08, 0.7, 0.34), silver)
    _aircraft_part(plane, SphereMesh.new(), Vector3(0, 0.16, 0.68), Vector3(0.15, 0.13, 0.48), glass)
    _aircraft_part(plane, BoxMesh.new(), Vector3(-0.72, -0.05, -0.02), Vector3(0.34, 0.13, 0.78), dark)
    _aircraft_part(plane, BoxMesh.new(), Vector3(0.72, -0.05, -0.02), Vector3(0.34, 0.13, 0.78), dark)
    return plane

func _aircraft_part(parent: Node3D, mesh_resource: Mesh, at: Vector3, dimensions: Vector3, material: Material) -> void:
    var part := MeshInstance3D.new()
    part.mesh = mesh_resource
    part.position = at
    part.scale = dimensions
    part.material_override = material
    parent.add_child(part)

func _show_country_briefing() -> void:
    _clear_content()
    var flags := {"DZA":"🇩🇿", "TUN":"🇹🇳", "LBY":"🇱🇾", "EGY":"🇪🇬", "MAR":"🇲🇦"}
    var flag := str(flags.get(current_country_code, "🌍"))
    _add_heading(flag + "  أهلاً بك في " + current_country_name, "وصلت إلى وجهتك! استعد لاكتشاف أسرارها واختبار ذكائك")
    _add_stat_card("محطة الرحلة", "%d" % (current_country_index + 1))
    _add_stat_card("محتوى التحدّي", "تاريخ • جغرافيا • علوم • ثقافة")
    var welcome := Label.new()
    welcome.text = "تم الهبوط بنجاح ✦\nأمامك مجموعة أسئلة مستوحاة من هذه الدولة. اجمع النقاط وأثبت أنك تستحق فتح الوجهة التالية."
    welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    welcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    welcome.custom_minimum_size.y = 120
    welcome.add_theme_font_size_override("font_size", 19)
    welcome.add_theme_color_override("font_color", Color(0.82, 0.91, 1.0))
    content.add_child(welcome)
    var launch := _make_button("🚀  ابدأ تحدّي " + current_country_name)
    launch.custom_minimum_size.y = 82
    launch.pressed.connect(func(): _start_level(1))
    content.add_child(launch)
    var back := _make_button("🌍  العودة إلى الكرة الأرضية")
    back.pressed.connect(_show_world_map)
    content.add_child(back)

func _show_world_levels(world: int) -> void:
    _clear_content()
    var first_level := world * 2 + 1
    var names := ["وادي المعرفة", "غابة الألغاز", "مدينة العلوم", "قلعة العباقرة", "قمة الأساطير"]
    var icons := ["✦", "♣", "⚗", "♜", "♛"]
    var completed_stages := clampi(unlocked_level - first_level, 0, 2)
    _add_heading("%s  %s" % [icons[world], names[world]], "استكشف الخريطة… واتبع الطريق حتى قلعة الحارس")

    var banner := PanelContainer.new()
    var banner_style := StyleBoxFlat.new()
    banner_style.bg_color = Color(0.055, 0.11, 0.22, 0.97)
    banner_style.border_color = Color(0.38, 0.72, 0.88)
    banner_style.set_border_width_all(2)
    banner_style.set_corner_radius_all(16)
    banner_style.content_margin_left = 12
    banner_style.content_margin_right = 12
    banner_style.content_margin_top = 8
    banner_style.content_margin_bottom = 8
    banner.add_theme_stylebox_override("panel", banner_style)
    var banner_box := VBoxContainer.new()
    banner_box.add_theme_constant_override("separation", 5)
    banner.add_child(banner_box)
    var progress_title := Label.new()
    progress_title.text = "تقدّمك في العالم  •  %d / 2 مراحل" % completed_stages
    progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_title.add_theme_font_size_override("font_size", 17)
    progress_title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
    banner_box.add_child(progress_title)
    var progress := ProgressBar.new()
    progress.min_value = 0
    progress.max_value = 2
    progress.value = completed_stages
    progress.show_percentage = false
    progress.custom_minimum_size.y = 10
    banner_box.add_child(progress)
    content.add_child(banner)

    var map_frame := PanelContainer.new()
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color("#10243a")
    frame_style.border_color = Color("#80c7d0")
    frame_style.set_border_width_all(2)
    frame_style.set_corner_radius_all(18)
    frame_style.content_margin_left = 5
    frame_style.content_margin_right = 5
    frame_style.content_margin_top = 5
    frame_style.content_margin_bottom = 5
    map_frame.add_theme_stylebox_override("panel", frame_style)
    map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var map_art = WorldMapArt.new()
    map_art.configure(world, unlocked_level)
    map_art.custom_minimum_size = Vector2(0, 650)
    map_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_art.stage_selected.connect(_start_level)
    map_frame.add_child(map_art)
    content.add_child(map_frame)

    var legend := HBoxContainer.new()
    legend.add_theme_constant_override("separation", 8)
    var stage_one := Label.new()
    stage_one.text = "①  بوابة البداية"
    stage_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage_one.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage_one.add_theme_font_size_override("font_size", 15)
    stage_one.add_theme_color_override("font_color", Color("#f5d58a"))
    legend.add_child(stage_one)
    var stage_two := Label.new()
    stage_two.text = "②  حارس العالم"
    stage_two.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage_two.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage_two.add_theme_font_size_override("font_size", 15)
    stage_two.add_theme_color_override("font_color", Color("#f5d58a"))
    legend.add_child(stage_two)
    content.add_child(legend)

    var hint := Label.new()
    hint.text = "اضغط على علامة المرحلة في الخريطة للعب • الطريق يفتح بالتدريج"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 14)
    hint.add_theme_color_override("font_color", Color(0.68, 0.82, 0.94))
    content.add_child(hint)

    if completed_stages == 2:
        var finished := Label.new()
        finished.text = "🏆 اكتملت هذه الخريطة! البوابة التالية مفتوحة."
        finished.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        finished.add_theme_font_size_override("font_size", 16)
        finished.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
        content.add_child(finished)

    var back := _make_button("←   العودة إلى خريطة العوالم")
    back.pressed.connect(_show_world_map)
    content.add_child(back)

func _show_levels() -> void:
    _clear_content()
    _add_heading("اختر مستواك", "كلما تقدّمت، يقلّ الوقت وتزداد النقاط")
    for level in range(1, 11):
        var locked := level > unlocked_level
        var seconds := maxi(8, 22 - (level - 1))
        var label := "🔒 المستوى %d — مغلق" % level if locked else "⭐ المستوى %d%s\n%d ثانية لكل سؤال" % [level, " — الحالي" if level == unlocked_level else "", seconds]
        var button := _make_button(label)
        button.custom_minimum_size.y = 72
        button.disabled = locked
        if not locked:
            button.pressed.connect(func(): _start_level(level))
        content.add_child(button)
    var back := _make_button("→   العودة للرئيسية")
    back.pressed.connect(_show_main_menu)
    content.add_child(back)

func _start_game() -> void:
    _start_level(current_level)

func _start_level(level: int) -> void:
    current_level = clampi(level, 1, 10)
    if current_level > mini(unlocked_level, 10):
        _show_world_map()
        return
    if questions.is_empty():
        _clear_content()
        _add_heading("تعذّر بدء اللعبة", "لم نتمكن من تحميل الأسئلة. أعد تشغيل التطبيق.")
        var back_error := _make_button("العودة للرئيسية")
        back_error.pressed.connect(_show_main_menu)
        content.add_child(back_error)
        return

    score = 0
    correct_answers = 0
    time_limit = maxf(8.0, 22.0 - float(current_level - 1))
    showing_results = false
    question_index = 0
    question_pool.clear()
    for i in range(questions.size()):
        var candidate: Dictionary = questions[i]
        if str(candidate.get("country", "")) == current_country_code:
            question_pool.append(i)
    if question_pool.is_empty():
        for i in range(questions.size()):
            var general_candidate: Dictionary = questions[i]
            if str(general_candidate.get("country", "")).is_empty():
                question_pool.append(i)
    if question_pool.is_empty():
        for i in range(questions.size()):
            question_pool.append(i)
    question_order.clear()
    for i in range(question_pool.size()):
        question_order.append(i)
    question_order.shuffle()
    question_order.resize(mini(5, question_order.size()))
    _display_question()

func _display_question() -> void:
    answered = false
    _clear_content()
    var item: Dictionary = questions[question_pool[question_order[question_index]]]

    category_label = Label.new()
    category_label.text = "✦  %s  ✦" % str(item.get("category", "تحدّي عام"))
    category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    category_label.add_theme_font_size_override("font_size", 20)
    category_label.add_theme_color_override("font_color", Color(0.42, 0.85, 1.0))
    content.add_child(category_label)

    progress_label = Label.new()
    progress_label.text = "السؤال %d / %d" % [question_index + 1, question_order.size()]
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 17)
    progress_label.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0))
    content.add_child(progress_label)

    score_label = Label.new()
    score_label.text = "⭐ %d نقطة" % score
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_label.add_theme_font_size_override("font_size", 18)
    score_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
    content.add_child(score_label)

    time_label = Label.new()
    time_label.text = "⏱  الوقت المتبقي: %d ثانية" % int(time_limit)
    time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    time_label.add_theme_font_size_override("font_size", 20)
    time_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
    content.add_child(time_label)

    question_label = Label.new()
    question_label.text = str(item.get("question", ""))
    question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    question_label.custom_minimum_size.y = 150
    question_label.add_theme_font_size_override("font_size", 26)
    question_label.add_theme_color_override("font_color", Color.WHITE)
    content.add_child(question_label)

    var options: Array = item.get("answers", [])
    for i in range(options.size()):
        var answer_text := str(options[i])
        var answer_button := _make_button(answer_text)
        answer_button.pressed.connect(_select_answer.bind(answer_text))
        content.add_child(answer_button)

    feedback_label = Label.new()
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.custom_minimum_size.y = 72
    feedback_label.add_theme_font_size_override("font_size", 17)
    feedback_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
    content.add_child(feedback_label)

    next_button = _make_button("السؤال التالي  ←")
    next_button.disabled = true
    next_button.pressed.connect(_next_question)
    content.add_child(next_button)

    question_timer.start(time_limit)

    var home_button := _make_button("القائمة الرئيسية")
    home_button.pressed.connect(_show_main_menu)
    content.add_child(home_button)

func _select_answer(selected: String) -> void:
    # Ignore duplicate taps and stale callbacks after a screen change.
    if answered or question_timer == null or not is_instance_valid(question_timer):
        return
    if question_order.is_empty() or question_index < 0 or question_index >= question_order.size():
        return
    var question_id := question_pool[question_order[question_index]]
    if question_id < 0 or question_id >= questions.size():
        return
    if not questions[question_id] is Dictionary:
        return

    answered = true
    question_timer.stop()
    var item: Dictionary = questions[question_id]
    var raw_options = item.get("answers", [])
    var options: Array = raw_options if raw_options is Array else []
    var correct_index := int(item.get("correct", -1))
    var correct_answer := ""
    if correct_index >= 0 and correct_index < options.size():
        correct_answer = str(options[correct_index])

    var is_correct := not correct_answer.is_empty() and selected == correct_answer
    if is_correct:
        correct_answers += 1
        var points := 10 + current_level * 2
        score += points
        if is_instance_valid(feedback_label):
            feedback_label.text = "إجابة صحيحة! أحسنت +%d ⭐" % points
            if explanations_enabled:
                feedback_label.text += "\n" + str(item.get("explanation", ""))
            feedback_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.68))
    else:
        if is_instance_valid(feedback_label):
            feedback_label.text = "إجابة غير صحيحة. الجواب: " + (correct_answer if not correct_answer.is_empty() else "غير متوفر")
            if explanations_enabled:
                feedback_label.text += "\n" + str(item.get("explanation", ""))
            feedback_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.55))
    if selected.is_empty() and is_instance_valid(feedback_label):
        feedback_label.text = "انتهى الوقت! " + feedback_label.text

    # Vibration is disabled in this build while Android answer handling is being stabilized.
    if is_instance_valid(score_label):
        score_label.text = "⭐ %d نقطة" % score
    if is_instance_valid(next_button):
        next_button.disabled = false
        if question_index == question_order.size() - 1:
            next_button.text = "عرض النتيجة"

func _on_question_timeout() -> void:
    if not answered:
        _select_answer("")

func _next_question() -> void:
    if not answered:
        return
    if question_index >= question_order.size() - 1:
        _show_results()
        return
    question_index += 1
    _display_question()

func _show_results() -> void:
    showing_results = true
    games_played += 1
    if score > best_score:
        best_score = score
    _save_player_data()

    var points_per_question := 10 + current_level * 2
    _clear_content()
    _add_heading("انتهى تحدّي %s!" % current_country_name, "هذه حصيلتك في هذه الدولة")
    _add_stat_card("نتيجتك", "⭐  %d / %d نقطة" % [score, question_order.size() * points_per_question])
    _add_stat_card("أفضل نتيجة شخصية", "🏆  %d نقطة" % best_score)
    var percent := int(round(float(correct_answers) / float(question_order.size()) * 100.0))
    var journey_message := ""
    if percent >= 60 and current_country_index == unlocked_country_index:
        unlocked_country_index = mini(unlocked_country_index + 1, 176)
        journey_message = "🎉 ممتاز! فتحت الدولة التالية في رحلتك."
        _save_player_data()
    elif percent < 60:
        journey_message = "تحتاج إلى 60٪ على الأقل لفتح الدولة التالية. حاول مجدداً!"
    else:
        journey_message = "لقد فتحت هذه الدولة سابقاً. يمكنك مواصلة الرحلة."
    if percent >= 60 and current_country_index >= 176:
        journey_message = "🏆 أكملت رحلة دول العالم! أنت أسطورة العباقرة."
    var result_text := Label.new()
    result_text.text = "نسبة الإجابات الصحيحة: %d%%\n%s" % [percent, journey_message]
    result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result_text.add_theme_font_size_override("font_size", 20)
    result_text.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
    content.add_child(result_text)

    var replay := _make_button("↻   أعد تحدّي %s" % current_country_name)
    replay.pressed.connect(func(): _start_country(current_country_index, current_country_code, current_country_name))
    content.add_child(replay)
    var next := _make_button("🌍   متابعة الرحلة على الكرة الأرضية")
    next.pressed.connect(_show_world_map)
    content.add_child(next)
    var home := _make_button("⌂   القائمة الرئيسية")
    home.pressed.connect(_show_main_menu)
    content.add_child(home)

func _make_button(caption: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 64)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 20)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color(0.75, 0.9, 1.0))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.12, 0.19, 0.38, 0.96)
    normal.border_color = Color(0.27, 0.48, 0.85, 0.9)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(18)
    normal.content_margin_left = 18
    normal.content_margin_right = 18
    normal.content_margin_top = 8
    normal.content_margin_bottom = 8
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = Color(0.17, 0.28, 0.52, 1.0)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    var disabled_style := normal.duplicate()
    disabled_style.bg_color = Color(0.08, 0.11, 0.20, 0.9)
    button.add_theme_stylebox_override("disabled", disabled_style)
    return button
