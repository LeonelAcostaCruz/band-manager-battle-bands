extends Node

var prestigio: int = 0
var nivel_actual: int = 1
var mejoras_compradas: Array = []
var ultimo_resultado_victoria: bool = true

const NIVELES = {
	1: {"nombre": "Garage",               "enemigo": "res://resources/characters/los_novatos.tres",      "prestigio": 50},
	2: {"nombre": "Bar Local",            "enemigo": "res://resources/characters/ruido_callejero.tres",  "prestigio": 75},
	3: {"nombre": "Escuela de Arte",      "enemigo": "res://resources/characters/tinta_negra.tres",      "prestigio": 100},
	4: {"nombre": "Callejon Underground", "enemigo": "res://resources/characters/soul_breaker.tres",     "prestigio": 150},
	5: {"nombre": "Club Underground",     "enemigo": "res://resources/characters/metal_excesivo.tres",   "prestigio": 200},
}

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
