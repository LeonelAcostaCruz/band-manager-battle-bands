extends Control

@onready var prestigio_label = $Contenido/PrestigioLabel
@onready var niveles = $Contenido/Niveles

func _ready():
	GameData.cargar()
	prestigio_label.text = "Prestigio: " + str(GameData.prestigio)
	actualizar_botones()

func actualizar_botones():
	var botones = niveles.get_children()
	for i in range(botones.size()):
		var nivel = i + 1
		if nivel > GameData.nivel_actual:
			botones[i].disabled = true
			botones[i].text = botones[i].text + "  [Bloqueado]"
		elif nivel < GameData.nivel_actual:
			botones[i].text = botones[i].text + "  ✓"

func ir_a_nivel(nivel: int):
	GameData.nivel_actual = nivel
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")

func _on_btn_nivel_1_pressed():
	ir_a_nivel(1)

func _on_btn_nivel_2_pressed():
	ir_a_nivel(2)

func _on_btn_nivel_3_pressed():
	ir_a_nivel(3)

func _on_btn_nivel_4_pressed():
	ir_a_nivel(4)

func _on_btn_nivel_5_pressed():
	ir_a_nivel(5)

func _on_btn_volber_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
