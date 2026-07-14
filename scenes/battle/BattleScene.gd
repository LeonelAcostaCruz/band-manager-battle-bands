extends Node2D

var crow_storm = preload("res://resources/characters/crow_storm.tres")
var blaze_inferno = preload("res://resources/characters/blaze_inferno.tres")
var rex_thunder = preload("res://resources/characters/rex_thunder.tres")
var crash_doom = preload("res://resources/characters/crash_doom.tres")

var banda_jugador: Array = []
var banda_enemiga: Array = []
var turno_index: int = 0
var hype: int = 50
var turno_jugador: bool = true

@onready var hype_bar = $HUD/HypeBar
@onready var turno_label = $HUD/TurnoLabel
@onready var acciones_panel = $HUD/AccionesPanel

func _ready():
	# Restaurar stats del jugador
	banda_jugador = [crow_storm, blaze_inferno, rex_thunder, crash_doom]
	for miembro in banda_jugador:
		miembro.hp_actual = miembro.hp_max
		miembro.energia_actual = miembro.energia_max

	# Cargar enemigo según nivel actual
	var nivel_data = GameData.NIVELES[GameData.nivel_actual]
	var enemigo = load(nivel_data["enemigo"])
	enemigo.hp_actual = enemigo.hp_max
	enemigo.energia_actual = enemigo.energia_max
	banda_enemiga = [enemigo]

	hype_bar.max_value = 100
	hype_bar.value = hype

	turno_label.text = "Nivel " + str(GameData.nivel_actual) + ": " + nivel_data["nombre"]
	await get_tree().create_timer(1.5).timeout
	iniciar_turno()
	actualizar_stats()

func iniciar_turno():
	if turno_jugador:
		var personaje = banda_jugador[turno_index]
		turno_label.text = "Turno de: " + personaje.nombre
		acciones_panel.visible = true
		actualizar_botones(personaje)
	else:
		acciones_panel.visible = false
		turno_label.text = "Turno enemigo..."
		await get_tree().create_timer(1.5).timeout
		turno_enemigo()

func actualizar_botones(personaje: CharacterData):
	var botones = acciones_panel.get_children()
	for i in range(personaje.habilidades.size()):
		if i < botones.size():
			botones[i].text = personaje.habilidades[i].nombre

func usar_habilidad(indice: int):
	var atacante = banda_jugador[turno_index]
	var habilidad = atacante.habilidades[indice]

	if atacante.energia_actual < habilidad.costo_energia:
		turno_label.text = "!" + atacante.nombre + " no tiene energia!"
		return

	atacante.energia_actual -= habilidad.costo_energia

	var enemigo = banda_enemiga[0]
	match habilidad.tipo:
		"ataque":
			enemigo.hp_actual -= habilidad.dano_base + atacante.tecnica
		"critico":
			enemigo.hp_actual -= (habilidad.dano_base + atacante.tecnica) * 2
		"buff":
			atacante.carisma += 5
		"recuperar":
			atacante.energia_actual = min(
				atacante.energia_actual + 30,
				atacante.energia_max
			)

	enemigo.hp_actual = max(enemigo.hp_actual, 0)
	hype = min(hype + 10, 100)
	hype_bar.value = hype
	turno_label.text = atacante.nombre + " uso " + habilidad.nombre + "!"
	actualizar_stats()

	await get_tree().create_timer(1.0).timeout
	verificar_batalla()

func turno_enemigo():
	var enemigo = banda_enemiga[0]
	if enemigo.hp_actual <= 0:
		return

	var objetivo = banda_jugador[randi() % banda_jugador.size()]
	var habilidad = enemigo.habilidades[randi() % enemigo.habilidades.size()]

	objetivo.hp_actual -= habilidad.dano_base
	objetivo.hp_actual = max(objetivo.hp_actual, 0)
	turno_label.text = enemigo.nombre + " uso " + habilidad.nombre + "!"

	hype = max(hype - 5, 0)
	hype_bar.value = hype
	actualizar_stats()

	await get_tree().create_timer(1.0).timeout
	turno_jugador = true
	turno_index = (turno_index + 1) % banda_jugador.size()
	iniciar_turno()

func verificar_batalla():
	if banda_enemiga[0].hp_actual <= 0:
		var nivel_data = GameData.NIVELES[GameData.nivel_actual]
		turno_label.text = "VICTORIA! Derrotaste a " + banda_enemiga[0].nombre + "!"
		acciones_panel.visible = false
		GameData.ultimo_resultado_victoria = true
		GameData.ganar_prestigio(nivel_data["prestigio"])
		# Desbloquea el siguiente nivel
		if GameData.nivel_actual < 5:
			GameData.nivel_actual += 1
		GameData.guardar()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/ResultScreen.tscn")
		return

	var todos_caidos = banda_jugador.all(func(m): return m.hp_actual <= 0)
	if todos_caidos:
		turno_label.text = "DERROTA... regresa al garage."
		acciones_panel.visible = false
		GameData.ultimo_resultado_victoria = false
		GameData.guardar()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/ResultScreen.tscn")
		return

	turno_jugador = false
	iniciar_turno()

func actualizar_stats():
	var hp_crow = $HUD/StatsPanel/StatsCrow/HPCrow
	var energia_crow = $HUD/StatsPanel/StatsCrow/EnergiaCrow
	var hp_blaze = $HUD/StatsPanel/StatsBlaze/HPBlaze
	var energia_blaze = $HUD/StatsPanel/StatsBlaze/EnergiaBlaze
	var hp_rex = $HUD/StatsPanel/StatsRex/HPRex
	var energia_rex = $HUD/StatsPanel/StatsRex/EnergiaRex
	var hp_crash = $HUD/StatsPanel/StatsCrash/HPCrash
	var energia_crash = $HUD/StatsPanel/StatsCrash/EnergiaCrash

	hp_crow.max_value = crow_storm.hp_max
	hp_crow.value = crow_storm.hp_actual
	energia_crow.max_value = crow_storm.energia_max
	energia_crow.value = crow_storm.energia_actual

	hp_blaze.max_value = blaze_inferno.hp_max
	hp_blaze.value = blaze_inferno.hp_actual
	energia_blaze.max_value = blaze_inferno.energia_max
	energia_blaze.value = blaze_inferno.energia_actual

	hp_rex.max_value = rex_thunder.hp_max
	hp_rex.value = rex_thunder.hp_actual
	energia_rex.max_value = rex_thunder.energia_max
	energia_rex.value = rex_thunder.energia_actual

	hp_crash.max_value = crash_doom.hp_max
	hp_crash.value = crash_doom.hp_actual
	energia_crash.max_value = crash_doom.energia_max
	energia_crash.value = crash_doom.energia_actual

func _on_btn_habilidad_1_pressed():
	usar_habilidad(0)

func _on_btn_habilidad_2_pressed():
	usar_habilidad(1)

func _on_btn_habilidad_3_pressed():
	usar_habilidad(2)

func _on_btn_recuperar_pressed():
	var personaje = banda_jugador[turno_index]
	personaje.energia_actual = min(
		personaje.energia_actual + 30,
		personaje.energia_max
	)
	turno_label.text = personaje.nombre + " recupero energia!"
	actualizar_stats()
	await get_tree().create_timer(1.0).timeout
	turno_jugador = false
	verificar_batalla()
