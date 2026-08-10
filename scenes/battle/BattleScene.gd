extends Node2D

# CAMBIO (nuevo): volúmenes por capa, en dB. 0.0 = volumen normal del
# archivo, negativo = más bajo, positivo = más fuerte (con cuidado,
# arriba de +6 puede distorsionar si el archivo ya viene fuerte).
# Ajusta solo estos 4 números para balancear música vs FX.
const MUSICA_VOLUMEN_DB = -16.0
const SFX_ATAQUE_VOLUMEN_DB = 4.0
const IMPACTO_VOLUMEN_DB = 6.0
const UI_VOLUMEN_DB = 2.0

# CAMBIO (nuevo): íconos simples por tipo de habilidad (sin necesidad
# de assets nuevos, son solo caracteres).
const ICONOS_HABILIDAD = {
	"ataque": "⚔ ",
	"critico": "☠ ",
	"buff": "▲ ",
	"recuperar": "♥ ",
}

# CAMBIO (nuevo): SFX de ataque, uno distinto por integrante de la banda,
# en el mismo orden que sprites_banda / banda_jugador (0=Crow, 1=Blaze,
# 2=Rex, 3=Crash). Si tus archivos tienen otro nombre, solo cambia la ruta.
const SFX_ATAQUE = [
	preload("res://assets/audio/sfx/grito_crow.wav"),          # Crow Storm - grito metalero
	preload("res://assets/audio/sfx/power_chord_blaze.mp3"),   # Blaze Inferno - power chord
	preload("res://assets/audio/sfx/slap_rex.mp3"),            # Rex Thunder - slap de bajo
	preload("res://assets/audio/sfx/drum-roll.wav"),           # Crash Doom - fill de batería
]

# CAMBIO (nuevo): resto de los SFX ya descargados.
const SFX_IMPACTO_ATAQUE = preload("res://assets/audio/sfx/ataque.wav")
const SFX_IMPACTO_CRITICO = preload("res://assets/audio/sfx/critico.wav")
const SFX_DANO_JUGADOR = preload("res://assets/audio/sfx/Daño recibido (jugador).wav")
const SFX_WINDUP_ENEMIGO = preload("res://assets/audio/sfx/Windup enemigo (telegraph).wav")
const SFX_RECUPERAR = preload("res://assets/audio/sfx/recuperar.wav")
const SFX_BUFF = preload("res://assets/audio/sfx/uppower-up.wav")
const SFX_VICTORIA = preload("res://assets/audio/sfx/Victoria.wav")
const SFX_DERROTA = preload("res://assets/audio/sfx/Derrota.wav")
const SFX_BOTON_UI = preload("res://assets/audio/sfx/Botón de turnoUI.wav")
const SFX_CAMBIO_TURNO = preload("res://assets/audio/sfx/Cambio de turno.wav")

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
var turno_indicador_tween: Tween = null
var pulso_tweens: Dictionary = {}

# CAMBIO (nuevo): estado del mini-juego QTE (requisito de "colisiones").
var qte_en_zona: bool = false
var qte_marcador_area: Area2D = null
var qte_zona_area: Area2D = null
var qte_direccion: int = 1
var qte_velocidad: float = 260.0

# CAMBIO (nuevo): candado para evitar doble clic / doble acción durante
# el turno del jugador (esto era lo que causaba prestigio duplicado).
var accion_en_curso: bool = false

@onready var hype_bar = $HUD/HypeBar
@onready var turno_label = $HUD/TurnoLabel
@onready var acciones_panel = $HUD/AccionesPanel
@onready var camera: Camera2D = get_node_or_null("Camera2D")

# CAMBIO (nuevo): reproductores de SFX. Se crean por código en _ready()
# para no depender de que los agregues manualmente en el editor.
var sfx_player: AudioStreamPlayer2D = null
var impact_player: AudioStreamPlayer2D = null
var ui_player: AudioStreamPlayer = null

# CAMBIO (nuevo): música de fondo por nivel, con fade in/out.
var music_player: AudioStreamPlayer = null

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

const ANCHO_BARRA_FLOTANTE = 90.0
const ALTO_BARRA_HP = -5.0
const ALTO_BARRA_ENERGIA = 3.0
const FUENTE_NOMBRE = 15
const MARGEN_SOBRE_CABEZA = 10.0
const ALTO_GRUPO_STATS = -120.0

const ALTO_OBJETIVO_ENEMIGO = 420.0


