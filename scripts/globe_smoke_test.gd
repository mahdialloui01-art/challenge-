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
    print("WORLD_GLOBE_SMOKE_OK")
    quit()
