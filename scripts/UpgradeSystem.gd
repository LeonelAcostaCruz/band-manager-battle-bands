extends Node
const MEJORAS = {
	"guitarra_distortion_x": {
		"nombre": "Guitarra Distortion X",
		"descripcion": "+20% de daño musical",
		"costo": 50,
		"personaje": "Blaze Inferno",
		"efecto": {"tecnica": 5}
	},
	"amplificador_overdrive": {
		"nombre": "Amplificador Overdrive Pro",
		"descripcion": "+15% de reacción del público",
		"costo": 40,
		"personaje": "Crow Storm",
		"efecto": {"carisma": 5}
	},
	"baquetas_trueno": {
		"nombre": "Baquetas del Trueno",
		"descripcion": "Aumenta resistencia del baterista",
		"costo": 80,
		"personaje": "Crash Doom",
		"efecto": {"resistencia": 8}
	},
	"pua_acero_infernal": {
		"nombre": "Púa de Acero Infernal",
		"descripcion": "Ataques críticos más fuertes",
		"costo": 80,
		"personaje": "Blaze Inferno",
		"efecto": {"tecnica": 8}
	},
	"cuerdas_resonantes": {
		"nombre": "Cuerdas Resonantes",
		"descripcion": "Mejora la estabilidad del bajista",
		"costo": 60,
		"personaje": "Rex Thunder",
		"efecto": {"ritmo": 6}
	}
}

func comprar_mejora(id: String, personaje: CharacterData) -> bool:
	if not MEJORAS.has(id):
		return false
	if id in GameData.mejoras_compradas:
		return false  # ya comprada
	
	var mejora = MEJORAS[id]
	if not GameData.gastar_prestigio(mejora["costo"]):
		return false  # no hay suficiente prestigio
	
	aplicar_efecto(mejora["efecto"], personaje)
	GameData.mejoras_compradas.append(id)
	GameData.guardar()
	return true

func aplicar_efecto(efecto: Dictionary, personaje: CharacterData):
	for stat in efecto:
		match stat:
			"tecnica":
				personaje.tecnica += efecto[stat]
			"carisma":
				personaje.carisma += efecto[stat]
			"ritmo":
				personaje.ritmo += efecto[stat]
			"resistencia":
				personaje.resistencia += efecto[stat]
			"velocidad":
				personaje.velocidad += efecto[stat]