func _ready():
	# Crear los reproductores de SFX si no existen ya en la escena
	sfx_player = get_node_or_null("SFXPlayer")
	if sfx_player == null:
		sfx_player = AudioStreamPlayer2D.new()
		sfx_player.name = "SFXPlayer"
		add_child(sfx_player)
	sfx_player.volume_db = SFX_ATAQUE_VOLUMEN_DB

	impact_player = get_node_or_null("ImpactPlayer")
	if impact_player == null:
		impact_player = AudioStreamPlayer2D.new()
		impact_player.name = "ImpactPlayer"
		add_child(impact_player)
	impact_player.volume_db = IMPACTO_VOLUMEN_DB

	ui_player = get_node_or_null("UIPlayer")
	if ui_player == null:
		ui_player = AudioStreamPlayer.new()
		ui_player.name = "UIPlayer"
		add_child(ui_player)
	ui_player.volume_db = UI_VOLUMEN_DB

	music_player = get_node_or_null("MusicPlayer")
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		add_child(music_player)
	if not music_player.finished.is_connected(_on_musica_finished):
		music_player.finished.connect(_on_musica_finished)

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
		# CAMBIO (nuevo): efectos de vida en el escenario.
		iniciar_fx_fondo(fondo_sprite)

	# CAMBIO: Cargar sprite del enemigo dinámicamente.
	# Si el enemigo tiene frames_path (hoja animada) y el nodo es
	# AnimatedSprite2D, cargamos su SpriteFrames y reproducimos idle.
	# Si no, caemos al modo textura estática de siempre.
	if "frames_path" in enemigo and enemigo.frames_path != "" and sprite_enemigo is AnimatedSprite2D:
		sprite_enemigo.sprite_frames = load(enemigo.frames_path)
		if sprite_enemigo.sprite_frames.has_animation("idle"):
			sprite_enemigo.play("idle")
	elif enemigo.sprite_path != "" and sprite_enemigo is Sprite2D:
		sprite_enemigo.texture = load(enemigo.sprite_path)

	# Música de fondo según el nivel (clave "musica" en GameData.NIVELES).
	if nivel_data.has("musica") and ResourceLoader.exists(nivel_data["musica"]):
		reproducir_musica(load(nivel_data["musica"]))

	hype_bar.max_value = 100
	hype_bar.value = hype
	$HUD/AccionesPanel/BtnRecuperar.text = "♥ Recuperar Energia"

	# CAMBIO (nuevo): botón de objetos especiales, creado por código si
	# no existe ya en la escena (no necesitas tocar el editor).
	var btn_objetos = get_node_or_null("HUD/AccionesPanel/BtnObjetos")
	if btn_objetos == null:
		btn_objetos = Button.new()
		btn_objetos.name = "BtnObjetos"
		btn_objetos.custom_minimum_size = Vector2(150, 50)
		acciones_panel.add_child(btn_objetos)
	btn_objetos.text = "🎒 Objetos"
	if not btn_objetos.pressed.is_connected(_on_btn_objetos_pressed):
		btn_objetos.pressed.connect(_on_btn_objetos_pressed)

	turno_label.text = "Nivel " + str(GameData.nivel_actual) + ": " + nivel_data["nombre"]

	reubicar_stats_en_personajes()
	ajustar_sprite_enemigo()

	# CAMBIO (nuevo): banner de "JEFE" si el nivel lo marca. Agrega
	# "jefe": true a la entrada correspondiente en GameData.NIVELES.
	if nivel_data.get("jefe", false):
		mostrar_banner_jefe(enemigo.nombre)

	await get_tree().create_timer(1.5).timeout
	iniciar_turno()
	actualizar_stats()


# Reproduce idle solo en los sprites que son AnimatedSprite2D
# CAMBIO: ahora también incluye al enemigo, por si conviertes su nodo a
# AnimatedSprite2D con animaciones idle/ataque/dano. Si sigue siendo un
# Sprite2D estático, simplemente lo ignora sin error.
func reproducir_idle():
	for sprite in [sprite_crow, sprite_blaze, sprite_rex, sprite_crash, sprite_enemigo]:
		if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")


# CAMBIO: reemplaza al panel fijo de stats. Saca cada barra de HP/Energía
# de su contenedor original (StatsPanel) y la cuelga directamente del
# sprite de su personaje, flotando arriba de él (igual que el indicador
# de turno). Oculta el StatsPanel viejo al final.
func obtener_borde_superior_y(sprite: Node2D) -> float:
	if sprite.has_method("get_rect"):
		var rect = sprite.get_rect()
		return rect.position.y * sprite.scale.y
	return -300.0  # valor de respaldo si el nodo no soporta get_rect()


