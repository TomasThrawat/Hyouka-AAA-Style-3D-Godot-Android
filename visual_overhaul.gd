extends Node3D
class_name FrontierVisualOverhaul

const BG = Color("07101c")
const PANEL = Color(0.025, 0.055, 0.09, 0.90)
const PANEL_SOFT = Color(0.04, 0.085, 0.13, 0.72)
const CYAN = Color("55e6ff")
const MAGENTA = Color("ff4fd8")
const TEXT = Color("e8f7ff")
const MUTED = Color("8fa8ba")

func _ready() -> void:
    _setup_environment()
    _build_world_accents()
    _build_hud()

func _setup_environment() -> void:
    var env_node := get_node_or_null("VisualEnvironment") as WorldEnvironment
    if env_node == null:
        env_node = WorldEnvironment.new()
        env_node.name = "VisualEnvironment"
        add_child(env_node)
    var env := env_node.environment
    if env == null:
        env = Environment.new()
        env_node.environment = env
    env.background_mode = Environment.BG_COLOR
    env.background_color = BG
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("19314a")
    env.ambient_light_energy = 0.72
    env.fog_enabled = true
    env.fog_light_color = Color("172b46")
    env.fog_light_energy = 0.55
    env.fog_density = 0.006
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.03
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 1.05

    if get_node_or_null("KeyLight") == null:
        var key := DirectionalLight3D.new()
        key.name = "KeyLight"
        key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
        key.light_color = Color("b7d7ff")
        key.light_energy = 1.15
        key.shadow_enabled = true
        add_child(key)

    if get_node_or_null("FillLight") == null:
        var fill := OmniLight3D.new()
        fill.name = "FillLight"
        fill.position = Vector3(0.0, 5.0, 2.0)
        fill.light_color = CYAN
        fill.light_energy = 3.0
        fill.omni_range = 16.0
        add_child(fill)

func _build_world_accents() -> void:
    if get_node_or_null("VisualAccents") != null:
        return
    var root := Node3D.new()
    root.name = "VisualAccents"
    add_child(root)

    var emissive := StandardMaterial3D.new()
    emissive.albedo_color = CYAN
    emissive.emission_enabled = true
    emissive.emission = CYAN
    emissive.emission_energy_multiplier = 4.0
    emissive.roughness = 0.28

    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("101b2a")
    dark.metallic = 0.78
    dark.roughness = 0.34

    for i in range(10):
        var angle := TAU * float(i) / 10.0
        var radius := 14.0 + float(i % 2) * 2.5
        var pylon := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.35, 5.0 + float(i % 3), 0.35)
        pylon.mesh = mesh
        pylon.material_override = emissive
        pylon.position = Vector3(cos(angle) * radius, 2.5, sin(angle) * radius)
        root.add_child(pylon)

        var cap := MeshInstance3D.new()
        var cap_mesh := SphereMesh.new()
        cap_mesh.radius = 0.38
        cap_mesh.height = 0.76
        cap.mesh = cap_mesh
        cap.material_override = emissive
        cap.position = pylon.position + Vector3.UP * (mesh.size.y * 0.5 + 0.25)
        root.add_child(cap)

    var platform := MeshInstance3D.new()
    platform.name = "HeroPlatform"
    var platform_mesh := CylinderMesh.new()
    platform_mesh.top_radius = 8.0
    platform_mesh.bottom_radius = 8.0
    platform_mesh.height = 0.18
    platform.mesh = platform_mesh
    platform.material_override = dark
    platform.position = Vector3(0.0, -0.12, 0.0)
    root.add_child(platform)

    var beacon := OmniLight3D.new()
    beacon.name = "NeonBeacon"
    beacon.position = Vector3(0.0, 4.0, -6.0)
    beacon.light_color = MAGENTA
    beacon.light_energy = 4.0
    beacon.omni_range = 18.0
    root.add_child(beacon)

func _build_hud() -> void:
    if get_node_or_null("CinematicHUD") != null:
        return
    var layer := CanvasLayer.new()
    layer.name = "CinematicHUD"
    layer.layer = 40
    add_child(layer)

    var root := Control.new()
    root.name = "HUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    var top := ColorRect.new()
    top.position = Vector2(28, 24)
    top.size = Vector2(1224, 72)
    top.color = PANEL
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top)

    var title := Label.new()
    title.position = Vector2(24, 12)
    title.text = "FRONTIER // ZERO"
    title.add_theme_color_override("font_color", TEXT)
    title.add_theme_font_size_override("font_size", 24)
    top.add_child(title)

    var subtitle := Label.new()
    subtitle.position = Vector2(26, 42)
    subtitle.text = "NEON FRONT // OPERATIONS DECK"
    subtitle.add_theme_color_override("font_color", MUTED)
    subtitle.add_theme_font_size_override("font_size", 11)
    top.add_child(subtitle)

    var status := Label.new()
    status.position = Vector2(1010, 18)
    status.text = "ONLINE\nSYSTEMS NOMINAL"
    status.add_theme_color_override("font_color", CYAN)
    status.add_theme_font_size_override("font_size", 12)
    top.add_child(status)

    var mission := ColorRect.new()
    mission.position = Vector2(28, 118)
    mission.size = Vector2(330, 104)
    mission.color = PANEL_SOFT
    mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(mission)

    var mtitle := Label.new()
    mtitle.position = Vector2(18, 12)
    mtitle.text = "ACTIVE OBJECTIVE"
    mtitle.add_theme_color_override("font_color", CYAN)
    mtitle.add_theme_font_size_override("font_size", 12)
    mission.add_child(mtitle)

    var mbody := Label.new()
    mbody.position = Vector2(18, 36)
    mbody.text = "SECURE THE FRONTIER NODE\nEstablish control of the orbital sector."
    mbody.add_theme_color_override("font_color", TEXT)
    mbody.add_theme_font_size_override("font_size", 14)
    mission.add_child(mbody)

    var footer := ColorRect.new()
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.position = Vector2(28, -74)
    footer.size = Vector2(1224, 48)
    footer.color = PANEL
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(footer)

    var hint := Label.new()
    hint.position = Vector2(18, 14)
    hint.text = "TACTICAL HUD  •  BOOST  •  SHIELD  •  PAUSE"
    hint.add_theme_color_override("font_color", MUTED)
    hint.add_theme_font_size_override("font_size", 11)
    footer.add_child(hint)

    var right := Label.new()
    right.position = Vector2(1020, 14)
    right.text = "MOBILE // 60 FPS TARGET"
    right.add_theme_color_override("font_color", CYAN)
    right.add_theme_font_size_override("font_size", 11)
    footer.add_child(right)
