# resources/SkillData.gd
class_name SkillData
extends Resource

@export var nombre: String = ""
@export var descripcion: String = ""
@export var costo_energia: int = 20
@export var dano_base: int = 30

# Tipos: "ataque", "buff", "recuperar", "critico"
@export var tipo: String = "ataque"