func reubicar_stats_en_personajes():
	var configuraciones = [
		[sprite_crow, hp_crow, energia_crow, crow_storm],
		[sprite_blaze, hp_blaze, energia_blaze, blaze_inferno],
		[sprite_rex, hp_rex, energia_rex, rex_thunder],
		[sprite_crash, hp_crash, energia_crash, crash_doom],
	]

	for i in range(configuraciones.size()):
		var cfg = configuraciones[i]
		var sprite = cfg[0]
		var hp_bar = cfg[1]
		var energia_bar = cfg[2]
		var personaje = cfg[3]

		if sprite == null or hp_bar == null or energia_bar == null:
			continue
		if sprite.has_node("NombreFlotante"):
			continue  # ya reubicado (por si _ready corre más de una vez)

		# Reparentar sin perder el estilo que ya tenían configurado
		var hp_padre = hp_bar.get_parent()
		if hp_padre != null:
			hp_padre.remove_child(hp_bar)
		sprite.add_child(hp_bar)

		var energia_padre = energia_bar.get_parent()
		if energia_padre != null:
			energia_padre.remove_child(energia_bar)
		sprite.add_child(energia_bar)

		var borde_superior_y = obtener_borde_superior_y(sprite)
		var y_base = borde_superior_y - MARGEN_SOBRE_CABEZA

		for bar in [hp_bar, energia_bar]:
			bar.anchor_left = 0.0
			bar.anchor_top = 0.0
			bar.anchor_right = 0.0
			bar.anchor_bottom = 0.0
			bar.offset_left = 0.0
			bar.offset_top = 0.0
			bar.offset_right = 0.0
			bar.offset_bottom = 0.0
			bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			bar.top_level = true

		hp_bar.custom_minimum_size = Vector2(ANCHO_BARRA_FLOTANTE, ALTO_BARRA_HP)
		hp_bar.size = Vector2(ANCHO_BARRA_FLOTANTE, ALTO_BARRA_HP)
		hp_bar.global_position = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0, y_base - ALTO_GRUPO_STATS + 20)
		hp_bar.z_index = 50
		hp_bar.add_theme_font_size_override("font_size", 13)

		energia_bar.custom_minimum_size = Vector2(ANCHO_BARRA_FLOTANTE, ALTO_BARRA_ENERGIA)
		energia_bar.size = Vector2(ANCHO_BARRA_FLOTANTE, ALTO_BARRA_ENERGIA)
		energia_bar.global_position = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0, y_base - ALTO_GRUPO_STATS + 40)
		energia_bar.z_index = 30
		energia_bar.add_theme_font_size_override("font_size", 14)

		var fondo = ColorRect.new()
		fondo.name = "FondoStats"
		fondo.color = Color(0, 0, 0, 0.45)
		fondo.size = Vector2(ANCHO_BARRA_FLOTANTE + 14, ALTO_GRUPO_STATS + 10)
		fondo.top_level = true
		fondo.global_position = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0 - 8, y_base - ALTO_GRUPO_STATS - 4)
		fondo.z_index = 49
		sprite.add_child(fondo)

		var nombre_label = Label.new()
		nombre_label.name = "NombreFlotante"
		nombre_label.text = personaje.nombre
		nombre_label.add_theme_font_size_override("font_size", FUENTE_NOMBRE)
		nombre_label.add_theme_color_override("font_color", Color(1, 1, 1))
		nombre_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		nombre_label.add_theme_constant_override("outline_size", 5)
		nombre_label.top_level = true
		nombre_label.global_position = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0, y_base - ALTO_GRUPO_STATS)
		nombre_label.z_index = 50
		sprite.add_child(nombre_label)

	var stats_panel = get_node_or_null("HUD/StatsPanel")
	if stats_panel != null:
		stats_panel.visible = false


# CAMBIO: escala el sprite del enemigo a una altura consistente y le
# agrega sombra. Ahora funciona tanto para Sprite2D estático como para
# AnimatedSprite2D (enemigos animados).
func ajustar_sprite_enemigo():
	if sprite_enemigo == null:
		return

	var alto_tex = 0.0
	if sprite_enemigo is Sprite2D and sprite_enemigo.texture != null:
		alto_tex = sprite_enemigo.texture.get_size().y
	elif sprite_enemigo is AnimatedSprite2D and sprite_enemigo.sprite_frames != null:
		var anim = sprite_enemigo.animation
		if sprite_enemigo.sprite_frames.get_frame_count(anim) > 0:
			var tex = sprite_enemigo.sprite_frames.get_frame_texture(anim, 0)
			if tex != null:
				alto_tex = tex.get_size().y

	if alto_tex > 0:
		var escala = ALTO_OBJETIVO_ENEMIGO / alto_tex
		sprite_enemigo.scale = Vector2(escala, escala)

	agregar_sombra_enemigo()


func agregar_sombra_enemigo():
	if sprite_enemigo == null:
		return
	var padre = sprite_enemigo.get_parent()
	if padre == null or padre.has_node("SombraEnemigo"):
		return

	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])

	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var sombra = Sprite2D.new()
	sombra.name = "SombraEnemigo"
	sombra.texture = tex
	sombra.scale = Vector2(1.6, 0.4)
	sombra.z_index = sprite_enemigo.z_index - 1

	var alto_real = ALTO_OBJETIVO_ENEMIGO
	sombra.position = sprite_enemigo.position + Vector2(0, alto_real * 0.5)

	padre.add_child(sombra)
	padre.move_child(sombra, sprite_enemigo.get_index())


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


# CAMBIO (nuevo): encuentra el próximo miembro vivo (hp_actual > 0)
# a partir de un índice dado, recorriendo la banda en círculo.
func siguiente_miembro_vivo(desde_index: int) -> int:
	for i in range(banda_jugador.size()):
		var idx = (desde_index + i) % banda_jugador.size()
		if banda_jugador[idx].hp_actual > 0:
			return idx
	return -1


