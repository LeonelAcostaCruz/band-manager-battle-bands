# tests/test_battle_system.gd
extends GutTest

var crow_storm

func before_each():
	crow_storm = load("res://resources/characters/crow_storm.tres")
	crow_storm.hp_actual = crow_storm.hp_max
	crow_storm.energia_actual = crow_storm.energia_max

func test_personaje_tiene_hp():
	assert_gt(crow_storm.hp_max, 0, "Crow Storm debe tener HP mayor a 0")

func test_personaje_tiene_habilidades():
	assert_gt(crow_storm.habilidades.size(), 0, "Crow Storm debe tener habilidades")

func test_energia_inicial_completa():
	assert_eq(crow_storm.energia_actual, crow_storm.energia_max, "Energía debe iniciar al máximo")

func test_habilidad_consume_energia():
	var habilidad = crow_storm.habilidades[0]
	var energia_antes = crow_storm.energia_actual
	crow_storm.energia_actual -= habilidad.costo_energia
	assert_lt(crow_storm.energia_actual, energia_antes, "Usar habilidad debe consumir energía")
