tool
extends EditorPlugin

var control = preload("res://addons/gitaddon2/main/Main.tscn")
var gittab

func _enter_tree():
	gittab = control.instance()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, gittab)
	#get_editor_interface().get_file_system_dock().add_child(dock)
	#get_editor_interface().get_file_system_dock().add_control(gittab)
	
func _exit_tree():
	remove_control_from_docks(gittab)
	gittab.free()