func iniciar_turno():
	if turno_jugador:
		var vivo = siguiente_miembro_vivo(turno_index)
		if vivo == -1:
			return  # nadie vivo; verificar_batalla debería haber cortado antes
		turno_index = vivo

	actualizar_indicador_turno()
	reproducir_sfx_ui(SFX_CAMBIO_TURNO)
	if turno_jugador:
		accion_en_curso = false
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
			var habilidad = personaje.habilidades[i]
			var icono = ICONOS_HABILIDAD.get(habilidad.tipo, "")
			botones[i].text = icono + habilidad.nombre


func usar_habilidad(indice: int):
	if accion_en_curso:
		return
	var atacante = banda_jugador[turno_index]
	var habilidad = atacante.habilidades[indice]

	if atacante.energia_actual < habilidad.costo_energia:
		turno_label.text = "!" + atacante.nombre + " no tiene energia!"
		return

	accion_en_curso = true
	acciones_panel.visible = false
	atacante.energia_actual -= habilidad.costo_energia

	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_atacante = sprites_banda[turno_index]
	var enemigo = banda_enemiga[0]

	# CAMBIO (nuevo): mini-juego de timing antes de golpear/critico.
	var qte_exito = false
	if habilidad.tipo == "ataque" or habilidad.tipo == "critico":
		qte_exito = await mostrar_qte()

	match habilidad.tipo:
		"ataque":
			var cantidad = habilidad.dano_base + atacante.tecnica
			if qte_exito:
				cantidad = int(round(cantidad * 1.5))
			enemigo.hp_actual -= cantidad
			reproducir_anim(sprite_atacante, "ataque", 0.4)
			reproducir_sfx_ataque(turno_index)
			trail_durante_animacion(sprite_atacante, 0.35)
			await hit_stop(0.05, 0.05)
			reproducir_sfx_impacto(SFX_IMPACTO_ATAQUE, sprite_enemigo)
			reproducir_anim(sprite_enemigo, "dano", 0.4)
			flash_dano(sprite_enemigo, Color(1, 0, 0, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.3, 0.1))
			spawn_slash(sprite_enemigo, Color(1, 0.9, 0.7, 0.9))
			spawn_damage_number(sprite_enemigo, ("¡PERFECTO! -" if qte_exito else "-") + str(cantidad), Color(1, 0.3, 0.1) if not qte_exito else Color(1, 0.9, 0.2))
			squash_stretch(sprite_enemigo)
			knockback(sprite_enemigo, Vector2.RIGHT)
			shake_camera(0.25, 6.0)
		"critico":
			var cantidad = (habilidad.dano_base + atacante.tecnica) * 2
			if qte_exito:
				cantidad = int(round(cantidad * 1.5))
			enemigo.hp_actual -= cantidad
			reproducir_anim(sprite_atacante, "ataque", 0.4)
			reproducir_sfx_ataque(turno_index)
			trail_durante_animacion(sprite_atacante, 0.35, Color(1, 0.85, 0.3, 0.4))
			await hit_stop(0.09, 0.03)
			reproducir_sfx_impacto(SFX_IMPACTO_CRITICO, sprite_enemigo)
			reproducir_anim(sprite_enemigo, "dano", 0.4)
			flash_dano(sprite_enemigo, Color(1, 0.5, 0, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.85, 0.1))
			spawn_slash(sprite_enemigo, Color(1, 0.85, 0.2, 1.0), 3)
			spawn_damage_number(sprite_enemigo, "-" + str(cantidad) + "!", Color(1, 0.85, 0.1))
			squash_stretch(sprite_enemigo)
			knockback(sprite_enemigo, Vector2.RIGHT)
			shake_camera(0.4, 12.0)
			zoom_punch(0.35, 0.18)
			mostrar_vineta(0.35, 0.45)
		"buff":
			atacante.carisma += 5
			reproducir_anim(sprite_atacante, "hype", 0.4)
			reproducir_sfx_ui(SFX_BUFF)
			flash_dano(sprite_atacante, Color(0, 1, 0, 1))
			spawn_impact_particles(sprite_atacante, Color(0.3, 1, 0.4))
			spawn_damage_number(sprite_atacante, "+5 carisma", Color(0.3, 1, 0.4))
			squash_stretch(sprite_atacante)
		"recuperar":
			atacante.energia_actual = min(
				atacante.energia_actual + 30,
				atacante.energia_max
			)
			reproducir_sfx_ui(SFX_RECUPERAR)
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

	# CAMBIO: el enemigo solo puede apuntar a miembros vivos.
	var vivos = []
	for i in range(banda_jugador.size()):
		if banda_jugador[i].hp_actual > 0:
			vivos.append(i)
	if vivos.is_empty():
		return
	var objetivo_index = vivos[randi() % vivos.size()]
	var objetivo = banda_jugador[objetivo_index]
	var habilidad = enemigo.habilidades[randi() % enemigo.habilidades.size()]
	var cantidad = habilidad.dano_base

	turno_label.text = enemigo.nombre + " se prepara..."
	reproducir_sfx_ui(SFX_WINDUP_ENEMIGO)
	await telegraph_ataque(sprite_enemigo)
	reproducir_anim(sprite_enemigo, "ataque", 0.4)

	objetivo.hp_actual -= cantidad
	objetivo.hp_actual = max(objetivo.hp_actual, 0)
	turno_label.text = enemigo.nombre + " uso " + habilidad.nombre + "!"

	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_objetivo = sprites_banda[objetivo_index]

	reproducir_anim(sprite_objetivo, "dano", 0.4)
	await hit_stop(0.05, 0.05)
	reproducir_sfx_impacto(SFX_DANO_JUGADOR, sprite_objetivo)
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
	verificar_batalla(true)


