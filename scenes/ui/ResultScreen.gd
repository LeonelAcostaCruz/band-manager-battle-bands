extends Control

@onready var resultado_label = $Contenido/ResultadoLabel
@onready var mensaje_label = $Contenido/MensajeLabel

# CAMBIO (nuevo): referencia al botón para poder cambiarle el texto.
@onready var btn_reintentar = $Contenido/Botones/BtnReintentar


func _ready():
	if GameData.ultimo_resultado_victoria:
		resultado_label.text = "VICTORIA!"
		resultado_label.modulate = Color(0.3, 1, 0.3)
		mensaje_label.text = "+50 Prestigio ganado! La banda sigue creciendo."
		if btn_reintentar != null:
			btn_reintentar.text = "CONTINUAR"
	else:
		resultado_label.text = "DERROTA"
		resultado_label.modulate = Color(1, 0.3, 0.3)
		mensaje_label.text = "La banda regresa al garage... a entrenar mas!"
		if btn_reintentar != null:
			btn_reintentar.text = "REINTENTAR"


func _on_btn_reintentar_pressed():
	# CAMBIO: mismo destino en ambos casos. En victoria, BattleScene.gd
	# ya incrementó GameData.nivel_actual antes de llegar aquí, así que
	# recargar la escena de batalla automáticamente continúa al
	# siguiente nivel. En derrota, nivel_actual no cambió, así que
	# recarga el mismo nivel (es un reintento real).
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")


func _on_btn_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
