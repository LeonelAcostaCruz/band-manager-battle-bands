extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_btn_jugar_pressed():
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")

func _on_btn_creditos_pressed():
	$Contenido/Botones/BtnCreditos.text = "Ruth Rodriguez & Daniel De la Cruz"
	await get_tree().create_timer(2.0).timeout
	$Contenido/Botones/BtnCreditos.text = "CREDITOS"

func _on_btn_tienda_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/UpgradeShop.tscn")
	

func _on_btn_salir_pressed():
	get_tree().quit()
