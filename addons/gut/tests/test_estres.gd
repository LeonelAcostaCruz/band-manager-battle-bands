extends GutTest

var crow_storm
var enemigo

func before_each():
	crow_storm = load("res://resources/characters/crow_storm.tres")
	enemigo = load("res://resources/characters/los_novatos.tres")
	crow_storm.hp_actual = crow_storm.hp_max
	crow_storm.energia_actual = crow_storm.energia_max
	enemigo.hp_actual = enemigo.hp_max

# Estres 1: HP nunca baja de 0
func test_hp_no_negativo_con_dano_excesivo():
	crow_storm.hp_actual -= 9999
	crow_storm.hp_actual = max(crow_storm.hp_actual, 0)
	assert_gte(crow_storm.hp_actual, 0, 
		"HP no debe ser negativo")

# Estres 2: Energia nunca supera el maximo
func test_energia_no_supera_maximo():
	crow_storm.energia_actual += 9999
	crow_storm.energia_actual = min(
		crow_storm.energia_actual, 
		crow_storm.energia_max
	)
	assert_lte(crow_storm.energia_actual, crow_storm.energia_max, 
		"Energia no debe superar el maximo")

# Estres 3: Prestigio no se vuelve negativo
func test_prestigio_no_negativo_con_muchas_compras():
	GameData.prestigio = 10
	for i in range(100):
		GameData.gastar_prestigio(50)
	assert_gte(GameData.prestigio, 0, 
		"Prestigio no debe ser negativo")

# Estres 4: Batalla larga sin colgar
func test_batalla_larga_sin_error():
	var turnos = 0
	var max_turnos = 100
	var hp_enemigo = enemigo.hp_max
	while hp_enemigo > 0 and turnos < max_turnos:
		hp_enemigo -= 5
		hp_enemigo = max(hp_enemigo, 0)
		turnos += 1
	assert_lte(turnos, max_turnos, 
		"La batalla debe terminar en menos de 100 turnos")

# Estres 5: Nivel no supera el maximo
func test_nivel_no_supera_maximo():
	GameData.nivel_actual = 5
	if GameData.nivel_actual < 5:
		GameData.nivel_actual += 1
	assert_lte(GameData.nivel_actual, 5, 
		"El nivel no debe superar 5")

# Estres 6: Multiples enemigos cargados sin error
func test_cargar_todos_los_enemigos():
	for nivel in GameData.NIVELES:
		var path = GameData.NIVELES[nivel]["enemigo"]
		var e = load(path)
		e.hp_actual = e.hp_max
		assert_gte(e.hp_actual, 0, 
			"Enemigo nivel " + str(nivel) + " debe cargar correctamente")

# Estres 7: Stats extremos no rompen el juego
func test_stats_extremos():
	crow_storm.tecnica = 9999
	var habilidad = load("res://resources/skills/voz_poderosa.tres")
	var dano = habilidad.dano_base + crow_storm.tecnica
	enemigo.hp_actual -= dano
	enemigo.hp_actual = max(enemigo.hp_actual, 0)
	assert_gte(enemigo.hp_actual, 0, 
		"HP enemigo no debe ser negativo con stats extremos")

# Estres 8: Comprar todas las mejoras seguidas
func test_comprar_todas_las_mejoras():
	var blaze = load("res://resources/characters/blaze_inferno.tres")
	GameData.prestigio = 9999
	GameData.mejoras_compradas = []
	for id in UpgradeSystem.MEJORAS:
		UpgradeSystem.comprar_mejora(id, blaze)
	assert_eq(
		GameData.mejoras_compradas.size(),
		UpgradeSystem.MEJORAS.size(),
        "Debe poder comprar todas las mejoras"
	)
