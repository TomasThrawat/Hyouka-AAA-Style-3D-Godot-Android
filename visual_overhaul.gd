extends Node3D

const CYAN = Color("55e6ff")
const MAGENTA = Color("ff4fd8")
const TEXT = Color("e8f7ff")
const MUTED = Color("8fa8ba")
const PANEL = Color(0.025, 0.055, 0.09, 0.90)
const PANEL_SOFT = Color(0.04, 0.085, 0.13, 0.72)

func _ready():
    _add_lighting()
    _add_arena_accents()
    _add_hud()

func _add_lighting():
    if has_node("AAAKeyLight"):
        return
    var key = DirectionalLight3D.new()
    key.name = "AAAKeyLight"
    key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    key.light_color = Color("b7d7ff")
    key.light_energy = 1.15
    key.shadow_enabled = true
    add_child(key)

    var fill = OmniLight3D.new()
    fill.name = "AAACyanFill"
    fill.position = Vector3(0.0, 5.0, 2.0)
    fill.light_color = CYAN
    fill.light_energy = 3.0
    fill.omni_range = 16.0
    add_child(fill)

func _add_arena_accents():
    if has_node("AAAWorldAccents"):
        return
    var root = Node3D.new()
    root.name = "AAAWorldAccents"
    add_child(root)

    var glow = StandardMaterial3D.new()
    glow.albedo_color = CYAN
    glow.emission_enabled = true
    glow.emission = CYAN
    glow.emission_energy_multiplier = 3.5
    glow.roughness = 0.3

    var metal = StandardMaterial3D.new()
    metal.albedo_color = Color("101b2a")
    metal.metallic = 0.78
    metal.roughness = 0.34

    for i in range(8):
        var angle = TAU * float(i) / 8.0
        var radius = 14.0
        var pylon = MeshInstance3D.new()
        var mesh = BoxMesh.new()
        mesh.size = Vector3(0.35, 5.0 + float(i % 3), 0.35)
        pylon.mesh = mesh
        pylon.material_override = glow
        pylon.position = Vector3(cos(angle) * radius, 2.5, sin(angle) * radius)
        root.add_child(pylon)

    var platform = MeshInstance3D.new()
    platform.name = "AAAHeroPlatform"
    var platform_mesh = CylinderMesh.new()
    platform_mesh.top_radius = 8.0
    platform_mesh.bottom_radius = 8.0
    platform_mesh.height = 0.18
    platform_mesh.radial_segments = 32
    platform.mesh = platform_mesh
    platform.material_override = metal
    platform.position = Vector3(0.0, -0.12, 0.0)
    root.add_child(platform)

    var beacon = OmniLight3D.new()
    beacon.name = "AAAMagentaBeacon"
    beacon.position = Vector3(0.0, 4.0, -6.0)
    beacon.light_color = MAGENTA
    beacon.light_energy = 3.5
    beacon.omni_range = 18.0
    root.add_child(beacon)

func _add_hud():
    if has_node("CinematicHUD"):
        return
    var layer = CanvasLayer.new()
    layer.name = "CinematicHUD"
    layer.layer = 40
    add_child(layer)

    var root = Control.new()
    root.name = "HUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    var top = ColorRect.new()
    top.position = Vector2(28, 24)
    top.size = Vector2(1224, 72)
    top.color = PANEL
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top)

    var title = Label.new()
    title.position = Vector2(24, 10)
    title.text = "FRONTIER // ZERO"
    title.add_theme_color_override("font_color", TEXT)
    title.add_theme_font_size_override("font_size", 24)
    top.add_child(title)

    var subtitle = Label.new()
    subtitle.position = Vector2(26, 42)
    subtitle.text = "NEON FRONT  /  OPERATIONS DECK"
    subtitle.add_theme_color_override("font_color", MUTED)
    subtitle.add_theme_font_size_override("font_size", 11)
    top.add_child(subtitle)

    var status = Label.new()
    status.position = Vector2(1000, 18)
    status.text = "ONLINE\nSYSTEMS NOMINAL"
    status.add_theme_color_override("font_color", CYAN)
    status.add_theme_font_size_override("font_size", 12)
    top.add_child(status)

    var mission = ColorRect.new()
    mission.position = Vector2(28, 118)
    mission.size = Vector2(330, 104)
    mission.color = PANEL_SOFT
    mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(mission)

    var mtitle = Label.new()
    mtitle.position = Vector2(18, 12)
    mtitle.text = "ACTIVE OBJECTIVE"
    mtitle.add_theme_color_override("font_color", CYAN)
    mtitle.add_theme_font_size_override("font_size", 12)
    mission.add_child(mtitle)

    var mbody = Label.new()
    mbody.position = Vector2(18, 36)
    mbody.text = "SECURE THE FRONTIER NODE\nEstablish control of the orbital sector."
    mbody.add_theme_color_override("font_color", TEXT)
    mbody.add_theme_font_size_override("font_size", 14)
    mission.add_child(mbody)

    var footer = ColorRect.new()
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.position = Vector2(28, -74)
    footer.size = Vector2(1224, 48)
    footer.color = PANEL
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(footer)

    var hint = Label.new()
    hint.position = Vector2(18, 14)
    hint.text = "TACTICAL HUD  •  BOOST  •  SHIELD  •  PAUSE"
    hint.add_theme_color_override("font_color", MUTED)
    hint.add_theme_font_size_override("font_size", 11)
    footer.add_child(hint)

    var right = Label.new()
    right.position = Vector2(1020, 14)
    right.text = "MOBILE  /  60 FPS TARGET"
    right.add_theme_color_override("font_color", CYAN)
    right.add_theme_font_size_override("font_size", 11)
    footer.add_child(right)
