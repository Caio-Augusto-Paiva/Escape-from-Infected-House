extends Node3D

# --- CONFIGURAÇÕES DE SPAWN ---
@export var cena_zumbi: PackedScene = preload("res://cenas/zumbi.tscn")
@export var spawn_ativo: bool = false # Define se o spawner começa ligado ou desligado
@export var quantidade_inicial: int = 3
@export var quantidade_maxima: int = 10
@export var usar_spawn_contínuo: bool = true
@export var tempo_spawn: float = 5.0

# --- REFERÊNCIAS ---
# Arraste o nó CollisionShape3D que você criou para esta variável no Inspector
@export var area_spawn: CollisionShape3D 

# --- CONFIGURAÇÕES DE ZUMBI ---
@export var velocidade_zumbi: float = 2.0
@export var dano_zumbi: int = 15
@export var vida_zumbi: int = 100
@export var distancia_ataque: float = 1.0

# --- CONTROLE INTERNO ---
var zumbis_vivos: Array = []
var tempo_proximo_spawn: float = 0.0

func _ready():
	add_to_group("Spawners")
	# Verifica se a área foi definida para evitar erros
	if not area_spawn:
		push_warning("ATENÇÃO: 'area_spawn' não foi definida no Spawner de Zumbis!")
	
	if spawn_ativo:
		for i in range(quantidade_inicial):
			spawn_zumbi()

func _physics_process(delta):
	zumbis_vivos = zumbis_vivos.filter(func(z): return is_instance_valid(z))
	
	if spawn_ativo and usar_spawn_contínuo and zumbis_vivos.size() < quantidade_maxima:
		tempo_proximo_spawn -= delta
		if tempo_proximo_spawn <= 0:
			spawn_zumbi()
			tempo_proximo_spawn = tempo_spawn

func spawn_zumbi():
	if zumbis_vivos.size() >= quantidade_maxima:
		return
	
	var novo_zumbi = cena_zumbi.instantiate()
	
	# --- NOVA LÓGICA DE POSIÇÃO ---
	# Define a posição antes de adicionar à cena
	novo_zumbi.position = obter_posicao_aleatoria()
	
	# Aplica configurações
	if "velocidade" in novo_zumbi: novo_zumbi.velocidade = velocidade_zumbi
	if "dano_ataque" in novo_zumbi: novo_zumbi.dano_ataque = dano_zumbi
	if "vida" in novo_zumbi: novo_zumbi.vida = vida_zumbi
	if "distancia_ataque" in novo_zumbi: novo_zumbi.distancia_ataque = distancia_ataque
	
	add_child(novo_zumbi)
	zumbis_vivos.append(novo_zumbi)

func ativar_modo_horda():
	print("MODO HORDA ATIVADO! CORRA!")
	spawn_ativo = true
	quantidade_maxima = 50  # Limite maior
	tempo_spawn = 0.5       # Spawna muito rápido (2 por segundo)
	usar_spawn_contínuo = true
	tempo_proximo_spawn = 0 # Começa agora

# Função auxiliar para calcular ponto dentro da BoxShape
func obter_posicao_aleatoria() -> Vector3:
	# Se não houver área definida, spawna no centro do Spawner (0,0,0)
	if not area_spawn or not area_spawn.shape:
		return Vector3.ZERO
		
	# Assume que é um BoxShape3D
	var shape = area_spawn.shape
	if shape is BoxShape3D:
		var tamanho = shape.size
		
		# Calcula offsets aleatórios baseados na metade do tamanho (centro é 0,0,0 local)
		var x = randf_range(-tamanho.x / 2, tamanho.x / 2)
		# Se quiser que eles spawnem no chão, mantenha Y fixo ou use range pequeno
		var y = 0.0 # Pode mudar para: randf_range(-tamanho.y / 2, tamanho.y / 2) se for área aérea
		var z = randf_range(-tamanho.z / 2, tamanho.z / 2)
		
		# Pega a posição aleatória local
		var pos_local = Vector3(x, y, z)
		
		# Converte a posição local da caixa para a posição relativa ao Spawner
		# Isso permite que você mova/gire o CollisionShape e o spawn acompanhe
		return area_spawn.position + pos_local
		
	return Vector3.ZERO
