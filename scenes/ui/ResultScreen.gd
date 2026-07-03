extends Control

@onready var resultado_label = $Contenido/ResultadoLabel
@onready var mensaje_label = $Contenido/MensajeLabel

func _ready():
	if GameData.ultimo_resultado_victoria:
		resultado_label.text = "VICTORIA!"
		resultado_label.modulate = Color(0.3, 1, 0.3)
		mensaje_label.text = "+50 Prestigio ganado! La banda sigue creciendo."
	else:
		resultado_label.text = "DERROTA"
		resultado_label.modulate = Color(1, 0.3, 0.3)
		mensaje_label.text = "La banda regresa al garage... a entrenar mas!"

func _on_btn_reintentar_pressed():
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")

func _on_btn_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