# CAMBIO: recibe un parámetro para saber a quién le toca el siguiente
# turno si la batalla continúa.
func verificar_batalla(turno_jugador_siguiente: bool = false):
	if banda_enemiga[0].hp_actual <= 0:
		var nivel_data = GameData.NIVELES[GameData.nivel_actual]
		turno_label.text = "VICTORIA! Derrotaste a " + banda_enemiga[0].nombre + "!"
		acciones_panel.visible = false
		reproducir_sfx_ui(SFX_VICTORIA)
		fade_out_musica(1.5)
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
		reproducir_sfx_ui(SFX_DERROTA)
		fade_out_musica(1.5)
		mostrar_vineta(0.8, 0.7)
		GameData.ultimo_resultado_victoria = false
		GameData.guardar()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/ResultScreen.tscn")
		return

	turno_jugador = turno_jugador_siguiente
	if turno_jugador_siguiente:
		turno_index = (turno_index + 1) % banda_jugador.size()
	iniciar_turno()


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
	reproducir_sfx_ui(SFX_BOTON_UI)
	usar_habilidad(0)


func _on_btn_habilidad_2_pressed():
	reproducir_sfx_ui(SFX_BOTON_UI)
	usar_habilidad(1)


func _on_btn_habilidad_3_pressed():
	reproducir_sfx_ui(SFX_BOTON_UI)
	usar_habilidad(2)


func _on_btn_recuperar_pressed():
	if accion_en_curso:
		return
	accion_en_curso = true
	acciones_panel.visible = false
	reproducir_sfx_ui(SFX_BOTON_UI)
	var personaje = banda_jugador[turno_index]
	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]
	var sprite_actual = sprites_banda[turno_index]

	personaje.energia_actual = min(
		personaje.energia_actual + 30,
		personaje.energia_max
	)
	turno_label.text = personaje.nombre + " recupero energia!"
	reproducir_anim(sprite_actual, "recuperar", 0.4)
	reproducir_sfx_ui(SFX_RECUPERAR)
	flash_dano(sprite_actual, Color(0, 0.5, 1, 1))
	spawn_impact_particles(sprite_actual, Color(0.2, 0.6, 1))
	spawn_damage_number(sprite_actual, "+30 energia", Color(0.2, 0.6, 1))
	actualizar_stats()

	await get_tree().create_timer(1.0).timeout
	turno_jugador = false
	verificar_batalla()


func reproducir_sfx_ataque(indice: int):
	if sfx_player == null:
		return
	if indice < 0 or indice >= SFX_ATAQUE.size():
		return
	sfx_player.stream = SFX_ATAQUE[indice]
	sfx_player.play()


func reproducir_sfx_impacto(stream: AudioStream, posicion: Node2D):
	if impact_player == null or stream == null:
		return
	if posicion != null:
		impact_player.global_position = posicion.global_position
	impact_player.stream = stream
	impact_player.play()


func reproducir_sfx_ui(stream: AudioStream):
	if ui_player == null or stream == null:
		return
	ui_player.stream = stream
	ui_player.play()


func reproducir_musica(stream: AudioStream, fade_in: float = 1.5, volumen_final: float = MUSICA_VOLUMEN_DB):
	if music_player == null or stream == null:
		return
	music_player.stream = stream
	music_player.volume_db = -40.0
	music_player.play()
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", volumen_final, fade_in).set_trans(Tween.TRANS_SINE)


func _on_musica_finished():
	if music_player != null and music_player.stream != null:
		music_player.play()


func fade_out_musica(duracion: float = 1.5):
	if music_player == null:
		return
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -40.0, duracion).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(music_player.stop)


func _on_btn_objetos_pressed():
	if not turno_jugador or accion_en_curso:
		return

	var capa = CanvasLayer.new()
	capa.layer = 65
	add_child(capa)

	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(fondo)

	var panel = VBoxContainer.new()
	panel.position = Vector2(400, 250)
	fondo.add_child(panel)

	var titulo = Label.new()
	titulo.text = "🎒 Objetos"
	titulo.add_theme_font_size_override("font_size", 24)
	panel.add_child(titulo)

	var hay_objetos = false
	for id in UpgradeSystem.OBJETOS:
		var cantidad = GameData.inventario.get(id, 0)
		if cantidad <= 0:
			continue
		hay_objetos = true
		var objeto = UpgradeSystem.OBJETOS[id]

		var fila = HBoxContainer.new()
		panel.add_child(fila)

		var info = Label.new()
		info.custom_minimum_size = Vector2(350, 0)
		info.text = objeto["nombre"] + " (x" + str(cantidad) + ")"
		fila.add_child(info)

		var btn_usar = Button.new()
		btn_usar.text = "Usar"
		btn_usar.pressed.connect(_on_usar_objeto_pressed.bind(id, capa))
		fila.add_child(btn_usar)

	if not hay_objetos:
		var vacio = Label.new()
		vacio.text = "No tienes objetos. Cómpralos en la tienda de mejoras."
		panel.add_child(vacio)

	var btn_cerrar = Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.pressed.connect(func(): capa.queue_free())
	panel.add_child(btn_cerrar)


