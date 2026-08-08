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
var turno_indicador: Node = null
var pulso_tweens: Dictionary = {}

@onready var hype_bar = $HUD/HypeBar
@onready var turno_label = $HUD/TurnoLabel
@onready var acciones_panel = $HUD/AccionesPanel
@onready var camera: Camera2D = get_node_or_null("Camera2D")

# Nodos de sprites de la banda jugadora
@onready var sprite_crow = $BandaJugador/CrowStorm/CrowStorm
@onready var sprite_blaze = $BandaJugador/BlazeInferno/BlazeInferno
@onready var sprite_rex = $BandaJugador/RexThunder/RexThunder
@onready var sprite_crash = $BandaJugador/CrashDoom/CrashDoom
@onready var sprite_enemigo = $BandaEnemiga/Enemigo1/Enemigo1

# Referencias a las barras de stats (para poder animarlas con tween)
@onready var hp_crow = $HUD/StatsPanel/StatsCrow/HPCrow
@onready var energia_crow = $HUD/StatsPanel/StatsCrow/EnergiaCrow
@onready var hp_blaze = $HUD/StatsPanel/StatsBlaze/HPBlaze
@onready var energia_blaze = $HUD/StatsPanel/StatsBlaze/EnergiaBlaze
@onready var hp_rex = $HUD/StatsPanel/StatsRex/HPRex
@onready var energia_rex = $HUD/StatsPanel/StatsRex/EnergiaRex
@onready var hp_crash = $HUD/StatsPanel/StatsCrash/HPCrash
@onready var energia_crash = $HUD/StatsPanel/StatsCrash/EnergiaCrash


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

	# Iniciar animaciones idle de la banda
	reproducir_idle()

	# Cargar fondo según nivel
	var fondo_sprite = $Fondo
	if ResourceLoader.exists(nivel_data["fondo"]):
		fondo_sprite.texture = load(nivel_data["fondo"])
		var viewport_size = get_viewport().get_visible_rect().size
		var texture_size = fondo_sprite.texture.get_size()
		fondo_sprite.scale = Vector2(
			viewport_size.x / texture_size.x,
			viewport_size.y / texture_size.y
		)

	# Cargar sprite del enemigo dinámicamente
	if enemigo.sprite_path != "":
		sprite_enemigo.texture = load(enemigo.sprite_path)

	hype_bar.max_value = 100
	hype_bar.value = hype
	$HUD/AccionesPanel/BtnRecuperar.text = "Recuperar Energia"
	turno_label.text = "Nivel " + str(GameData.nivel_actual) + ": " + nivel_data["nombre"]

	await get_tree().create_timer(1.5).timeout
	iniciar_turno()
	actualizar_stats()


# Reproduce idle solo en los sprites que son AnimatedSprite2D
func reproducir_idle():
	for sprite in [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]:
		if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")


# Reproduce una animación y regresa a idle (solo si es AnimatedSprite2D)
func reproducir_anim(sprite: Node, anim: String, duracion: float = 0.4):
	if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			if sprite.sprite_frames.get_animation_loop(anim):
				await get_tree().create_timer(duracion).timeout
			else:
				await sprite.animation_finished
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")


