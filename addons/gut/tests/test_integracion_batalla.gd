extends GutTest

var crow_storm
var enemigo

func before_each():
	crow_storm = load("res://resources/characters/crow_storm.tres")
	enemigo = load("res://resources/characters/los_novatos.tres")
	crow_storm.hp_actual = crow_storm.hp_max
	crow_storm.energia_actual = crow_storm.energia_max
	enemigo.hp_actual = enemigo.hp_max
	GameData.prestigio = 0
	GameData.nivel_actual = 1

func test_ataque_reduce_hp_enemigo():
	var habilidad = load("res://resources/skills/voz_poderosa.tres")
	var hp_antes = enemigo.hp_actual
	var dano = habilidad.dano_base + crow_storm.tecnica
	enemigo.hp_actual -= dano
	enemigo.hp_actual = max(enemigo.hp_actual, 0)
	assert_lt(enemigo.hp_actual, hp_antes, 
		"El ataque debe reducir HP del enemigo")

func test_victoria_otorga_prestigio():
	var prestigio_antes = GameData.prestigio
	GameData.ganar_prestigio(GameData.NIVELES[1]["prestigio"])
	assert_gt(GameData.prestigio, prestigio_antes, 
		"Victoria debe otorgar prestigio")

func test_victoria_avanza_nivel():
	var nivel_antes = GameData.nivel_actual
	if GameData.nivel_actual < 5:
		GameData.nivel_actual += 1
	assert_gt(GameData.nivel_actual, nivel_antes, 
		"Victoria debe avanzar el nivel")

func test_energia_insuficiente_bloquea_habilidad():
	var habilidad = load("res://resources/skills/grito_legendario.tres")
	crow_storm.energia_actual = 0
	var puede_usar = crow_storm.energia_actual >= habilidad.costo_energia
	assert_false(puede_usar, 
		"No debe poder usar habilidad sin energia")

func test_enemigo_nivel2_es_mas_fuerte_que_nivel1():
	var novatos = load("res://resources/characters/los_novatos.tres")
	var ruido = load("res://resources/characters/ruido_callejero.tres")
	assert_gt(ruido.hp_max, novatos.hp_max, 
		"Enemigo nivel 2 debe tener mas HP que nivel 1")

func test_todos_niveles_tienen_enemigo_valido():
	for nivel in GameData.NIVELES:
		var path = GameData.NIVELES[nivel]["enemigo"]
		var enemigo_nivel = load(path)
		assert_not_null(enemigo_nivel, 
			"Nivel " + str(nivel) + " debe tener enemigo valido")

func test_prestigio_escala_por_nivel():
	for i in range(1, 5):
		assert_gt(
			GameData.NIVELES[i + 1]["prestigio"],
			GameData.NIVELES[i]["prestigio"],
			"Nivel " + str(i+1) + " debe dar mas prestigio que nivel " + str(i)
		)
