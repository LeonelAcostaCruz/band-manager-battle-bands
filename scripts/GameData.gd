extends Node

var prestigio: int = 0
var nivel_actual: int = 1
var mejoras_compradas: Array = []
var ultimo_resultado_victoria: bool = true

# CAMBIO (nuevo): inventario de objetos especiales consumibles.
# Clave = id del objeto (ej. "vida_extra"), valor = cantidad que tienes.
var inventario: Dictionary = {}

const NIVELES = {
	1: {"nombre": "Garage",               "enemigo": "res://resources/characters/los_novatos.tres",      "prestigio": 50,  "fondo": "res://assets/sprites/backgrounds/bg_garage.jpg", "musica": "res://assets/audio/music/nivel1.mp3"},
	2: {"nombre": "Bar Local",            "enemigo": "res://resources/characters/ruido_callejero.tres",  "prestigio": 75,  "fondo": "res://assets/sprites/backgrounds/bg_bar_local.jpg", "musica": "res://assets/audio/music/nivel2.mp3"},
	3: {"nombre": "Escuela de Arte",      "enemigo": "res://resources/characters/tinta_negra.tres",      "prestigio": 100, "fondo": "res://assets/sprites/backgrounds/bg_escuela_arte.jpg", "musica": "res://assets/audio/music/nivel3.mp3"},
	4: {"nombre": "Callejon Underground", "enemigo": "res://resources/characters/soul_breaker.tres",     "prestigio": 150, "fondo": "res://assets/sprites/backgrounds/bg_callejon.jpg", "musica": "res://assets/audio/music/nivel4.mp3", "jefe": true},
	5: {"nombre": "Club Underground",     "enemigo": "res://resources/characters/metal_excesivo.tres",   "prestigio": 200, "fondo": "res://assets/sprites/backgrounds/bg_club_underground.jpg", "musica": "res://assets/audio/music/nivel5.mp3", "jefe": true},
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
		"mejoras_compradas": mejoras_compradas,
		"inventario": inventario,
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
		inventario = data.get("inventario", {})