func iniciar_turno():
	actualizar_indicador_turno()
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

	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_atacante = sprites_banda[turno_index]
	var enemigo = banda_enemiga[0]

	match habilidad.tipo:
		"ataque":
			var cantidad = habilidad.dano_base + atacante.tecnica
			enemigo.hp_actual -= cantidad
			reproducir_anim(sprite_atacante, "ataque", 0.4)
			trail_durante_animacion(sprite_atacante, 0.35)
			await hit_stop(0.05, 0.05)
			flash_dano(sprite_enemigo, Color(1, 0, 0, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.3, 0.1))
			spawn_damage_number(sprite_enemigo, "-" + str(cantidad), Color(1, 0.3, 0.1))
			squash_stretch(sprite_enemigo)
			knockback(sprite_enemigo, Vector2.RIGHT)
			shake_camera(0.25, 6.0)
		"critico":
			var cantidad = (habilidad.dano_base + atacante.tecnica) * 2
			enemigo.hp_actual -= cantidad
			reproducir_anim(sprite_atacante, "ataque", 0.4)
			trail_durante_animacion(sprite_atacante, 0.35, Color(1, 0.85, 0.3, 0.4))
			await hit_stop(0.09, 0.03)
			flash_dano(sprite_enemigo, Color(1, 0.5, 0, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.85, 0.1))
			spawn_damage_number(sprite_enemigo, "-" + str(cantidad) + "!", Color(1, 0.85, 0.1))
			squash_stretch(sprite_enemigo)
			knockback(sprite_enemigo, Vector2.RIGHT)
			shake_camera(0.4, 12.0)
			zoom_punch(0.35, 0.18)
			mostrar_vineta(0.35, 0.45)
		"buff":
			atacante.carisma += 5
			reproducir_anim(sprite_atacante, "hype", 0.4)
			flash_dano(sprite_atacante, Color(0, 1, 0, 1))
			spawn_impact_particles(sprite_atacante, Color(0.3, 1, 0.4))
			spawn_damage_number(sprite_atacante, "+5 carisma", Color(0.3, 1, 0.4))
			squash_stretch(sprite_atacante)
		"recuperar":
			atacante.energia_actual = min(
				atacante.energia_actual + 30,
				atacante.energia_max
			)
			flash_dano(sprite_atacante, Color(0, 0.5, 1, 1))
			spawn_impact_particles(sprite_atacante, Color(0.2, 0.6, 1))
			spawn_damage_number(sprite_atacante, "+30 energia", Color(0.2, 0.6, 1))

	enemigo.hp_actual = max(enemigo.hp_actual, 0)
	hype = min(hype + 10, 100)
	tween_bar(hype_bar, hype)
	turno_label.text = atacante.nombre + " uso " + habilidad.nombre + "!"
	actualizar_stats()

	await get_tree().create_timer(1.0).timeout
	verificar_batalla()


func turno_enemigo():
	var enemigo = banda_enemiga[0]
	if enemigo.hp_actual <= 0:
		return

	var objetivo_index = randi() % banda_jugador.size()
	var objetivo = banda_jugador[objetivo_index]
	var habilidad = enemigo.habilidades[randi() % enemigo.habilidades.size()]
	var cantidad = habilidad.dano_base

	turno_label.text = enemigo.nombre + " se prepara..."
	await telegraph_ataque(sprite_enemigo)

	objetivo.hp_actual -= cantidad
	objetivo.hp_actual = max(objetivo.hp_actual, 0)
	turno_label.text = enemigo.nombre + " uso " + habilidad.nombre + "!"

	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_objetivo = sprites_banda[objetivo_index]

	reproducir_anim(sprite_objetivo, "dano", 0.4)
	await hit_stop(0.05, 0.05)
	flash_dano(sprite_objetivo, Color(1, 0, 0, 1))
	spawn_impact_particles(sprite_objetivo, Color(1, 0.2, 0.2))
	spawn_damage_number(sprite_objetivo, "-" + str(cantidad), Color(1, 0.3, 0.3))
	squash_stretch(sprite_objetivo)
	knockback(sprite_objetivo, Vector2.LEFT)
	shake_camera(0.25, 6.0)

	hype = max(hype - 5, 0)
	tween_bar(hype_bar, hype)
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
		for sprite in [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]:
			spawn_confetti(sprite)
		GameData.ultimo_resultado_victoria = true
		GameData.ganar_prestigio(nivel_data["prestigio"])
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
		mostrar_vineta(0.8, 0.7)
		GameData.ultimo_resultado_victoria = false
		GameData.guardar()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/ResultScreen.tscn")
		return

	turno_jugador = false
	iniciar_turno()


