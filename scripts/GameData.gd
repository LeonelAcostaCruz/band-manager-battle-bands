extends Node

var prestigio: int = 0
var nivel_actual: int = 1
var mejoras_compradas: Array = []  # guarda los IDs de mejoras ya compradas
var ultimo_resultado_victoria: bool = true

func ganar_prestigio(cantidad: int):
	prestigio += cantidad

func gastar_prestigio(cantidad: int) -> bool:
	if prestigio >= cantidad:
		prestigio -= cantidad
		return true
	return false

func guardar():
	var save = {
		"prestigio": prestigio,
		"nivel_actual": nivel_actual,
		"mejoras_compradas": mejoras_compradas
	}
	var f = FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(save))

func cargar():
	if FileAccess.file_exists("user://save.json"):
		var f = FileAccess.open("user://save.json", FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		prestigio = data.get("prestigio", 0)
		nivel_actual = data.get("nivel_actual", 1)
		mejoras_compradas = data.get("mejoras_compradas", [])
