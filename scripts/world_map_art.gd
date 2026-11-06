extends Control

signal stage_selected(level: int)

var world_index: int = 0
var unlocked_level: int = 1
var node_points: Array[Vector2] = [Vector2(190, 545), Vector2(520, 235)]
var map_tints := [
    Color("#49b99a"), Color("#72b95b"), Color("#4c9bd1"),
    Color("#a17ad0"), Color("#e0a64c")
]

func configure(index: int, unlocked: int) -> void:
    world_index = clampi(index, 0, 4)
    unlocked_level = unlocked
    queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(0, 690)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resized.connect(queue_redraw)

func _draw() -> void:
    var sx: float = size.x / 720.0
    var sy: float = size.y / 760.0
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
    var tint: Color = map_tints[world_index]
    # A hand-painted fantasy atlas, not a stack of level cards.
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 0), Vector2(720, 0), Vector2(720, 760), Vector2(0, 760)
    ]), Color("#10233a"))
    draw_colored_polygon(PackedVector2Array([
        Vector2(28, 24), Vector2(692, 24), Vector2(692, 736), Vector2(28, 736)
    ]), Color("#25465a"))
    draw_colored_polygon(PackedVector2Array([
        Vector2(48, 45), Vector2(672, 45), Vector2(672, 715), Vector2(48, 715)
    ]), Color("#345b58"))
    # Uneven land masses and coastal coves.
    draw_colored_polygon(PackedVector2Array([
        Vector2(48, 45), Vector2(390, 45), Vector2(350, 130), Vector2(405, 205),
        Vector2(335, 295), Vector2(370, 390), Vector2(285, 475), Vector2(330, 590),
        Vector2(250, 715), Vector2(48, 715)
    ]), tint.darkened(0.40))
    draw_colored_polygon(PackedVector2Array([
        Vector2(390, 45), Vector2(672, 45), Vector2(672, 715), Vector2(330, 715),
        Vector2(390, 610), Vector2(345, 520), Vector2(440, 420), Vector2(385, 330),
        Vector2(465, 240), Vector2(405, 155)
    ]), tint.darkened(0.26))
    # Rivers and a lake.
    draw_colored_polygon(PackedVector2Array([
        Vector2(48, 360), Vector2(135, 330), Vector2(210, 365), Vector2(300, 340),
        Vector2(390, 375), Vector2(485, 340), Vector2(672, 365), Vector2(672, 405),
        Vector2(485, 382), Vector2(390, 420), Vector2(300, 380), Vector2(210, 405),
        Vector2(135, 370), Vector2(48, 402)
    ]), Color("#367f9a"))
    draw_circle(Vector2(560, 560), 62, Color("#347f9b"))
    draw_arc(Vector2(560, 560), 64, 0, TAU, 72, Color("#70c3c9"), 4.0, true)
    # Hills, mountain ridges and forests vary by world.
    for i in range(9):
        var p := Vector2(95.0 + float((i * 83) % 530), 105.0 + float((i * 137) % 520))
        if world_index == 2 or world_index == 4:
            draw_colored_polygon(PackedVector2Array([
                p + Vector2(-34, 28), p + Vector2(0, -38), p + Vector2(38, 28)
            ]), Color("#b8c9d4") if world_index == 4 else Color("#66899c"))
            draw_colored_polygon(PackedVector2Array([
                p + Vector2(-15, -8), p + Vector2(0, -38), p + Vector2(17, -8)
            ]), Color("#f0f2e8"))
        else:
            draw_circle(p, 25, tint.darkened(0.16))
            draw_circle(p + Vector2(-13, 7), 19, tint.darkened(0.08))
            draw_circle(p + Vector2(13, 8), 18, tint.lightened(0.08))
    # Winding dotted stone trail with a bright outer stroke.
    var route := PackedVector2Array([
        Vector2(190, 545), Vector2(115, 500), Vector2(140, 445),
        Vector2(250, 430), Vector2(325, 465), Vector2(405, 450),
        Vector2(465, 390), Vector2(420, 330), Vector2(465, 275), Vector2(520, 235)
    ])
    draw_polyline(route, Color("#172b3b"), 24.0, true)
    draw_polyline(route, Color("#e3c58a"), 12.0, true)
    draw_polyline(route, Color("#fff0bd"), 3.0, true)
    for i in range(24):
        var t := float(i) / 23.0
        var seg := int(floor(t * float(route.size() - 1)))
        var local_t := t * float(route.size() - 1) - float(seg)
        var point: Vector2 = route[seg].lerp(route[mini(seg + 1, route.size() - 1)], local_t)
        draw_circle(point, 3.2, Color("#fff4cf"))
    # World-specific landmark at the finish.
    if world_index == 0:
        _draw_tower(Vector2(520, 185), tint)
    elif world_index == 1:
        for i in range(5):
            _draw_tree(Vector2(490 + float(i % 3) * 44, 130 + float(i / 3) * 35), tint)
    elif world_index == 2:
        _draw_tower(Vector2(520, 185), tint)
        draw_circle(Vector2(520, 145), 20, Color("#83e7ff"))
    elif world_index == 3:
        _draw_castle(Vector2(520, 170), tint)
    else:
        _draw_tower(Vector2(520, 175), Color("#ffc85c"))
        draw_colored_polygon(PackedVector2Array([
            Vector2(493, 128), Vector2(520, 75), Vector2(547, 128)
        ]), Color("#ffd77a"))
    # Stage markers are large, unmistakable map pins.
    for i in range(2):
        var point: Vector2 = node_points[i]
        var level := world_index * 2 + i + 1
        var completed := level < unlocked_level
        var locked := level > mini(unlocked_level, 10)
        var fill := Color("#39c995") if completed else (Color("#687b91") if locked else Color("#ffd166"))
        draw_circle(point + Vector2(0, 7), 34, Color(0, 0, 0, 0.30))
        draw_circle(point, 34, Color("#f5e7c8"))
        draw_circle(point, 28, fill)
        draw_arc(point, 30, 0, TAU, 64, Color("#fff4d2"), 4.0, true)
        draw_circle(point, 7, Color("#fff8e8"))
        draw_string(ThemeDB.fallback_font, point + Vector2(-6, 6), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#172b3b"))
        if locked:
            draw_arc(point, 13, PI, TAU, 24, Color("#e5edf6"), 3.0, true)
            draw_rect(Rect2(point + Vector2(-11, -1), Vector2(22, 16)), Color("#e5edf6"), true)
    # Full-map lock: later worlds stay visibly sealed until the previous world is completed.
    var world_first_level := world_index * 2 + 1
    if world_first_level > unlocked_level:
        draw_rect(Rect2(48, 45, 624, 670), Color(0.012, 0.020, 0.034, 0.82), true)
        var lock_center := Vector2(360, 292)
        draw_arc(lock_center + Vector2(0, -13), 43, PI, TAU, 48, Color("#f3d99a"), 11.0, true)
        draw_rect(Rect2(lock_center + Vector2(-55, -12), Vector2(110, 88)), Color("#d5b46c"), true)
        draw_rect(Rect2(lock_center + Vector2(-44, -1), Vector2(88, 66)), Color("#f0d69a"), true)
        draw_circle(lock_center + Vector2(0, 25), 9, Color("#4b3924"))
        draw_rect(Rect2(lock_center + Vector2(-4, 29), Vector2(8, 19)), Color("#4b3924"), true)
        draw_string(ThemeDB.fallback_font, Vector2(80, 430), "هذه الخريطة مقفلة", HORIZONTAL_ALIGNMENT_CENTER, 560, 30, Color("#fff0c8"))
        draw_string(ThemeDB.fallback_font, Vector2(80, 475), "أكمل الخريطة السابقة لفتح هذه المغامرة", HORIZONTAL_ALIGNMENT_CENTER, 560, 19, Color("#e3d5b8"))
        draw_string(ThemeDB.fallback_font, Vector2(80, 520), "المرحلة المطلوبة: %d" % (world_first_level - 1), HORIZONTAL_ALIGNMENT_CENTER, 560, 17, Color("#f5ca73"))
    draw_set_transform(Vector2.ZERO)

func _draw_tree(p: Vector2, tint: Color) -> void:
    draw_rect(Rect2(p + Vector2(-4, 0), Vector2(8, 24)), Color("#68472e"))
    draw_circle(p + Vector2(0, -8), 19, tint.lightened(0.10))
    draw_circle(p + Vector2(-11, 0), 13, tint)
    draw_circle(p + Vector2(11, 0), 13, tint.darkened(0.12))

func _draw_tower(p: Vector2, tint: Color) -> void:
    draw_rect(Rect2(p + Vector2(-18, -8), Vector2(36, 55)), Color("#d6d5c6"))
    draw_colored_polygon(PackedVector2Array([
        p + Vector2(-25, -8), p + Vector2(0, -42), p + Vector2(25, -8)
    ]), tint.lightened(0.25))
    draw_rect(Rect2(p + Vector2(-6, 20), Vector2(12, 27)), Color("#34465a"))

func _draw_castle(p: Vector2, tint: Color) -> void:
    draw_rect(Rect2(p + Vector2(-48, -5), Vector2(96, 62)), Color("#bfc5d0"))
    for x in [-43.0, 28.0]:
        draw_rect(Rect2(p + Vector2(x, -38), Vector2(18, 96)), Color("#d8d9dd"))
        draw_colored_polygon(PackedVector2Array([
            p + Vector2(x - 5, -38), p + Vector2(x + 9, -62), p + Vector2(x + 23, -38)
        ]), tint.lightened(0.35))
    draw_rect(Rect2(p + Vector2(-10, 24), Vector2(20, 33)), Color("#45536a"))

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _try_select(event.position)
    elif event is InputEventScreenTouch and event.pressed:
        _try_select(event.position)

func _try_select(pos: Vector2) -> void:
    if world_index * 2 + 1 > unlocked_level:
        accept_event()
        return
    var sx: float = size.x / 720.0
    var sy: float = size.y / 760.0
    var p := Vector2(pos.x / sx, pos.y / sy)
    for i in range(2):
        if p.distance_to(node_points[i]) <= 42.0:
            var level := world_index * 2 + i + 1
            if level <= mini(unlocked_level, 10):
                stage_selected.emit(level)
            accept_event()
            return