# CAMBIO: ahora usa tween_bar() en vez de asignar .value directo,
# para que las barras se muevan suavemente en vez de saltar.
func actualizar_stats():
	tween_bar(hp_crow, crow_storm.hp_actual)
	hp_crow.max_value = crow_storm.hp_max
	tween_bar(energia_crow, crow_storm.energia_actual)
	energia_crow.max_value = crow_storm.energia_max

	tween_bar(hp_blaze, blaze_inferno.hp_actual)
	hp_blaze.max_value = blaze_inferno.hp_max
	tween_bar(energia_blaze, blaze_inferno.energia_actual)
	energia_blaze.max_value = blaze_inferno.energia_max

	tween_bar(hp_rex, rex_thunder.hp_actual)
	hp_rex.max_value = rex_thunder.hp_max
	tween_bar(energia_rex, rex_thunder.energia_actual)
	energia_rex.max_value = rex_thunder.energia_max

	tween_bar(hp_crash, crash_doom.hp_actual)
	hp_crash.max_value = crash_doom.hp_max
	tween_bar(energia_crash, crash_doom.energia_actual)
	energia_crash.max_value = crash_doom.energia_max

	actualizar_pulso_hp()


func _on_btn_habilidad_1_pressed():
	usar_habilidad(0)


func _on_btn_habilidad_2_pressed():
	usar_habilidad(1)


func _on_btn_habilidad_3_pressed():
	usar_habilidad(2)


func _on_btn_recuperar_pressed():
	var personaje = banda_jugador[turno_index]
	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_actual = sprites_banda[turno_index]

	personaje.energia_actual = min(
		personaje.energia_actual + 30,
		personaje.energia_max
	)
	turno_label.text = personaje.nombre + " recupero energia!"
	reproducir_anim(sprite_actual, "recuperar", 0.4)
	flash_dano(sprite_actual, Color(0, 0.5, 1, 1))
	spawn_impact_particles(sprite_actual, Color(0.2, 0.6, 1))
	spawn_damage_number(sprite_actual, "+30 energia", Color(0.2, 0.6, 1))
	actualizar_stats()

	await get_tree().create_timer(1.0).timeout
	turno_jugador = false
	verificar_batalla()


func flash_dano(sprite: Node, color: Color = Color(1, 0, 0, 1)):
	if sprite == null:
		return
	sprite.modulate = color
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1, 1)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = color
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1, 1)


func spawn_impact_particles(target: Node2D, color: Color = Color(1, 0.3, 0.1)):
	if target == null:
		return

	var particles = GPUParticles2D.new()
	var particle_material = ParticleProcessMaterial.new()

	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 4.0
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 60.0
	particle_material.gravity = Vector3(0, 260, 0)
	particle_material.initial_velocity_min = 90.0
	particle_material.initial_velocity_max = 180.0
	particle_material.scale_min = 0.5
	particle_material.scale_max = 1.2
	particle_material.color = color

	particles.process_material = particle_material
	particles.amount = 20
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = false

	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	particles.texture = ImageTexture.create_from_image(img)

	target.add_child(particles)
	particles.position = Vector2.ZERO
	particles.top_level = false
	particles.emitting = true

	particles.finished.connect(func(): particles.queue_free())


func shake_camera(duration: float = 0.3, strength: float = 8.0):
	if camera == null:
		return

	var original_offset = camera.offset
	var elapsed = 0.0
	while elapsed < duration:
		camera.offset = original_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().create_timer(0.03).timeout
		elapsed += 0.03

	camera.offset = original_offset


# CAMBIO (nuevo): hit-stop / freeze frame. Congela el juego por
# 'duration' segundos reales (ignorando el time_scale que nosotros
# mismos bajamos), usando Engine.time_scale. Le da mucho más peso
# al golpe justo antes de que se vea el shake/partículas.
func hit_stop(duration: float = 0.06, escala_tiempo: float = 0.05):
	Engine.time_scale = escala_tiempo
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# CAMBIO (nuevo): compresión/estiramiento rápido del sprite al recibir
# el golpe, efecto clásico de "juice" en juegos de pelea.
func squash_stretch(sprite: Node2D):
	if sprite == null:
		return
	var original_scale = sprite.scale
	var tween = create_tween()
	tween.tween_property(sprite, "scale", original_scale * Vector2(1.25, 0.75), 0.06)
	tween.tween_property(sprite, "scale", original_scale, 0.12)