func _on_usar_objeto_pressed(id: String, capa: CanvasLayer):
	if accion_en_curso:
		return
	if not GameData.inventario.has(id) or GameData.inventario[id] <= 0:
		return

	accion_en_curso = true
	acciones_panel.visible = false
	GameData.inventario[id] -= 1
	GameData.guardar()

	var objeto = UpgradeSystem.OBJETOS[id]
	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]

	match objeto["tipo"]:
		"revivir":
			var revivido_index = -1
			for i in range(banda_jugador.size()):
				if banda_jugador[i].hp_actual <= 0:
					revivido_index = i
					break

			if revivido_index != -1:
				var personaje = banda_jugador[revivido_index]
				personaje.hp_actual = int(round(personaje.hp_max * 0.4))
				turno_label.text = personaje.nombre + " ¡vuelve al escenario!"
				spawn_damage_number(sprites_banda[revivido_index], "¡REVIVIÓ!", Color(0.3, 1, 0.4))
				spawn_impact_particles(sprites_banda[revivido_index], Color(0.3, 1, 0.4))
			else:
				var personaje = banda_jugador[turno_index]
				personaje.hp_actual = min(personaje.hp_actual + 40, personaje.hp_max)
				turno_label.text = personaje.nombre + " recuperó 40 HP!"
				spawn_damage_number(sprites_banda[turno_index], "+40 HP", Color(0.3, 1, 0.4))
			actualizar_stats()

		"adrenalina":
			var personaje = banda_jugador[turno_index]
			personaje.energia_actual = personaje.energia_max
			var enemigo = banda_enemiga[0]
			var cantidad_dano = 25
			enemigo.hp_actual = max(enemigo.hp_actual - cantidad_dano, 0)
			turno_label.text = "¡Carga de Adrenalina!"
			reproducir_sfx_impacto(SFX_IMPACTO_CRITICO, sprite_enemigo)
			flash_dano(sprite_enemigo, Color(1, 0.9, 0.2, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.9, 0.2))
			spawn_damage_number(sprite_enemigo, "-" + str(cantidad_dano), Color(1, 0.9, 0.2))
			shake_camera(0.3, 8.0)
			actualizar_stats()

	capa.queue_free()
	await get_tree().create_timer(0.8).timeout
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


func hit_stop(duration: float = 0.06, escala_tiempo: float = 0.05):
	Engine.time_scale = escala_tiempo
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func squash_stretch(sprite: Node2D):
	if sprite == null:
		return
	var original_scale = sprite.scale
	var tween = create_tween()
	tween.tween_property(sprite, "scale", original_scale * Vector2(1.25, 0.75), 0.06)
	tween.tween_property(sprite, "scale", original_scale, 0.12)


func knockback(sprite: Node2D, direccion: Vector2):
	if sprite == null:
		return
	var original_pos = sprite.position
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_pos + direccion * 12, 0.05)
	tween.tween_property(sprite, "position", original_pos, 0.15)


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


func tween_bar(bar: ProgressBar, valor: float):
	if bar == null:
		return
	var tween = create_tween()
	tween.tween_property(bar, "value", valor, 0.3).set_trans(Tween.TRANS_SINE)


