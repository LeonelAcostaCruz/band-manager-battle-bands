extends GutTest

var blaze

func before_each():
	blaze = load("res://resources/characters/blaze_inferno.tres")
	GameData.prestigio = 200
	GameData.mejoras_compradas = []

func test_compra_mejora_aumenta_stats():
	var tecnica_antes = blaze.tecnica
	UpgradeSystem.comprar_mejora("guitarra_distortion_x", blaze)
	assert_gt(blaze.tecnica, tecnica_antes, 
		"Comprar mejora debe aumentar tecnica")

func test_compra_reduce_prestigio():
	var prestigio_antes = GameData.prestigio
	UpgradeSystem.comprar_mejora("guitarra_distortion_x", blaze)
	assert_lt(GameData.prestigio, prestigio_antes, 
		"Compra debe reducir prestigio")

func test_no_comprar_dos_veces():
	UpgradeSystem.comprar_mejora("guitarra_distortion_x", blaze)
	var segundo = UpgradeSystem.comprar_mejora("guitarra_distortion_x", blaze)
	assert_false(segundo, 
		"No debe poder comprar la misma mejora dos veces")

func test_no_comprar_sin_prestigio():
	GameData.prestigio = 0
	var resultado = UpgradeSystem.comprar_mejora("guitarra_distortion_x", blaze)
	assert_false(resultado, 
		"No debe poder comprar sin prestigio suficiente")

func test_mejora_registrada_en_gamedata():
	UpgradeSystem.comprar_mejora("guitarra_distortion_x", blaze)
	assert_has(GameData.mejoras_compradas, "guitarra_distortion_x",
		"Mejora debe quedar registrada en GameData")
