# resources/CharacterData.gd
class_name CharacterData
extends Resource

@export var sprite_path: String = ""
# CAMBIO (nuevo): ruta a un SpriteFrames guardado (.tres) para enemigos
# animados. Si está vacío, se usa sprite_path como textura estática.
@export var frames_path: String = ""
@export var nombre: String = ""
@export var rol: String = ""
@export var hp_max: int = 100
@export var hp_actual: int = 100
@export var energia_max: int = 100
@export var energia_actual: int = 100
@export var carisma: int = 10
@export var tecnica: int = 10
@export var ritmo: int = 10
@export var velocidad: int = 10
@export var resistencia: int = 10
@export var habilidades: Array[SkillData] = []
