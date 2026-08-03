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

func _on_btn_volver_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_btn_volber_pressed() -> void:
	pass # Replace with function body.
