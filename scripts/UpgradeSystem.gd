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
				
# ============================================================
# AGREGAR a tu UpgradeSystem.gd (no reemplaza nada, solo se suma
# a lo que ya tienes: MEJORAS, comprar_mejora, aplicar_efecto).
# ============================================================

# CAMBIO (nuevo): objetos especiales consumibles (requisito de la
# rúbrica: "2 objetos especiales - vidas, armas, etc."). A diferencia
# de MEJORAS (se compran una vez, son permanentes), estos se compran
# varias veces y se consumen al usarse en batalla.
const OBJETOS = {
	"vida_extra": {
		"nombre": "Vida Extra",
		"descripcion": "Revive a un integrante caído (40% HP), o cura 40 HP si nadie cayó.",
		"costo": 60,
		"tipo": "revivir",
	},
	"carga_adrenalina": {
		"nombre": "Carga de Adrenalina",
		"descripcion": "Arma especial: energía al máximo y una ráfaga de daño instantáneo al rival.",
		"costo": 70,
		"tipo": "adrenalina",
	},
}

# Compra una unidad de un objeto (se puede comprar varias veces).
func comprar_objeto(id: String) -> bool:
	if not OBJETOS.has(id):
		return false

	var objeto = OBJETOS[id]
	if not GameData.gastar_prestigio(objeto["costo"]):
		return false  # no hay suficiente prestigio

	if not GameData.inventario.has(id):
		GameData.inventario[id] = 0
	GameData.inventario[id] += 1
	GameData.guardar()
	return true
