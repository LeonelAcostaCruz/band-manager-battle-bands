extends Node2D

var crow_storm = preload("res://resources/characters/crow_storm.tres")
var blaze_inferno = preload("res://resources/characters/blaze_inferno.tres")
var rex_thunder = preload("res://resources/characters/rex_thunder.tres")
var crash_doom = preload("res://resources/characters/crash_doom.tres")
var los_novatos = preload("res://resources/characters/los_novatos.tres")

var banda_jugador: Array = []
var banda_enemiga: Array = []
var turno_index: int = 0
var hype: int = 50
var turno_jugador: bool = true

@onready var hype_bar = $HUD/HypeBar
@onready var turno_label = $HUD/TurnoLabel
@onready var acciones_panel = $HUD/AccionesPanel
# Agrega estas variables @onready debajo de las que ya tienes:
@onready var hp_crow = $HUD/StatsPanel/StatsCrow/HPCrow
@onready var energia_crow = $HUD/StatsPanel/StatsCrow/EnergiaCrow
@onready var hp_blaze = $HUD/StatsPanel/StatsBlaze/HPBlaze
@onready var energia_blaze = $HUD/StatsPanel/StatsBlaze/EnergiaBlaze
@onready var hp_rex = $HUD/StatsPanel/StatsRex/HPRex
@onready var energia_rex = $HUD/StatsPanel/StatsRex/EnergiaRex
@onready var hp_crash = $HUD/StatsPanel/StatsCrash/HPCrash
@onready var energia_crash = $HUD/StatsPanel/StatsCrash/EnergiaCrash

@onready var nombre_crow = $HUD/StatsPanel/StatsCrow/NombreCrow
@onready var nombre_blaze = $HUD/StatsPanel/StatsBlaze/NombreBlaze
@onready var nombre_rex = $HUD/StatsPanel/StatsRex/NombreRex
@onready var nombre_crash = $HUD/StatsPanel/StatsCrash/NombreCrash

func _ready():
	banda_jugador = [crow_storm, blaze_inferno, rex_thunder, crash_doom]
	banda_enemiga = [los_novatos]
	
	
	for miembro in banda_jugador:
		miembro.hp_actual = miembro.hp_max
		miembro.energia_actual = miembro.energia_max
	for enemigo in banda_enemiga:
		enemigo.hp_actual = enemigo.hp_max
		enemigo.energia_actual = enemigo.energia_max
	
	hype_bar.max_value = 100
	hype_bar.value = hype
	
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
		turno_label.text = "¡" + atacante.nombre + " no tiene energía!"
		return
	
	atacante.energia_actual -= habilidad.costo_energia
	
	# Aplicar daño al enemigo
	var enemigo = banda_enemiga[0]
	match habilidad.tipo:
		"ataque":
			enemigo.hp_actual -= habilidad.dano_base + atacante.tecnica
		"critico":
			enemigo.hp_actual -= (habilidad.dano_base + atacante.tecnica) * 2
		"buff":
			atacante.carisma += 5
		"recuperar":
			atacante.energia_actual = min(atacante.energia_actual + 30, atacante.energia_max)
	
	hype = min(hype + 10, 100)
	hype_bar.value = hype
	turno_label.text = atacante.nombre + " usó " + habilidad.nombre + "!"
	
	await get_tree().create_timer(1.0).timeout
	verificar_batalla()
	actualizar_stats() 

func turno_enemigo():
	var enemigo = banda_enemiga[0]
	if enemigo.hp_actual <= 0:
		return
	
	# El enemigo ataca a un miembro aleatorio
	var objetivo = banda_jugador[randi() % banda_jugador.size()]
	var habilidad = enemigo.habilidades[randi() % enemigo.habilidades.size()]
	
	objetivo.hp_actual -= habilidad.dano_base
	turno_label.text = enemigo.nombre + " usó " + habilidad.nombre + " contra " + objetivo.nombre + "!"
	
	hype = max(hype - 5, 0)
	hype_bar.value = hype
	
	await get_tree().create_timer(1.0).timeout
	
	# Regresa al turno del jugador
	turno_jugador = true
	turno_index = (turno_index + 1) % banda_jugador.size()
	iniciar_turno()

func verificar_batalla():
	# ¿Ganó el jugador?
	if banda_enemiga[0].hp_actual <= 0:
		turno_label.text = "🎸 ¡VICTORIA! ¡Derrotaste a " + banda_enemiga[0].nombre + "!"
		acciones_panel.visible = false
		return
	
	# ¿Perdió el jugador?
	var todos_caidos = banda_jugador.all(func(m): return m.hp_actual <= 0)
	if todos_caidos:
		turno_label.text = "💀 DERROTA... regresa al garage."
		acciones_panel.visible = false
		return
	
	# Siguiente turno — ahora le toca al enemigo
	turno_jugador = false
	iniciar_turno()

func _on_btn_habilidad_1_pressed():
	usar_habilidad(0)

func _on_btn_habilidad_2_pressed():
	usar_habilidad(1)

func _on_btn_habilidad_3_pressed():
	usar_habilidad(2)

func _on_btn_recuperar_pressed():
	var personaje = banda_jugador[turno_index]
	personaje.energia_actual = min(personaje.energia_actual + 30, personaje.energia_max)
	turno_label.text = personaje.nombre + " recuperó energía!"
	await get_tree().create_timer(1.0).timeout
	turno_jugador = false
	verificar_batalla()  
	actualizar_stats() 	
	
func actualizar_stats():
	# HP máximo de cada personaje
	hp_crow.max_value = crow_storm.hp_max
	hp_crow.value = crow_storm.hp_actual
	energia_crow.max_value = crow_storm.energia_max
	energia_crow.value = crow_storm.energia_actual
	nombre_crow.text = crow_storm.nombre

	hp_blaze.max_value = blaze_inferno.hp_max
	hp_blaze.value = blaze_inferno.hp_actual
	energia_blaze.max_value = blaze_inferno.energia_max
	energia_blaze.value = blaze_inferno.energia_actual
	nombre_blaze.text = blaze_inferno.nombre

	hp_rex.max_value = rex_thunder.hp_max
	hp_rex.value = rex_thunder.hp_actual
	energia_rex.max_value = rex_thunder.energia_max
	energia_rex.value = rex_thunder.energia_actual
	nombre_rex.text = rex_thunder.nombre

	hp_crash.max_value = crash_doom.hp_max
	hp_crash.value = crash_doom.hp_actual
	energia_crash.max_value = crash_doom.energia_max
	energia_crash.value = crash_doom.energia_actual
	nombre_crash.text = crash_doom.nombre
	
	# Agregar esta línea:
	$HUD/AccionesPanel/BtnRecuperar.text = "Recuperar Energía"
	
	
