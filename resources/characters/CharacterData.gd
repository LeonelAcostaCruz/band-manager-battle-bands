# resources/CharacterData.gd
class_name CharacterData
extends Resource

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

# ← ESTA ES LA LÍNEA QUE FALTA
@export var habilidades: Array[SkillData] = []
