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
var turno_spot: Node = null
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

# CAMBIO (nuevo): si es true, el enemigo pierde su próximo turno
# (lo activa la Carga de Adrenalina).
var enemigo_aturdido: bool = false

# CAMBIO (nuevo): barra de HP flotante del enemigo.
var enemigo_hp_bar: ProgressBar = null

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

# CAMBIO: tamaños del HUD flotante. AJUSTA ESTOS 3 para el grosor/ancho.
const ANCHO_BARRA_FLOTANTE = 96.0
const ALTO_BARRA_HP = 7.0        # grosor barra de vida (más chico = más delgada, mín útil ~4)
const ALTO_BARRA_ENERGIA = 5.0   # grosor barra de energía
const FUENTE_NOMBRE = 13
const MARGEN_SOBRE_CABEZA = 10.0
const ALTO_GRUPO_STATS = -100.0
# Separaciones verticales dentro del grupo (nombre / hp / energía)
const OFF_NOMBRE = 0.0
const OFF_HP = 19.0
const OFF_ENERGIA = 31.0
const ALTO_PANEL_STATS = 44.0

# CAMBIO (nuevo): paleta Battle Bands para el HUD.
const COLOR_HP = Color(0.9, 0.15, 0.25)          # rojo (solo para HP)
const COLOR_ENERGIA = Color(0.8, 0.2, 0.9)       # magenta/morado
const COLOR_BARRA_FONDO = Color(0.1, 0.1, 0.12)  # gris muy oscuro
const COLOR_BORDE = Color(0.85, 0.2, 0.8)        # magenta borde


# CAMBIO (nuevo): construye un StyleBoxFlat para el relleno de una barra,
# con esquinas redondeadas y borde, en el estilo Battle Bands.
func _estilo_barra_fill(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	# Sin márgenes internos para que no inflen el alto de la barra.
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


func _estilo_barra_fondo() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_BARRA_FONDO
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = COLOR_BORDE
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

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
	# CAMBIO (nuevo): estilo Battle Bands para la barra de Hype.
	hype_bar.show_percentage = false
	hype_bar.add_theme_stylebox_override("background", _estilo_barra_fondo())
	hype_bar.add_theme_stylebox_override("fill", _estilo_barra_fill(Color(1, 0.4, 0.9)))
	if not hype_bar.has_node("HypeLabel"):
		var hype_lbl = Label.new()
		hype_lbl.name = "HypeLabel"
		hype_lbl.text = "⚡ HYPE"
		hype_lbl.add_theme_font_size_override("font_size", 14)
		hype_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		hype_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		hype_lbl.add_theme_constant_override("outline_size", 4)
		hype_lbl.position = Vector2(8, -2)
		hype_bar.add_child(hype_lbl)

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

	# CAMBIO (nuevo): botón de Golpe de Multitud (ultimate de Hype).
	# Solo aparece cuando el Hype está al 100%.
	var btn_hype = get_node_or_null("HUD/AccionesPanel/BtnHype")
	if btn_hype == null:
		btn_hype = Button.new()
		btn_hype.name = "BtnHype"
		btn_hype.custom_minimum_size = Vector2(150, 50)
		acciones_panel.add_child(btn_hype)
	btn_hype.text = "🔥 GOLPE DE MULTITUD"
	btn_hype.visible = false
	if not btn_hype.pressed.is_connected(_on_golpe_multitud_pressed):
		btn_hype.pressed.connect(_on_golpe_multitud_pressed)

	# CAMBIO (nuevo): estilo Battle Bands para todos los botones del
	# menú de acciones (panel oscuro, borde magenta, hover con glow).
	for boton in acciones_panel.get_children():
		if boton is Button:
			_estilizar_boton_bb(boton)

	turno_label.text = "Nivel " + str(GameData.nivel_actual) + ": " + nivel_data["nombre"]

	reubicar_stats_en_personajes()
	ajustar_sprite_enemigo()
	crear_barra_enemigo(enemigo)

	# CAMBIO (nuevo): transición de entrada al venue (fade + nombre del lugar).
	transicion_entrada(nivel_data["nombre"])

	# CAMBIO (nuevo): banner de "JEFE" si el nivel lo marca. Agrega
	# "jefe": true a la entrada correspondiente en GameData.NIVELES.
	if nivel_data.get("jefe", false):
		mostrar_banner_jefe(enemigo.nombre)

	await get_tree().create_timer(1.5).timeout
	iniciar_turno()
	actualizar_stats()


# CAMBIO (nuevo): color de acento por nivel, para el rim light del enemigo
# y detalles del venue. Si el nivel no está aquí, usa el default magenta.
const COLOR_VENUE = {
	1: Color(0.8, 0.3, 1.0),   # Garage - morado
	2: Color(1.0, 0.3, 0.7),   # Bar Local - rosa
	3: Color(0.3, 0.7, 1.0),   # Escuela de Arte - azul
	4: Color(0.6, 0.2, 1.0),   # Callejón - violeta
	5: Color(1.0, 0.2, 0.3),   # Club - rojo
}

func color_venue() -> Color:
	return COLOR_VENUE.get(GameData.nivel_actual, Color(0.85, 0.2, 0.8))


# CAMBIO (nuevo): fade negro que se abre + nombre del venue entrando,
# para que el cambio de escenario se sienta intencional.
func transicion_entrada(nombre_venue: String):
	var capa = CanvasLayer.new()
	capa.layer = 85
	add_child(capa)

	var negro = ColorRect.new()
	negro.color = Color(0, 0, 0, 1)
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(negro)

	var viewport_size = get_viewport().get_visible_rect().size
	var etiqueta = Label.new()
	etiqueta.text = nombre_venue.to_upper()
	etiqueta.add_theme_font_size_override("font_size", 52)
	etiqueta.add_theme_color_override("font_color", color_venue())
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	etiqueta.add_theme_constant_override("outline_size", 8)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capa.add_child(etiqueta)

	var tween = create_tween()
	# el negro se abre
	tween.tween_property(negro, "color", Color(0, 0, 0, 0), 0.6).set_delay(0.3)
	# el nombre del venue se desvanece un poco después
	tween.parallel().tween_property(etiqueta, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tween.tween_callback(capa.queue_free)


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
		hp_bar.global_position = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0, y_base - ALTO_GRUPO_STATS + OFF_HP)
		hp_bar.z_index = 50
		hp_bar.show_percentage = false
		# CAMBIO: la fuente interna del ProgressBar impone un alto mínimo
		# (~40px) aunque ocultes el %. Forzándola a 1px, ALTO_BARRA_HP sí
		# controla el grosor real de la barra.
		hp_bar.add_theme_font_size_override("font_size", 1)
		hp_bar.add_theme_stylebox_override("background", _estilo_barra_fondo())
		hp_bar.add_theme_stylebox_override("fill", _estilo_barra_fill(COLOR_HP))

		energia_bar.custom_minimum_size = Vector2(ANCHO_BARRA_FLOTANTE, ALTO_BARRA_ENERGIA)
		energia_bar.size = Vector2(ANCHO_BARRA_FLOTANTE, ALTO_BARRA_ENERGIA)
		energia_bar.global_position = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0, y_base - ALTO_GRUPO_STATS + OFF_ENERGIA)
		energia_bar.z_index = 50
		energia_bar.show_percentage = false
		energia_bar.add_theme_font_size_override("font_size", 1)
		energia_bar.add_theme_stylebox_override("background", _estilo_barra_fondo())
		energia_bar.add_theme_stylebox_override("fill", _estilo_barra_fill(COLOR_ENERGIA))

		# CAMBIO: fondo compacto (panel oscuro con borde magenta) que
		# envuelve nombre + 2 barras. Antes tenía altura negativa y no
		# se veía; ahora es un Panel con el estilo Battle Bands.
		var origen_grupo = sprite.global_position + Vector2(-ANCHO_BARRA_FLOTANTE / 2.0, y_base - ALTO_GRUPO_STATS)
		var fondo = Panel.new()
		fondo.name = "FondoStats"
		var sb_fondo = StyleBoxFlat.new()
		sb_fondo.bg_color = Color(0, 0, 0, 0.5)
		sb_fondo.border_width_left = 1
		sb_fondo.border_width_right = 1
		sb_fondo.border_width_top = 1
		sb_fondo.border_width_bottom = 1
		sb_fondo.border_color = Color(COLOR_BORDE.r, COLOR_BORDE.g, COLOR_BORDE.b, 0.6)
		sb_fondo.corner_radius_top_left = 4
		sb_fondo.corner_radius_top_right = 4
		sb_fondo.corner_radius_bottom_left = 4
		sb_fondo.corner_radius_bottom_right = 4
		fondo.add_theme_stylebox_override("panel", sb_fondo)
		fondo.size = Vector2(ANCHO_BARRA_FLOTANTE + 12, ALTO_PANEL_STATS)
		fondo.top_level = true
		fondo.global_position = origen_grupo + Vector2(-6, -2)
		fondo.z_index = 49
		sprite.add_child(fondo)

		var nombre_label = Label.new()
		nombre_label.name = "NombreFlotante"
		nombre_label.text = personaje.nombre.to_upper()
		nombre_label.add_theme_font_size_override("font_size", FUENTE_NOMBRE)
		nombre_label.add_theme_color_override("font_color", Color(1, 1, 1))
		nombre_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		nombre_label.add_theme_constant_override("outline_size", 4)
		nombre_label.top_level = true
		nombre_label.global_position = origen_grupo
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
	agregar_rim_light_enemigo()


