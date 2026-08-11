extends Control

@onready var prestigio_label = $PrestigioLabel
@onready var mejoras_container = $ListaMejoras/Mejoras

var crow_storm = preload("res://resources/characters/crow_storm.tres")
var blaze_inferno = preload("res://resources/characters/blaze_inferno.tres")
var rex_thunder = preload("res://resources/characters/rex_thunder.tres")
var crash_doom = preload("res://resources/characters/crash_doom.tres")

var personajes_por_nombre = {}

# Paleta Battle Bands
const COLOR_BORDE = Color(0.85, 0.2, 0.8)
const COLOR_PANEL = Color(0.06, 0.06, 0.09, 0.95)
const COLOR_PANEL_HOVER = Color(0.15, 0.06, 0.16, 0.98)


func _ready():
	personajes_por_nombre = {
		"Crow Storm": crow_storm,
		"Blaze Inferno": blaze_inferno,
		"Rex Thunder": rex_thunder,
		"Crash Doom": crash_doom
	}
	var btn_volver = get_node_or_null("BtnVolver")
	if btn_volver != null and btn_volver is Button:
		_estilizar_boton(btn_volver)

	# Un poco de espacio entre filas de la lista
	if mejoras_container is VBoxContainer:
		mejoras_container.add_theme_constant_override("separation", 8)

	actualizar_prestigio()
	refrescar_tienda()


func actualizar_prestigio():
	prestigio_label.text = "💰 Prestigio: " + str(GameData.prestigio)


# --- Estilo Battle Bands ---
func _estilo_panel(color: Color = COLOR_PANEL) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(COLOR_BORDE.r, COLOR_BORDE.g, COLOR_BORDE.b, 0.5)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _estilizar_boton(btn: Button):
	var normal = StyleBoxFlat.new()
	normal.bg_color = COLOR_PANEL
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = COLOR_BORDE
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover = normal.duplicate()
	hover.bg_color = COLOR_PANEL_HOVER
	hover.border_color = Color(1, 0.4, 0.95)

	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.1, 0.14, 0.1, 0.9)
	disabled.border_color = Color(0.3, 0.6, 0.3, 0.6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.8, 0.5))


# CAMBIO: reconstruye TODO en una sola lista (mejoras + objetos), para
# que los objetos fluyan justo debajo de las mejoras sin posiciones fijas.
func refrescar_tienda():
	for child in mejoras_container.get_children():
		child.queue_free()

	# --- MEJORAS ---
	for id in UpgradeSystem.MEJORAS:
		var mejora = UpgradeSystem.MEJORAS[id]
		var ya_comprada = id in GameData.mejoras_compradas
		var texto = mejora["nombre"] + " (" + mejora["personaje"] + ")\n" + mejora["descripcion"]
		var btn_texto = "✅ Comprada" if ya_comprada else "💰 " + str(mejora["costo"])
		var fila = _crear_fila(texto, btn_texto, ya_comprada, COLOR_PANEL)
		if not ya_comprada:
			fila["boton"].pressed.connect(_on_comprar_pressed.bind(id))

	# --- Separador / encabezado de objetos ---
	var header = Label.new()
	header.text = "🎒 OBJETOS ESPECIALES"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	mejoras_container.add_child(header)

	# --- OBJETOS ---
	for id in UpgradeSystem.OBJETOS:
		var objeto = UpgradeSystem.OBJETOS[id]
		var cantidad = int(GameData.inventario.get(id, 0))
		var texto = objeto["nombre"] + "  (tienes: " + str(cantidad) + ")\n" + objeto["descripcion"]
		var fila = _crear_fila(texto, "💰 " + str(objeto["costo"]), false, Color(0.09, 0.06, 0.11, 0.95))
		fila["boton"].pressed.connect(_on_comprar_objeto_pressed.bind(id))


# Crea una fila (panel + info + botón). Devuelve dict con "boton".
func _crear_fila(texto: String, btn_texto: String, deshabilitado: bool, color_panel: Color) -> Dictionary:
	var fila = PanelContainer.new()
	fila.add_theme_stylebox_override("panel", _estilo_panel(color_panel))
	mejoras_container.add_child(fila)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	fila.add_child(hbox)

	var info = Label.new()
	info.custom_minimum_size = Vector2(400, 0)
	info.text = texto
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 50)
	_estilizar_boton(btn)
	btn.text = btn_texto
	btn.disabled = deshabilitado
	hbox.add_child(btn)

	return {"boton": btn}


func _on_comprar_pressed(id: String):
	var mejora = UpgradeSystem.MEJORAS[id]
	var personaje = personajes_por_nombre[mejora["personaje"]]

	if UpgradeSystem.comprar_mejora(id, personaje):
		actualizar_prestigio()
		refrescar_tienda()
	else:
		prestigio_label.text = "❌ Prestigio insuficiente"
		await get_tree().create_timer(1.5).timeout
		actualizar_prestigio()


func _on_comprar_objeto_pressed(id: String):
	if UpgradeSystem.comprar_objeto(id):
		actualizar_prestigio()
		refrescar_tienda()
	else:
		prestigio_label.text = "❌ Prestigio insuficiente"
		await get_tree().create_timer(1.5).timeout
		actualizar_prestigio()


func _on_btn_volber_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