func actualizar_indicador_turno():
	if turno_indicador_tween != null and turno_indicador_tween.is_valid():
		turno_indicador_tween.kill()
		turno_indicador_tween = null

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
	indicador.add_theme_font_size_override("font_size", 32)
	indicador.position = Vector2(-10, -110)
	sprite_actual.add_child(indicador)
	turno_indicador = indicador

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(indicador, "position:y", indicador.position.y - 8, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(indicador, "position:y", indicador.position.y, 0.4).set_trans(Tween.TRANS_SINE)
	turno_indicador_tween = tween


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


func zoom_punch(duracion: float = 0.3, intensidad: float = 0.15):
	if camera == null:
		return
	var original_zoom = camera.zoom
	var tween = create_tween()
	tween.tween_property(camera, "zoom", original_zoom + Vector2(intensidad, intensidad), duracion * 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "zoom", original_zoom, duracion * 0.6).set_trans(Tween.TRANS_SINE)


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


func trail_durante_animacion(sprite: AnimatedSprite2D, duracion: float = 0.3, color: Color = Color(1, 1, 1, 0.35)):
	var elapsed = 0.0
	while elapsed < duracion:
		spawn_trail_ghost(sprite, color)
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


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


# ============================================================
# Mini-juego QTE (Quick Time Event) de timing. Cubre el requisito de
# "colisiones": un marcador se mueve por una barra y usa Area2D real
# para detectar si está sobre la zona verde cuando el jugador presiona
# (ui_accept = Espacio/Enter). Devuelve true si acertó dentro de la zona.
# ============================================================
func mostrar_qte() -> bool:
	qte_en_zona = false
	qte_direccion = 1

	var capa = CanvasLayer.new()
	capa.layer = 70
	add_child(capa)

	var viewport_size = get_viewport().get_visible_rect().size
	var ancho_barra = 400.0
	var origen_barra = Vector2(viewport_size.x / 2.0 - ancho_barra / 2.0, viewport_size.y - 160)

	var fondo_barra = ColorRect.new()
	fondo_barra.color = Color(0, 0, 0, 0.6)
	fondo_barra.size = Vector2(ancho_barra, 24)
	fondo_barra.position = origen_barra
	capa.add_child(fondo_barra)

	var ancho_zona = 70.0
	var offset_zona = randf_range(20, ancho_barra - 20 - ancho_zona)
	var zona_visual = ColorRect.new()
	zona_visual.color = Color(0.2, 1.0, 0.3, 0.85)
	zona_visual.size = Vector2(ancho_zona, 24)
	zona_visual.position = origen_barra + Vector2(offset_zona, 0)
	capa.add_child(zona_visual)

	var marcador_visual = ColorRect.new()
	marcador_visual.color = Color(1, 1, 1, 1)
	marcador_visual.size = Vector2(6, 30)
	marcador_visual.position = origen_barra + Vector2(0, -3)
	capa.add_child(marcador_visual)

	var instrucciones = Label.new()
	instrucciones.text = "¡Presiona ESPACIO en el momento justo!"
	instrucciones.add_theme_font_size_override("font_size", 20)
	instrucciones.add_theme_color_override("font_color", Color(1, 1, 1))
	instrucciones.position = origen_barra + Vector2(0, -40)
	capa.add_child(instrucciones)

	var mundo_qte = Node2D.new()
	capa.add_child(mundo_qte)

	qte_zona_area = Area2D.new()
	var zona_shape = CollisionShape2D.new()
	var zona_rect = RectangleShape2D.new()
	zona_rect.size = Vector2(ancho_zona, 24)
	zona_shape.shape = zona_rect
	qte_zona_area.add_child(zona_shape)
	qte_zona_area.position = origen_barra + Vector2(offset_zona + ancho_zona / 2.0, 12)
	mundo_qte.add_child(qte_zona_area)

	qte_marcador_area = Area2D.new()
	var marcador_shape = CollisionShape2D.new()
	var marcador_rect = RectangleShape2D.new()
	marcador_rect.size = Vector2(6, 30)
	marcador_shape.shape = marcador_rect
	qte_marcador_area.add_child(marcador_shape)
	qte_marcador_area.position = origen_barra + Vector2(0, 12)
	mundo_qte.add_child(qte_marcador_area)

	qte_zona_area.area_entered.connect(func(area):
		if area == qte_marcador_area:
			qte_en_zona = true
	)
	qte_zona_area.area_exited.connect(func(area):
		if area == qte_marcador_area:
			qte_en_zona = false
	)

	var exito = false
	var tiempo_max = 2.5
	var t = 0.0

	while t < tiempo_max:
		var delta = get_process_delta_time()
		t += delta

		var x_actual = qte_marcador_area.position.x - origen_barra.x
		x_actual += qte_direccion * qte_velocidad * delta
		if x_actual <= 0:
			x_actual = 0
			qte_direccion = 1
		elif x_actual >= ancho_barra:
			x_actual = ancho_barra
			qte_direccion = -1

		qte_marcador_area.position.x = origen_barra.x + x_actual
		marcador_visual.position.x = origen_barra.x + x_actual - 3

		if Input.is_action_just_pressed("ui_accept"):
			exito = qte_en_zona
			break

		await get_tree().process_frame

	if exito:
		zona_visual.color = Color(1, 0.9, 0.2, 0.9)
	else:
		zona_visual.color = Color(1, 0.2, 0.2, 0.7)

	await get_tree().create_timer(0.15).timeout
	capa.queue_free()
	return exito


func mostrar_banner_jefe(nombre_enemigo: String):
	var capa = CanvasLayer.new()
	capa.layer = 80
	add_child(capa)

	var franja = ColorRect.new()
	franja.color = Color(0.6, 0, 0, 0.9)
	var viewport_size = get_viewport().get_visible_rect().size
	franja.size = Vector2(viewport_size.x, 90)
	franja.position = Vector2(0, -90)
	capa.add_child(franja)

	var titulo = Label.new()
	titulo.text = "⚠ JEFE: " + nombre_enemigo.to_upper() + " ⚠"
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", Color(1, 1, 1))
	titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	franja.add_child(titulo)

	var tween = create_tween()
	tween.tween_property(franja, "position:y", viewport_size.y / 2.0 - 45, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.5)
	tween.tween_property(franja, "position:y", -90, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(capa.queue_free)


# ============================================================
# CAMBIO (nuevo): efectos de vida en el fondo del escenario.
# Los 4 se generan por código sobre el fondo ya cargado:
#  1. Parallax/zoom lento (Ken Burns)
#  2. Pulso de luz rítmico (brillo que late)
#  3. Reflectores de colores barriendo
#  4. Partículas flotantes (motas/humo)
# ============================================================
func iniciar_fx_fondo(fondo_sprite: Sprite2D):
	fx_parallax_zoom(fondo_sprite)
	fx_pulso_luz(fondo_sprite)
	fx_reflectores()
	fx_particulas_ambiente()


# 1. Zoom/paneo lento infinito (efecto Ken Burns).
func fx_parallax_zoom(fondo_sprite: Sprite2D):
	if fondo_sprite == null:
		return
	var escala_base = fondo_sprite.scale
	var pos_base = fondo_sprite.position
	var tween = create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	# acercar un poco
	tween.tween_property(fondo_sprite, "scale", escala_base * 1.06, 8.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fondo_sprite, "position", pos_base + Vector2(-20, -10), 8.0).set_trans(Tween.TRANS_SINE)
	# volver
	tween.chain().set_parallel(true)
	tween.tween_property(fondo_sprite, "scale", escala_base, 8.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fondo_sprite, "position", pos_base, 8.0).set_trans(Tween.TRANS_SINE)


# 2. Pulso de brillo/tinte del fondo, como respirando al ritmo.
func fx_pulso_luz(fondo_sprite: Sprite2D):
	if fondo_sprite == null:
		return
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(fondo_sprite, "modulate", Color(1.12, 1.05, 1.15), 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fondo_sprite, "modulate", Color(0.9, 0.9, 1.0), 1.2).set_trans(Tween.TRANS_SINE)


# 3. Reflectores de colores: haces triangulares semitransparentes que
#    barren lentamente de lado a lado, en su propia capa detrás de todo.
func fx_reflectores():
	var capa = CanvasLayer.new()
	capa.layer = -5  # detrás de personajes/HUD, delante del fondo
	capa.name = "ReflectoresFX"
	add_child(capa)

	var viewport_size = get_viewport().get_visible_rect().size
	var colores = [Color(1, 0.2, 0.8, 0.12), Color(0.3, 0.5, 1, 0.12), Color(0.6, 0.2, 1, 0.12)]

	for i in range(colores.size()):
		var haz = Polygon2D.new()
		# triángulo tipo cono de luz apuntando hacia abajo
		haz.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(-120, viewport_size.y),
			Vector2(120, viewport_size.y),
		])
		haz.color = colores[i]
		haz.position = Vector2(viewport_size.x * (0.25 + 0.25 * i), -20)
		capa.add_child(haz)

		var tween = create_tween()
		tween.set_loops()
		var desp = 150 + i * 40
		tween.tween_property(haz, "position:x", haz.position.x + desp, 3.0 + i).set_trans(Tween.TRANS_SINE)
		tween.tween_property(haz, "position:x", haz.position.x - desp, 3.0 + i).set_trans(Tween.TRANS_SINE)