# CAMBIO (nuevo): glow de borde (rim light) detrás del enemigo, del color
# del venue, para integrarlo al escenario en vez de verse recortado.
func agregar_rim_light_enemigo():
	if sprite_enemigo == null:
		return
	var padre = sprite_enemigo.get_parent()
	if padre == null or padre.has_node("RimLightEnemigo"):
		return

	var c = color_venue()
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.5), Color(c.r, c.g, c.b, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gtex = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256

	var rim = Sprite2D.new()
	rim.name = "RimLightEnemigo"
	rim.texture = gtex
	rim.scale = Vector2(2.2, 3.0)
	rim.position = sprite_enemigo.position
	rim.z_index = sprite_enemigo.z_index - 1

	padre.add_child(rim)
	padre.move_child(rim, sprite_enemigo.get_index())

	# pulso lento
	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(rim, "modulate:a", 0.6, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rim, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)


# CAMBIO (nuevo): barra de HP flotante sobre el enemigo, con su nombre.
# Más ancha que las de la banda porque el enemigo es más grande.
func crear_barra_enemigo(enemigo):
	if sprite_enemigo == null or enemigo == null:
		return
	if sprite_enemigo.has_node("EnemigoNombre"):
		return  # ya creada

	var ancho = 180.0
	var borde_superior = obtener_borde_superior_y(sprite_enemigo)
	var origen = sprite_enemigo.global_position + Vector2(-ancho / 2.0, borde_superior - -130)

	# Panel de fondo
	var fondo = Panel.new()
	fondo.name = "EnemigoFondo"
	var sb_fondo = StyleBoxFlat.new()
	sb_fondo.bg_color = Color(0, 0, 0, 0.55)
	sb_fondo.border_width_left = 1
	sb_fondo.border_width_right = 1
	sb_fondo.border_width_top = 1
	sb_fondo.border_width_bottom = 1
	sb_fondo.border_color = Color(0.9, 0.2, 0.25, 0.7)
	sb_fondo.corner_radius_top_left = 5
	sb_fondo.corner_radius_top_right = 5
	sb_fondo.corner_radius_bottom_left = 5
	sb_fondo.corner_radius_bottom_right = 5
	fondo.add_theme_stylebox_override("panel", sb_fondo)
	fondo.size = Vector2(ancho + 14, 44)
	fondo.top_level = true
	fondo.global_position = origen + Vector2(-7, -4)
	fondo.z_index = 49
	sprite_enemigo.add_child(fondo)

	# Nombre
	var nombre = Label.new()
	nombre.name = "EnemigoNombre"
	nombre.text = enemigo.nombre.to_upper()
	nombre.add_theme_font_size_override("font_size", 16)
	nombre.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	nombre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	nombre.add_theme_constant_override("outline_size", 4)
	nombre.top_level = true
	nombre.global_position = origen
	nombre.z_index = 50
	sprite_enemigo.add_child(nombre)

	# Barra de HP
	enemigo_hp_bar = ProgressBar.new()
	enemigo_hp_bar.name = "EnemigoHP"
	enemigo_hp_bar.max_value = enemigo.hp_max
	enemigo_hp_bar.value = enemigo.hp_actual
	enemigo_hp_bar.show_percentage = false
	enemigo_hp_bar.add_theme_font_size_override("font_size", 1)
	enemigo_hp_bar.add_theme_stylebox_override("background", _estilo_barra_fondo())
	enemigo_hp_bar.add_theme_stylebox_override("fill", _estilo_barra_fill(COLOR_HP))
	enemigo_hp_bar.custom_minimum_size = Vector2(ancho, 12)
	enemigo_hp_bar.size = Vector2(ancho, 12)
	enemigo_hp_bar.top_level = true
	enemigo_hp_bar.global_position = origen + Vector2(0, 24)
	enemigo_hp_bar.z_index = 50
	sprite_enemigo.add_child(enemigo_hp_bar)


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
		anunciar_turno(personaje.nombre)
		acciones_panel.visible = true
		actualizar_botones(personaje)
		actualizar_boton_hype()
		# CAMBIO: el botón de recuperar cambia para Crash Doom (cura banda)
		var btn_rec = get_node_or_null("HUD/AccionesPanel/BtnRecuperar")
		if btn_rec != null:
			if personaje == crash_doom:
				btn_rec.text = "♥ Sanar Banda +30"
			else:
				btn_rec.text = "♥ Recuperar Energia"
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
	# La calidad (perfect/good/miss) multiplica el daño.
	var qte_calidad = "good"  # valor neutro si no aplica QTE
	if habilidad.tipo == "ataque" or habilidad.tipo == "critico":
		qte_calidad = await mostrar_qte()
	var mult_qte = 1.0
	match qte_calidad:
		"perfect": mult_qte = 1.75
		"good": mult_qte = 1.25
		"miss": mult_qte = 0.75

	match habilidad.tipo:
		"ataque":
			var cantidad = int(round((habilidad.dano_base + atacante.tecnica) * mult_qte))
			enemigo.hp_actual -= cantidad
			# Secuencia de golpe satisfactorio: ATTACK → zoom → freeze →
			# flash → shake → slash → número → enemigo HURT
			reproducir_anim(sprite_atacante, "ataque", 0.4)
			reproducir_sfx_ataque(turno_index)
			trail_durante_animacion(sprite_atacante, 0.35)
			await fx_ataque_personaje(turno_index, sprite_atacante, sprite_enemigo)
			zoom_punch(0.25, 0.10)
			await hit_stop(0.08, 0.05)
			reproducir_sfx_impacto(SFX_IMPACTO_ATAQUE, sprite_enemigo)
			reproducir_anim(sprite_enemigo, "dano", 0.4)
			flash_dano(sprite_enemigo, Color(1, 0, 0, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.3, 0.1))
			spawn_slash(sprite_enemigo, Color(1, 0.9, 0.7, 0.9))
			mega_impacto(sprite_enemigo, Color(1, 0.4, 0.1), 2)
			spawn_damage_number(sprite_enemigo, ("¡PERFECT! -" if qte_calidad == "perfect" else "-") + str(cantidad), Color(1, 0.9, 0.2) if qte_calidad == "perfect" else Color(1, 0.3, 0.1))
			squash_stretch(sprite_enemigo)
			knockback(sprite_enemigo, Vector2.RIGHT)
			shake_camera(0.25, 7.0)
		"critico":
			var cantidad = int(round((habilidad.dano_base + atacante.tecnica) * 2 * mult_qte))
			enemigo.hp_actual -= cantidad
			reproducir_anim(sprite_atacante, "ataque", 0.4)
			reproducir_sfx_ataque(turno_index)
			trail_durante_animacion(sprite_atacante, 0.35, Color(1, 0.85, 0.3, 0.4))
			await fx_ataque_personaje(turno_index, sprite_atacante, sprite_enemigo)
			spawn_shockwave(sprite_enemigo, Color(1, 0.85, 0.2))
			spawn_rayo(sprite_atacante, sprite_enemigo, Color(1, 0.9, 0.4))
			zoom_punch(0.35, 0.18)
			await hit_stop(0.09, 0.03)
			reproducir_sfx_impacto(SFX_IMPACTO_CRITICO, sprite_enemigo)
			reproducir_anim(sprite_enemigo, "dano", 0.4)
			flash_dano(sprite_enemigo, Color(1, 0.5, 0, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.85, 0.1))
			spawn_slash(sprite_enemigo, Color(1, 0.85, 0.2, 1.0), 3)
			mega_impacto(sprite_enemigo, Color(1, 0.85, 0.2), 4)
			spawn_damage_number(sprite_enemigo, "-" + str(cantidad) + "!", Color(1, 0.85, 0.1))
			squash_stretch(sprite_enemigo)
			knockback(sprite_enemigo, Vector2.RIGHT)
			shake_camera(0.4, 12.0)
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

	# CAMBIO (nuevo): si está aturdido (Carga de Adrenalina), pierde el
	# turno y se lo devuelve al jugador.
	if enemigo_aturdido:
		enemigo_aturdido = false
		turno_label.text = enemigo.nombre + " está aturdido... ¡pierde el turno!"
		spawn_damage_number(sprite_enemigo, "💫 ATURDIDO", Color(1, 0.9, 0.4))
		var tw = create_tween()
		tw.tween_property(sprite_enemigo, "modulate", Color(0.7, 0.7, 1.0), 0.3)
		tw.tween_property(sprite_enemigo, "modulate", Color(1, 1, 1), 0.3)
		await get_tree().create_timer(1.4).timeout
		verificar_batalla(true)
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

	# CAMBIO (nuevo): FX de ataque del enemigo hacia el objetivo (energía
	# oscura + onda de choque al impactar).
	await spawn_proyectil(sprite_enemigo, sprite_objetivo, Color(0.7, 0.15, 0.85), 2)
	spawn_shockwave(sprite_objetivo, Color(0.7, 0.15, 0.85))

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
		enemigo_derrotado_visual()  # CAMBIO: el enemigo cae/se apaga
		for sprite in [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]:
			spawn_confetti(sprite)

		var prestigio_ganado = nivel_data["prestigio"]
		var fans_ganados = prestigio_ganado * 2 + hype
		# CAMBIO: detectar si este era el jefe final (nivel 5) ANTES de
		# tocar nivel_actual, para mostrar créditos en vez de "continuar".
		var era_final = GameData.nivel_actual >= 5

		GameData.ultimo_resultado_victoria = true
		GameData.ganar_prestigio(prestigio_ganado)
		if GameData.nivel_actual < 5:
			GameData.nivel_actual += 1
		GameData.guardar()

		await get_tree().create_timer(1.2).timeout
		if era_final:
			mostrar_creditos()
		else:
			mostrar_victoria_en_escena(prestigio_ganado, fans_ganados)
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

	# CAMBIO: barra de HP del enemigo
	if enemigo_hp_bar != null and banda_enemiga.size() > 0:
		enemigo_hp_bar.max_value = banda_enemiga[0].hp_max
		tween_bar(enemigo_hp_bar, banda_enemiga[0].hp_actual)

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

	# CAMBIO: Crash Doom (baterista) cura 30 HP a TODA la banda en vez
	# de recuperar energía (su "redoble sanador").
	if personaje == crash_doom:
		turno_label.text = crash_doom.nombre + " ¡sana a toda la banda!"
		reproducir_anim(sprite_actual, "recuperar", 0.4)
		reproducir_sfx_ui(SFX_RECUPERAR)
		for i in range(banda_jugador.size()):
			var miembro = banda_jugador[i]
			if miembro.hp_actual <= 0:
				continue  # no revive caídos, solo cura vivos
			miembro.hp_actual = min(miembro.hp_actual + 30, miembro.hp_max)
			flash_dano(sprites_banda[i], Color(0.3, 1, 0.4))
			spawn_impact_particles(sprites_banda[i], Color(0.3, 1, 0.4))
			spawn_damage_number(sprites_banda[i], "+30 HP", Color(0.3, 1, 0.4))
		flash_pantalla(Color(0.3, 1, 0.4, 0.18), 0.3)
	else:
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


# CAMBIO (nuevo): muestra/oculta el botón de Golpe de Multitud según el
# Hype. Cuando está al 100%, la barra de Hype también pulsa.
func actualizar_boton_hype():
	var btn_hype = get_node_or_null("HUD/AccionesPanel/BtnHype")
	if btn_hype == null:
		return
	var lleno = hype >= 100 and turno_jugador and not accion_en_curso
	btn_hype.visible = lleno
	if lleno:
		if hype_bar.has_meta("pulso"):
			return  # ya está pulsando, no apilar otro tween
		var tw = create_tween()
		tw.set_loops()
		tw.tween_property(hype_bar, "modulate", Color(1.4, 1.0, 1.4), 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(hype_bar, "modulate", Color(1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
		hype_bar.set_meta("pulso", tw)
	else:
		if hype_bar.has_meta("pulso"):
			var tw = hype_bar.get_meta("pulso")
			if tw != null and tw.is_valid():
				tw.kill()
			hype_bar.remove_meta("pulso")
			hype_bar.modulate = Color(1, 1, 1)


# CAMBIO (nuevo): ultimate de la banda. Toda la banda golpea al enemigo
# de golpe, con FX grande, y consume todo el Hype.
func _on_golpe_multitud_pressed():
	if accion_en_curso or hype < 100:
		return
	accion_en_curso = true
	acciones_panel.visible = false
	var btn_hype = get_node_or_null("HUD/AccionesPanel/BtnHype")
	if btn_hype != null:
		btn_hype.visible = false

	var enemigo = banda_enemiga[0]
	var sprites_banda = [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]

	turno_label.text = "¡GOLPE DE MULTITUD!"
	reproducir_sfx_ui(SFX_VICTORIA)  # rugido/hype de la multitud
	mostrar_vineta(0.6, 0.5)

	# Cada miembro vivo dispara al enemigo en cadena
	var total = 0
	for i in range(banda_jugador.size()):
		if banda_jugador[i].hp_actual <= 0:
			continue
		var atacante = banda_jugador[i]
		var dano = 25 + atacante.tecnica
		total += dano
		reproducir_anim(sprites_banda[i], "ataque", 0.3)
		reproducir_sfx_ataque(i)
		await spawn_proyectil(sprites_banda[i], sprite_enemigo, color_venue(), 2)

	enemigo.hp_actual = max(enemigo.hp_actual - total, 0)

	# Impacto final gordo
	reproducir_sfx_impacto(SFX_IMPACTO_CRITICO, sprite_enemigo)
	reproducir_anim(sprite_enemigo, "dano", 0.4)
	await hit_stop(0.12, 0.03)
	flash_dano(sprite_enemigo, Color(1, 0.3, 1, 1))
	spawn_impact_particles(sprite_enemigo, color_venue())
	spawn_slash(sprite_enemigo, Color(1, 0.5, 1, 1), 5)
	mega_impacto(sprite_enemigo, Color(1, 0.4, 1), 5)
	spawn_damage_number(sprite_enemigo, "-" + str(total) + "!!", Color(1, 0.4, 1))
	squash_stretch(sprite_enemigo)
	knockback(sprite_enemigo, Vector2.RIGHT)
	shake_camera(0.5, 14.0)
	zoom_punch(0.4, 0.2)

	# Consumir el Hype
	hype = 0
	tween_bar(hype_bar, hype)
	actualizar_boton_hype()
	actualizar_stats()

	await get_tree().create_timer(1.2).timeout
	verificar_batalla()


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
			turno_label.text = "¡Carga de Adrenalina! El rival queda aturdido."
			reproducir_sfx_impacto(SFX_IMPACTO_CRITICO, sprite_enemigo)
			flash_dano(sprite_enemigo, Color(1, 0.9, 0.2, 1))
			spawn_impact_particles(sprite_enemigo, Color(1, 0.9, 0.2))
			spawn_damage_number(sprite_enemigo, "-" + str(cantidad_dano), Color(1, 0.9, 0.2))
			shake_camera(0.3, 8.0)
			# CAMBIO (nuevo): además, aturde al enemigo un turno.
			enemigo_aturdido = true
			spawn_damage_number(sprite_enemigo, "¡ATURDIDO!", Color(1, 0.85, 0.2))
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
	# CAMBIO: centrar el texto sobre el objetivo (antes crecía a la
	# derecha y se salía de cuadro con el enemigo pegado al borde).
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ancho_label = 320.0
	label.size = Vector2(ancho_label, 60)

	var capa = CanvasLayer.new()
	capa.layer = 60
	add_child(capa)
	capa.add_child(label)

	var pos_pantalla = target.get_global_transform_with_canvas().origin
	var viewport_size = get_viewport().get_visible_rect().size
	# Centrado horizontal sobre el objetivo, pero limitado para que no se
	# salga por ningún borde de la pantalla.
	var x = clamp(pos_pantalla.x - ancho_label / 2.0, 8.0, viewport_size.x - ancho_label - 8.0)
	label.position = Vector2(x, pos_pantalla.y - 110)

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

	if turno_spot != null:
		turno_spot.queue_free()
		turno_spot = null

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

	# CAMBIO (nuevo): spotlight/glow luminoso bajo los pies del personaje
	# activo. Va como hijo del sprite, en la parte inferior de su rect.
	var pies_y = 0.0
	if sprite_actual.has_method("get_rect"):
		pies_y = sprite_actual.get_rect().end.y
	var spot = Sprite2D.new()
	spot.name = "SpotTurno"
	var grad = Gradient.new()
	var c = color_venue()
	grad.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.6), Color(c.r, c.g, c.b, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gtex = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	spot.texture = gtex
	spot.scale = Vector2(0.9, 0.35)
	spot.position = Vector2(0, pies_y - 20)
	spot.z_index = -1
	sprite_actual.add_child(spot)
	turno_spot = spot

	var tw_spot = create_tween()
	tw_spot.set_loops()
	tw_spot.tween_property(spot, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
	tw_spot.tween_property(spot, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

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
# CAMBIO: ahora devuelve una CALIDAD ("perfect" / "good" / "miss") en
# vez de solo true/false. La barra tiene dos zonas concéntricas:
# GOOD (amplia, magenta) y PERFECT (angosta y brillante en el centro).
# Al presionar muestra un texto grande PERFECT!/GOOD!/MISS! con escala.
func mostrar_qte() -> String:
	qte_direccion = 1

	var capa = CanvasLayer.new()
	capa.layer = 70
	add_child(capa)

	var viewport_size = get_viewport().get_visible_rect().size
	var ancho_barra = 420.0
	var origen_barra = Vector2(viewport_size.x / 2.0 - ancho_barra / 2.0, viewport_size.y - 170)

	# Marco/fondo de la barra
	var marco = ColorRect.new()
	marco.color = Color(0, 0, 0, 0.7)
	marco.size = Vector2(ancho_barra + 8, 34)
	marco.position = origen_barra + Vector2(-4, -5)
	capa.add_child(marco)

	var fondo_barra = ColorRect.new()
	fondo_barra.color = Color(0.08, 0.08, 0.1, 0.9)
	fondo_barra.size = Vector2(ancho_barra, 24)
	fondo_barra.position = origen_barra
	capa.add_child(fondo_barra)

	# Zona GOOD (amplia)
	var ancho_good = 120.0
	var offset_good = randf_range(20, ancho_barra - 20 - ancho_good)
	var zona_good = ColorRect.new()
	zona_good.color = Color(0.9, 0.2, 0.8, 0.55)  # magenta
	zona_good.size = Vector2(ancho_good, 24)
	zona_good.position = origen_barra + Vector2(offset_good, 0)
	capa.add_child(zona_good)

	# Zona PERFECT (angosta, centrada dentro de GOOD, brillante)
	var ancho_perfect = 34.0
	var offset_perfect = offset_good + (ancho_good - ancho_perfect) / 2.0
	var zona_perfect = ColorRect.new()
	zona_perfect.color = Color(1, 0.95, 0.4, 0.95)  # dorado brillante
	zona_perfect.size = Vector2(ancho_perfect, 24)
	zona_perfect.position = origen_barra + Vector2(offset_perfect, 0)
	capa.add_child(zona_perfect)

	var marcador_visual = ColorRect.new()
	marcador_visual.color = Color(1, 1, 1, 1)
	marcador_visual.size = Vector2(5, 34)
	marcador_visual.position = origen_barra + Vector2(0, -5)
	capa.add_child(marcador_visual)

	var instrucciones = Label.new()
	instrucciones.text = "¡ESPACIO en el momento justo!"
	instrucciones.add_theme_font_size_override("font_size", 20)
	instrucciones.add_theme_color_override("font_color", Color(1, 1, 1))
	instrucciones.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	instrucciones.add_theme_constant_override("outline_size", 4)
	instrucciones.position = origen_barra + Vector2(0, -42)
	capa.add_child(instrucciones)

	var calidad = "miss"
	var tiempo_max = 2.5
	var t = 0.0
	var x_actual = 0.0

	while t < tiempo_max:
		var delta = get_process_delta_time()
		t += delta

		x_actual += qte_direccion * qte_velocidad * delta
		if x_actual <= 0:
			x_actual = 0
			qte_direccion = 1
		elif x_actual >= ancho_barra:
			x_actual = ancho_barra
			qte_direccion = -1

		marcador_visual.position.x = origen_barra.x + x_actual - 2

		if Input.is_action_just_pressed("ui_accept"):
			# Determinar calidad según dónde cayó el marcador
			if x_actual >= offset_perfect and x_actual <= offset_perfect + ancho_perfect:
				calidad = "perfect"
			elif x_actual >= offset_good and x_actual <= offset_good + ancho_good:
				calidad = "good"
			else:
				calidad = "miss"
			break

		await get_tree().process_frame

	# Texto grande de resultado con escala rápida
	var resultado = Label.new()
	match calidad:
		"perfect":
			resultado.text = "PERFECT!"
			resultado.add_theme_color_override("font_color", Color(1, 0.95, 0.3))
		"good":
			resultado.text = "GOOD!"
			resultado.add_theme_color_override("font_color", Color(1, 0.4, 0.9))
		_:
			resultado.text = "MISS!"
			resultado.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	resultado.add_theme_font_size_override("font_size", 64)
	resultado.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	resultado.add_theme_constant_override("outline_size", 8)
	resultado.position = Vector2(viewport_size.x / 2.0 - 120, viewport_size.y - 260)
	resultado.scale = Vector2(0.3, 0.3)
	resultado.pivot_offset = Vector2(120, 40)
	capa.add_child(resultado)

	var tw = create_tween()
	tw.tween_property(resultado, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(resultado, "scale", Vector2(1.0, 1.0), 0.08)

	await get_tree().create_timer(0.4).timeout
	capa.queue_free()
	return calidad


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


# ============================================================
# CAMBIO (nuevo): pantalla de victoria SOBRE el escenario. Oscurece el
# venue (no negro total), pone a la banda en pose de victoria, agrega
# reflectores desde atrás y muestra VICTORIA! + Prestigio + Fans con
# botones CONTINUAR / MENÚ.
# ============================================================
func mostrar_victoria_en_escena(prestigio_ganado: int, fans_ganados: int):
	var viewport_size = get_viewport().get_visible_rect().size

	# La banda a pose de victoria (usa "victoria" si existe, si no idle)
	for sprite in [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]:
		if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("victoria"):
				sprite.play("victoria")
			elif sprite.sprite_frames.has_animation("hype"):
				sprite.play("hype")

	var capa = CanvasLayer.new()
	capa.layer = 90
	capa.name = "VictoriaFX"
	add_child(capa)

	# Oscurecido parcial (escenario visible)
	var oscuro = ColorRect.new()
	oscuro.color = Color(0, 0, 0, 0.0)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(oscuro)
	var tw_osc = create_tween()
	tw_osc.tween_property(oscuro, "color", Color(0, 0, 0, 0.5), 0.5)

	# Reflectores brillantes desde arriba hacia la banda
	for i in range(3):
		var haz = Polygon2D.new()
		haz.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(-90, viewport_size.y * 0.8),
			Vector2(90, viewport_size.y * 0.8),
		])
		haz.color = [Color(1, 0.3, 0.85, 0.14), Color(0.4, 0.6, 1, 0.14), Color(1, 0.9, 0.4, 0.12)][i]
		haz.position = Vector2(viewport_size.x * (0.3 + 0.2 * i), 0)
		capa.add_child(haz)
		var tw_haz = create_tween()
		tw_haz.set_loops()
		tw_haz.tween_property(haz, "position:x", haz.position.x + 60, 2.0).set_trans(Tween.TRANS_SINE)
		tw_haz.tween_property(haz, "position:x", haz.position.x - 60, 2.0).set_trans(Tween.TRANS_SINE)

	# Panel central: CenterContainer de pantalla completa para centrar
	# de forma confiable (evita que el texto se salga de la pantalla).
	var centrador = CenterContainer.new()
	centrador.set_anchors_preset(Control.PRESET_FULL_RECT)
	centrador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(centrador)

	var panel = VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_constant_override("separation", 10)
	centrador.add_child(panel)

	var titulo = Label.new()
	titulo.text = "¡VICTORIA!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	titulo.add_theme_constant_override("outline_size", 10)
	panel.add_child(titulo)

	var l_prestigio = Label.new()
	l_prestigio.text = "+" + str(prestigio_ganado) + " Prestigio"
	l_prestigio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_prestigio.add_theme_font_size_override("font_size", 28)
	l_prestigio.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	l_prestigio.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l_prestigio.add_theme_constant_override("outline_size", 5)
	panel.add_child(l_prestigio)

	var l_fans = Label.new()
	l_fans.text = "+" + str(fans_ganados) + " Fans"
	l_fans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_fans.add_theme_font_size_override("font_size", 28)
	l_fans.add_theme_color_override("font_color", Color(1, 0.4, 0.9))
	l_fans.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l_fans.add_theme_constant_override("outline_size", 5)
	panel.add_child(l_fans)

	var espacio = Control.new()
	espacio.custom_minimum_size = Vector2(0, 20)
	panel.add_child(espacio)

	var btn_continuar = Button.new()
	btn_continuar.text = "▶  CONTINUAR"
	btn_continuar.custom_minimum_size = Vector2(300, 54)
	_estilizar_boton_bb(btn_continuar)
	btn_continuar.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	)
	panel.add_child(btn_continuar)

	var btn_menu = Button.new()
	btn_menu.text = "MENÚ PRINCIPAL"
	btn_menu.custom_minimum_size = Vector2(300, 46)
	_estilizar_boton_bb(btn_menu)
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	panel.add_child(btn_menu)

	# Entrada del título con escala (espera un frame para que el layout
	# calcule el tamaño real y el pivote quede centrado).
	await get_tree().process_frame
	titulo.pivot_offset = titulo.size / 2.0
	titulo.scale = Vector2(0.2, 0.2)
	var tw_tit = create_tween()
	tw_tit.tween_property(titulo, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_tit.tween_property(titulo, "scale", Vector2(1.0, 1.0), 0.15)


# CAMBIO (nuevo): anuncio grande del turno que entra desde un lado,
# se planta un instante con un destello y sale. Sonido incluido.
func anunciar_turno(nombre: String):
	reproducir_sfx_ui(SFX_CAMBIO_TURNO)

	var viewport_size = get_viewport().get_visible_rect().size
	var capa = CanvasLayer.new()
	capa.layer = 75
	add_child(capa)

	# franja de destello detrás del texto
	var franja = ColorRect.new()
	var c = color_venue()
	franja.color = Color(c.r, c.g, c.b, 0.0)
	franja.size = Vector2(viewport_size.x, 70)
	franja.position = Vector2(0, viewport_size.y * 0.30)
	capa.add_child(franja)

	var etiqueta = Label.new()
	etiqueta.text = nombre.to_upper()
	etiqueta.add_theme_font_size_override("font_size", 46)
	etiqueta.add_theme_color_override("font_color", Color(1, 1, 1))
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	etiqueta.add_theme_constant_override("outline_size", 7)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.size = Vector2(viewport_size.x, 70)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.position = Vector2(-viewport_size.x, viewport_size.y * 0.30)
	capa.add_child(etiqueta)

	var tween = create_tween()
	# entra deslizando
	tween.tween_property(etiqueta, "position:x", 0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(franja, "color", Color(c.r, c.g, c.b, 0.35), 0.2)
	# destello y se mantiene
	tween.tween_interval(0.5)
	# sale
	tween.tween_property(etiqueta, "position:x", viewport_size.x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(franja, "color", Color(c.r, c.g, c.b, 0.0), 0.25)
	tween.tween_callback(capa.queue_free)


# CAMBIO (nuevo): proyectil que viaja del atacante al enemigo antes del
# impacto. Es un punto brillante con estela; 'cantidad' repite el disparo.
func spawn_proyectil(origen: Node2D, destino: Node2D, color: Color = Color(1, 0.5, 0.2), cantidad: int = 1):
	if origen == null or destino == null:
		return

	var capa = get_node_or_null("ProyectilFX")
	if capa == null:
		capa = Node2D.new()
		capa.name = "ProyectilFX"
		add_child(capa)

	var pos_origen = origen.global_position + Vector2(0, -120)
	var pos_destino = destino.global_position + Vector2(0, -100)

	for i in range(cantidad):
		var bala = Sprite2D.new()
		var grad = Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(color.r, color.g, color.b, 0.0)])
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		var gtex = GradientTexture2D.new()
		gtex.gradient = grad
		gtex.fill = GradientTexture2D.FILL_RADIAL
		gtex.fill_from = Vector2(0.5, 0.5)
		gtex.fill_to = Vector2(1.0, 0.5)
		gtex.width = 48
		gtex.height = 48
		bala.texture = gtex
		bala.scale = Vector2(0.9, 0.9)
		bala.z_index = 40
		bala.global_position = pos_origen
		capa.add_child(bala)

		var tween = create_tween()
		tween.tween_property(bala, "global_position", pos_destino, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(bala.queue_free)

		if i < cantidad - 1:
			await get_tree().create_timer(0.06).timeout

	await get_tree().create_timer(0.18).timeout


# ============================================================
# CAMBIO (nuevo): FX de ataque variados. Cada integrante de la banda
# tiene su propio efecto (dispatch por índice), más 3 primitivas
# reutilizables: onda de choque, rayo y ondas de sonido.
# ============================================================

# Textura de anillo (ring) generada por código, para shockwaves/ondas.
func _ring_texture(color: Color) -> GradientTexture2D:
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, 0.0),
		Color(1, 1, 1, 0.9),
		Color(color.r, color.g, color.b, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
	var t = GradientTexture2D.new()
	t.gradient = grad
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# Dispatch: elige el FX según qué integrante ataca.
func fx_ataque_personaje(indice: int, origen: Node2D, destino: Node2D):
	match indice:
		0:  # Crow Storm - vocalista → ondas de sonido
			await spawn_ondas_sonido(origen, destino, Color(1, 0.4, 0.9))
		1:  # Blaze Inferno - guitarrista → rayo
			spawn_rayo(origen, destino, Color(1, 0.9, 0.3))
			await get_tree().create_timer(0.18).timeout
		2:  # Rex Thunder - bajista → onda de choque azul
			await spawn_proyectil(origen, destino, Color(0.3, 0.6, 1))
			spawn_shockwave(destino, Color(0.3, 0.6, 1))
		3:  # Crash Doom - baterista → onda de choque naranja doble
			await spawn_proyectil(origen, destino, Color(1, 0.5, 0.2))
			spawn_shockwave(destino, Color(1, 0.5, 0.2))
		_:
			await spawn_proyectil(origen, destino, color_venue())


# CAMBIO (nuevo): flash de pantalla completa breve (para dar "punch"
# visual a los golpes fuertes). color con alpha bajo (~0.15-0.25).
func flash_pantalla(color: Color = Color(1, 1, 1, 0.2), duracion: float = 0.25):
	var capa = CanvasLayer.new()
	capa.layer = 68
	add_child(capa)
	var rect = ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(rect)
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duracion)
	tween.tween_callback(capa.queue_free)


# CAMBIO (nuevo): "mega impacto" — varios anillos de choque escalonados
# + partículas extra + destello. Para máximo show en golpes fuertes.
func mega_impacto(target: Node2D, color: Color = Color(1, 0.5, 0.2), anillos: int = 3):
	if target == null:
		return
	for i in range(anillos):
		spawn_shockwave(target, color)
		spawn_impact_particles(target, color)
		await get_tree().create_timer(0.07).timeout
	flash_pantalla(Color(color.r, color.g, color.b, 0.15), 0.2)


# Onda de choque: anillo que se expande y se desvanece sobre el objetivo.
func spawn_shockwave(target: Node2D, color: Color = Color(1, 1, 1)):
	if target == null:
		return
	var ring = Sprite2D.new()
	ring.texture = _ring_texture(color)
	ring.global_position = target.global_position + Vector2(0, -100)
	ring.scale = Vector2(0.2, 0.2)
	ring.z_index = 45
	add_child(ring)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)


# Rayo: línea en zigzag entre atacante y objetivo, con destello.
func spawn_rayo(origen: Node2D, destino: Node2D, color: Color = Color(1, 0.9, 0.3)):
	if origen == null or destino == null:
		return
	var p0 = origen.global_position + Vector2(0, -120)
	var p1 = destino.global_position + Vector2(0, -100)

	var linea = Line2D.new()
	linea.width = 5.0
	linea.default_color = color
	linea.z_index = 46
	var pasos = 8
	for i in range(pasos + 1):
		var tt = float(i) / pasos
		var punto = p0.lerp(p1, tt)
		if i != 0 and i != pasos:
			var perp = (p1 - p0).orthogonal().normalized()
			punto += perp * randf_range(-22, 22)
		linea.add_point(punto)
	add_child(linea)

	# destello blanco breve
	var flash = Line2D.new()
	flash.width = 10.0
	flash.default_color = Color(1, 1, 1, 0.7)
	flash.z_index = 45
	for p in linea.points:
		flash.add_point(p)
	add_child(flash)

	var tween = create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(linea, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(linea.queue_free)
	tween.tween_callback(flash.queue_free)


# Ondas de sonido: varios anillos que viajan del músico al enemigo.
func spawn_ondas_sonido(origen: Node2D, destino: Node2D, color: Color = Color(1, 0.4, 0.9)):
	if origen == null or destino == null:
		return
	var p0 = origen.global_position + Vector2(0, -110)
	var p1 = destino.global_position + Vector2(0, -100)

	for i in range(3):
		var onda = Sprite2D.new()
		onda.texture = _ring_texture(color)
		onda.global_position = p0
		onda.scale = Vector2(0.4, 0.4)
		onda.z_index = 44
		add_child(onda)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(onda, "global_position", p1, 0.3)
		tween.tween_property(onda, "scale", Vector2(1.1, 1.1), 0.3)
		tween.chain().tween_property(onda, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(onda.queue_free)
		await get_tree().create_timer(0.08).timeout

	await get_tree().create_timer(0.15).timeout


# CAMBIO (nuevo): estado visual del enemigo derrotado. Usa la animación
# "derrota" si existe; si no, lo tiñe oscuro, lo inclina y lo desvanece.
func enemigo_derrotado_visual():
	if sprite_enemigo == null:
		return
	if sprite_enemigo is AnimatedSprite2D and sprite_enemigo.sprite_frames != null and sprite_enemigo.sprite_frames.has_animation("derrota"):
		sprite_enemigo.play("derrota")
		return
	# Fallback sin animación: cae y se apaga
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_enemigo, "modulate", Color(0.4, 0.4, 0.5, 0.5), 0.6)
	tween.tween_property(sprite_enemigo, "rotation", 0.4, 0.6).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite_enemigo, "position:y", sprite_enemigo.position.y + 40, 0.6).set_trans(Tween.TRANS_QUAD)


# CAMBIO (nuevo): estilo Battle Bands para botones (panel oscuro, borde
# magenta, texto blanco). Reusa esto en otros botones que quieras.
# ============================================================
# CAMBIO (nuevo): pantalla de CRÉDITOS al derrotar al jefe final
# (nivel 5). Escenario oscurecido + reflectores, texto que sube tipo
# créditos, y al final botón a menú. Reinicia el progreso a nivel 1.
# ============================================================
func mostrar_creditos():
	var viewport_size = get_viewport().get_visible_rect().size

	# Banda a pose de victoria
	for sprite in [sprite_crow, sprite_blaze, sprite_rex, sprite_crash]:
		if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("victoria"):
				sprite.play("victoria")
			elif sprite.sprite_frames.has_animation("hype"):
				sprite.play("hype")

	var capa = CanvasLayer.new()
	capa.layer = 95
	capa.name = "CreditosFX"
	add_child(capa)

	var oscuro = ColorRect.new()
	oscuro.color = Color(0, 0, 0, 0.0)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(oscuro)
	var tw_osc = create_tween()
	tw_osc.tween_property(oscuro, "color", Color(0, 0, 0, 0.75), 1.0)

	# Texto de créditos que sube
	var texto = Label.new()
	texto.text = "\n\n\n¡CAMPEONES!\n\nBATTLE BANDS\n\n\nLa banda conquistó\ntodos los escenarios.\n\n\n— ALINEACIÓN —\n\nCrow Storm — Voz\nBlaze Inferno — Guitarra\nRex Thunder — Bajo\nCrash Doom — Batería\n\n\n\nGracias por jugar\n\n\n\n UNIVERSIDAD TECNOLOGICA DE CIUDAD JUAREZ\nRUTH RODRIGUEZ\nFRANSISCO DE LA CRUZ\nLEONEL ACOSTA"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 34)
	texto.add_theme_color_override("font_color", Color(1, 1, 1))
	texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	texto.add_theme_constant_override("outline_size", 6)
	texto.size = Vector2(viewport_size.x, 900)
	texto.position = Vector2(0, viewport_size.y + 40)
	capa.add_child(texto)

	# Reflectores
	for i in range(3):
		var haz = Polygon2D.new()
		haz.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(-80, viewport_size.y), Vector2(80, viewport_size.y)])
		haz.color = [Color(1, 0.3, 0.85, 0.12), Color(0.4, 0.6, 1, 0.12), Color(1, 0.9, 0.4, 0.10)][i]
		haz.position = Vector2(viewport_size.x * (0.3 + 0.2 * i), 0)
		capa.add_child(haz)

	var tween = create_tween()
	tween.tween_property(texto, "position:y", -900.0, 12.0).set_trans(Tween.TRANS_LINEAR)

	# Botones al final (aparecen tras los créditos)
	var caja_btns = HBoxContainer.new()
	caja_btns.add_theme_constant_override("separation", 20)
	caja_btns.position = Vector2(viewport_size.x / 2.0 - 315, viewport_size.y - 90)
	caja_btns.modulate.a = 0.0
	capa.add_child(caja_btns)

	var btn_jugar = Button.new()
	btn_jugar.text = "🔁 JUGAR DE NUEVO"
	btn_jugar.custom_minimum_size = Vector2(300, 54)
	_estilizar_boton_bb(btn_jugar)
	btn_jugar.pressed.connect(func():
		reiniciar_juego()
		get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	)
	caja_btns.add_child(btn_jugar)

	var btn_menu = Button.new()
	btn_menu.text = "VOLVER AL MENÚ"
	btn_menu.custom_minimum_size = Vector2(300, 54)
	_estilizar_boton_bb(btn_menu)
	btn_menu.pressed.connect(func():
		reiniciar_juego()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	caja_btns.add_child(btn_menu)

	await get_tree().create_timer(4.0).timeout
	var tw_btn = create_tween()
	tw_btn.tween_property(caja_btns, "modulate:a", 1.0, 0.6)


# CAMBIO (nuevo): reinicia el progreso del juego a estado inicial.
# Borra nivel, prestigio, mejoras e inventario. Úsalo al terminar el
# juego o si quieres un botón de "reiniciar" en el menú.
func reiniciar_juego():
	GameData.nivel_actual = 1
	GameData.prestigio = 0
	GameData.mejoras_compradas = []
	GameData.inventario = {}
	GameData.guardar()


func _estilizar_boton_bb(btn: Button):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.85, 0.2, 0.8)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6

	var hover = normal.duplicate()
	hover.bg_color = Color(0.15, 0.06, 0.16, 0.98)
	hover.border_color = Color(1, 0.4, 0.95)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 1))
	btn.add_theme_font_size_override("font_size", 22)