# CAMBIO (nuevo): pequeño retroceso al recibir el golpe, y vuelta
# suave a la posición original.
func knockback(sprite: Node2D, direccion: Vector2):
	if sprite == null:
		return
	var original_pos = sprite.position
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_pos + direccion * 12, 0.05)
	tween.tween_property(sprite, "position", original_pos, 0.15)


# CAMBIO (nuevo): número de daño/curación flotante que sube y se
# desvanece, encima del personaje/enemigo afectado.

# CAMBIO: ahora se dibuja en su propia CanvasLayer (capa 60, por encima
# de la viñeta que está en capa 50) y con letra más grande + contorno
# para que se lea bien contra el fondo del escenario.
func spawn_damage_number(target: Node2D, texto: String, color: Color = Color.WHITE, duracion: float = 0.7):
	if target == null:
		return

	var label = Label.new()
	label.text = texto
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 200

	var capa = CanvasLayer.new()
	capa.layer = 60
	add_child(capa)
	capa.add_child(label)

	var pos_pantalla = target.get_global_transform_with_canvas().origin
	label.position = pos_pantalla + Vector2(-20, -110)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, duracion)
	tween.tween_property(label, "modulate:a", 0.0, duracion)
	tween.chain().tween_callback(capa.queue_free)


# CAMBIO (nuevo): anima una ProgressBar hacia un nuevo valor en vez
# de saltar de golpe.
func tween_bar(bar: ProgressBar, valor: float):
	if bar == null:
		return
	var tween = create_tween()
	tween.tween_property(bar, "value", valor, 0.3).set_trans(Tween.TRANS_SINE)


# CAMBIO (nuevo): indicador de turno. Pone una flechita amarilla
# rebotando arriba del personaje que tiene el turno, y la borra
# cuando pasa el turno a otro (jugador o enemigo).
func actualizar_indicador_turno():
	if turno_indicador != null:
		turno_indicador.queue_free()
		turno_indicador = null

	if not turno_jugador:
		return

	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_actual = sprites_banda[turno_index]
	if sprite_actual == null:
		return

	var indicador = Label.new()
	indicador.text = "▼"
	indicador.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	indicador.add_theme_font_size_override("font_size", 82)
	indicador.position = Vector2(-10, -550)
	sprite_actual.add_child(indicador)
	turno_indicador = indicador

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(indicador, "position:y", indicador.position.y - 8, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(indicador, "position:y", indicador.position.y, 0.4).set_trans(Tween.TRANS_SINE)


# CAMBIO (nuevo): "carga" visual antes de que el enemigo golpee.
# El sprite crece un poco y se tiñe de amarillo, luego vuelve a
# la normalidad, dando tiempo a anticipar el golpe.
func telegraph_ataque(sprite: Node2D, duracion: float = 0.5):
	if sprite == null:
		return
	var original_scale = sprite.scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", original_scale * 1.15, duracion * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate", Color(1, 1, 0.6), duracion * 0.5).set_trans(Tween.TRANS_SINE)
	await tween.finished

	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(sprite, "scale", original_scale, duracion * 0.5).set_trans(Tween.TRANS_SINE)
	tween2.tween_property(sprite, "modulate", Color(1, 1, 1), duracion * 0.5).set_trans(Tween.TRANS_SINE)
	await tween2.finished


