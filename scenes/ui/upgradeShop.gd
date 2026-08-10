extends Control

@onready var prestigio_label = $PrestigioLabel
@onready var mejoras_container = $ListaMejoras/Mejoras

var crow_storm = preload("res://resources/characters/crow_storm.tres")
var blaze_inferno = preload("res://resources/characters/blaze_inferno.tres")
var rex_thunder = preload("res://resources/characters/rex_thunder.tres")
var crash_doom = preload("res://resources/characters/crash_doom.tres")

var personajes_por_nombre = {}


func _ready():
	personajes_por_nombre = {
		"Crow Storm": crow_storm,
		"Blaze Inferno": blaze_inferno,
		"Rex Thunder": rex_thunder,
		"Crash Doom": crash_doom
	}
	actualizar_prestigio()
	generar_lista_mejoras()
	generar_lista_objetos()


func actualizar_prestigio():
	prestigio_label.text = "💰 Prestigio: " + str(GameData.prestigio)


func generar_lista_mejoras():
	# Limpia la lista antes de regenerar
	for child in mejoras_container.get_children():
		child.queue_free()

	for id in UpgradeSystem.MEJORAS:
		var mejora = UpgradeSystem.MEJORAS[id]
		var ya_comprada = id in GameData.mejoras_compradas

		var panel = HBoxContainer.new()
		mejoras_container.add_child(panel)

		var info = Label.new()
		info.custom_minimum_size = Vector2(400, 0)
		info.text = mejora["nombre"] + " (" + mejora["personaje"] + ")\n" + mejora["descripcion"]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		panel.add_child(info)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 50)
		if ya_comprada:
			btn.text = "✅ Comprada"
			btn.disabled = true
		else:
			btn.text = "💰 " + str(mejora["costo"])
			btn.pressed.connect(_on_comprar_pressed.bind(id))
		panel.add_child(btn)


# CAMBIO (nuevo): sección de objetos especiales consumibles. Se crea
# un contenedor "ListaObjetos" por código si no existe ya en la escena,
# así no necesitas tocar el árbol de nodos a mano.
var objetos_container: VBoxContainer = null

func generar_lista_objetos():
	if objetos_container == null:
		objetos_container = get_node_or_null("ListaObjetos/Objetos")

	if objetos_container == null:
		var titulo = Label.new()
		titulo.text = "🎒 OBJETOS ESPECIALES"
		titulo.add_theme_font_size_override("font_size", 22)
		titulo.add_theme_color_override("font_color", Color(1, 0.85, 0.2))

		var contenedor_raiz = VBoxContainer.new()
		contenedor_raiz.name = "ListaObjetos"
		contenedor_raiz.add_child(titulo)

		objetos_container = VBoxContainer.new()
		objetos_container.name = "Objetos"
		contenedor_raiz.add_child(objetos_container)

		add_child(contenedor_raiz)
		# Posición aproximada debajo de la lista de mejoras; ajústala
		# en el editor si tu layout es distinto.
		contenedor_raiz.position = Vector2(360, 420)

	for child in objetos_container.get_children():
		child.queue_free()

	for id in UpgradeSystem.OBJETOS:
		var objeto = UpgradeSystem.OBJETOS[id]
		var cantidad = GameData.inventario.get(id, 0)

		var panel = HBoxContainer.new()
		objetos_container.add_child(panel)

		var info = Label.new()
		info.custom_minimum_size = Vector2(400, 0)
		info.text = objeto["nombre"] + " (tienes: " + str(cantidad) + ")\n" + objeto["descripcion"]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		panel.add_child(info)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 50)
		btn.text = "💰 " + str(objeto["costo"])
		btn.pressed.connect(_on_comprar_objeto_pressed.bind(id))
		panel.add_child(btn)


func _on_comprar_pressed(id: String):
	var mejora = UpgradeSystem.MEJORAS[id]
	var personaje = personajes_por_nombre[mejora["personaje"]]

	if UpgradeSystem.comprar_mejora(id, personaje):
		actualizar_prestigio()
		generar_lista_mejoras()
	else:
		prestigio_label.text = "❌ Prestigio insuficiente"
		await get_tree().create_timer(1.5).timeout
		actualizar_prestigio()


func _on_comprar_objeto_pressed(id: String):
	if UpgradeSystem.comprar_objeto(id):
		actualizar_prestigio()
		generar_lista_objetos()
	else:
		prestigio_label.text = "❌ Prestigio insuficiente"
		await get_tree().create_timer(1.5).timeout
		actualizar_prestigio()


func _on_btn_volber_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
