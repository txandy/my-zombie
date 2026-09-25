class_name CombatTree
## Behavior tree del estado de Combate (GDD §11.2), construido por código para poder
## testearlo en headless. Selector dinámico, en orden de prioridad:
##   1. Objetivo perdido -> evento "target_lost" (pasa a búsqueda).
##   2. Malherido y con medicinas -> evento "retreat".
##   3. Recargar a cubierto si le quedan pocas balas.
##   4. Buscar cobertura, correr a ella y pelear desde ella (asomarse / esconderse).
##   5. Sin cobertura: pelear en campo abierto, agachado.

const DispatchTask := preload("res://src/ai/human/brain/tasks/task_dispatch.gd")
const TargetLost := preload("res://src/ai/human/brain/tasks/cond_target_lost.gd")
const ShouldRetreat := preload("res://src/ai/human/brain/tasks/cond_should_retreat.gd")
const ReloadInCover := preload("res://src/ai/human/brain/tasks/task_reload_in_cover.gd")
const TakeCover := preload("res://src/ai/human/brain/tasks/task_take_cover.gd")
const FightFromCover := preload("res://src/ai/human/brain/tasks/task_fight_from_cover.gd")
const FightInOpen := preload("res://src/ai/human/brain/tasks/task_fight_in_open.gd")


static func build() -> BehaviorTree:
	# Dinámico: reevalúa las prioridades cada tick (un BTSelector se quedaría en la rama RUNNING).
	var root := BTDynamicSelector.new()
	root.add_child(_sequence([TargetLost.new(), _dispatch(&"target_lost")]))
	root.add_child(_sequence([ShouldRetreat.new(), _dispatch(&"retreat")]))
	root.add_child(ReloadInCover.new())
	root.add_child(_sequence([TakeCover.new(), FightFromCover.new()]))
	root.add_child(FightInOpen.new())
	var tree := BehaviorTree.new()
	tree.root_task = root
	return tree


static func _sequence(tasks: Array[BTTask]) -> BTSequence:
	var sequence := BTSequence.new()
	for task: BTTask in tasks:
		sequence.add_child(task)
	return sequence


static func _dispatch(event: StringName) -> BTTask:
	var task: BTTask = DispatchTask.new()
	task.set(&"event", event)
	return task