# CAMBIO (nuevo): cuando un personaje queda con 25% de vida o menos,
# su barra de HP pulsa en rojo como advertencia. Se apaga sola al
# recuperar vida por encima del umbral.
func actualizar_pulso_hp():
	var pares = [
		[hp_crow, crow_storm],
		[hp_blaze, blaze_inferno],
		[hp_rex, rex_thunder],
		[hp_crash, crash_doom],
	]
	for par in pares:
		var bar = par[0]
		var personaje = par[1]
		var ratio = float(personaje.hp_actual) / float(personaje.hp_max)

		if ratio <= 0.25 and ratio > 0.0:
			if not pulso_tweens.has(bar):
				var tween = create_tween()
				tween.set_loops()
				tween.tween_property(bar, "modulate", Color(1, 0.3, 0.3), 0.4).set_trans(Tween.TRANS_SINE)
				tween.tween_property(bar, "modulate", Color(1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
				pulso_tweens[bar] = tween
		else:
			if pulso_tweens.has(bar):
				pulso_tweens[bar].kill()
				pulso_tweens.erase(bar)
				bar.modulate = Color(1, 1, 1)


# CAMBIO (nuevo): zoom rápido de la cámara al conectar un crítico.
func zoom_punch(duracion: float = 0.3, intensidad: float = 0.15):
	if camera == null:
		return
	var original_zoom = camera.zoom
	var tween = create_tween()
	tween.tween_property(camera, "zoom", original_zoom + Vector2(intensidad, intensidad), duracion * 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "zoom", original_zoom, duracion * 0.6).set_trans(Tween.TRANS_SINE)


# CAMBIO (nuevo): una sola "imagen fantasma" del frame actual del sprite,
# usada para armar el efecto de estela.
func spawn_trail_ghost(sprite: AnimatedSprite2D, color: Color = Color(1, 1, 1, 0.4)):
	if sprite == null or sprite.sprite_frames == null:
		return
	var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return

	var ghost = Sprite2D.new()
	ghost.texture = tex
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = color
	ghost.z_index = sprite.z_index - 1

	var padre = sprite.get_parent()
	if padre == null:
		return
	padre.add_child(ghost)

	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


# CAMBIO (nuevo): dispara varias "imágenes fantasma" seguidas durante
# la animación de ataque, dando sensación de velocidad/estela.
func trail_durante_animacion(sprite: AnimatedSprite2D, duracion: float = 0.3, color: Color = Color(1, 1, 1, 0.35)):
	var elapsed = 0.0
	while elapsed < duracion:
		spawn_trail_ghost(sprite, color)
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


# CAMBIO (nuevo): confeti dorado al ganar la batalla, generado 100%
# por código igual que las partículas de impacto.
func spawn_confetti(origin: Node2D):
	if origin == null:
		return

	var particles = GPUParticles2D.new()
	var particle_material = ParticleProcessMaterial.new()

	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 6.0
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 100.0
	particle_material.gravity = Vector3(0, 220, 0)
	particle_material.initial_velocity_min = 120.0
	particle_material.initial_velocity_max = 260.0
	particle_material.scale_min = 0.6
	particle_material.scale_max = 1.4
	particle_material.color = Color(1, 0.85, 0.2)

	particles.process_material = particle_material
	particles.amount = 40
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.7
	particles.emitting = false

	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	particles.texture = ImageTexture.create_from_image(img)

	origin.add_child(particles)
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())


# CAMBIO (nuevo): viñeta de pantalla completa (bordes oscuros), generada
# con un gradiente radial por código, sin necesitar ninguna textura
# ni shader externo. Se usa en críticos y en la derrota.
func mostrar_vineta(duracion: float = 0.4, intensidad: float = 0.6):
	var overlay = TextureRect.new()
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, intensidad)])
	gradient.offsets = PackedFloat32Array([0.5, 1.0])

	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512

	overlay.texture = tex
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0

	var capa = CanvasLayer.new()
	capa.layer = 50
	capa.add_child(overlay)
	add_child(capa)

	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, duracion * 0.3)
	tween.tween_property(overlay, "modulate:a", 0.0, duracion * 0.7)
	tween.tween_callback(capa.queue_free)