# 4. Partículas flotando en el ambiente (motas/polvo/humo tenue).
func fx_particulas_ambiente():
	var capa = CanvasLayer.new()
	capa.layer = -4
	capa.name = "ParticulasAmbienteFX"
	add_child(capa)

	var viewport_size = get_viewport().get_visible_rect().size

	var particles = GPUParticles2D.new()
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(viewport_size.x / 2.0, 10, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 25.0
	mat.gravity = Vector3(0, -12, 0)  # suben lentamente
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 24.0
	mat.scale_min = 0.5
	mat.scale_max = 1.6
	mat.color = Color(1, 1, 1, 0.25)

	particles.process_material = mat
	particles.amount = 40
	particles.lifetime = 6.0
	particles.preprocess = 3.0
	particles.position = Vector2(viewport_size.x / 2.0, viewport_size.y + 20)

	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	particles.texture = ImageTexture.create_from_image(img)

	capa.add_child(particles)
	particles.emitting = true


# CAMBIO (nuevo): marca de "corte" (slash) sobre el objetivo al golpear.
# Son líneas diagonales blancas que aparecen y se desvanecen rápido,
# dando sensación de impacto cortante. 'cantidad' = número de líneas.
func spawn_slash(target: Node2D, color: Color = Color(1, 1, 1, 0.9), cantidad: int = 1):
	if target == null:
		return

	for i in range(cantidad):
		var linea = Line2D.new()
		linea.width = 6.0
		linea.default_color = color
		var largo = randf_range(60, 110)
		var angulo = randf_range(-0.9, -0.5)  # diagonal
		var centro = Vector2(randf_range(-30, 30), randf_range(-140, -60))
		var dir = Vector2(cos(angulo), sin(angulo)) * largo
		linea.add_point(centro - dir)
		linea.add_point(centro + dir)
		linea.z_index = 60
		target.add_child(linea)

		var tween = create_tween()
		tween.tween_interval(0.05)
		tween.tween_property(linea, "modulate:a", 0.0, 0.2)
		tween.tween_callback(linea.queue_free)
