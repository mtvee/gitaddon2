tool
extends Control

# TODO
# - handle merge conflicts properly, instead of doing nothing?
# - hook up stage selected

export var debug: bool = true

# temp file for git commit message
const tmp_filename = "gitcommit.txt"
# system command to run
var git_command = "git"
# output from the exec command
var output = []
# message box
var popup

# icons
onready var status_changed = load("res://addons/gitaddon2/assets/check-18.png")
onready var status_untracked = load("res://addons/gitaddon2/assets/plus-18.png")
onready var status_deleted = load("res://addons/gitaddon2/assets/zap-18.png")
onready var status_added = load("res://addons/gitaddon2/assets/check-18.png")

# controls
onready var clist = $MarginContainer/Layout/VSplitContainer/VBoxContainer2/ChangedList
onready var slist = $MarginContainer/Layout/VSplitContainer/VBoxContainer/StagedList
onready var ctext = $MarginContainer/Layout/TextEdit


func _ready():
	if OS.get_name() == 'Windows':
		git_command = "git.exe"
	popup = AcceptDialog.new()
	add_child(popup)
	update_ui()

# show the alert with a messge
func show_error(msg):
	popup.dialog_text = msg
	popup.popup_centered()

func ask_if_wants_init():
	$ConfirmationDialog.dialog_text = """
	%s\n
	Do you want to initialize Git?
	""" % output[0]
	$ConfirmationDialog.popup_centered()

# run git command
# NOTE: this command just globs stdout and stderr in one pile
func run_command(args) -> bool:
	output = []
	var exit_code = OS.execute(git_command, args, true, output, true)
	output = output[0].split("\n")
	if debug:
		print(">>>> " + git_command + " " + PoolStringArray(args).join(" "))
		for line in output:
			print(line)
		print("git<<<<")
	if exit_code != 0:
		for line in output:
			if line.begins_with('fatal:'):
				if line.begins_with('fatal: not a git repository'):
					ask_if_wants_init()
					return false
				show_error(line)
				return false			
	return true

# append to some list
func append_to_list(list, text, color, icon, meta):
	list.add_item(text, icon)
	var cnt = list.get_item_count()
	list.set_item_custom_fg_color(cnt-1, color)
	list.set_item_metadata(cnt-1, meta)

# toggle enable	on various buttons based on list status
func update_ui():
	# status list empty
	if clist.get_item_count() == 0:
		$MarginContainer/Layout/VSplitContainer/VBoxContainer2/HBoxContainer/StageAll.disabled = true
	else:
		$MarginContainer/Layout/VSplitContainer/VBoxContainer2/HBoxContainer/StageAll.disabled = false
	# staged list empty	
	if slist.get_item_count() == 0:
		$MarginContainer/Layout/HBoxContainer2/Commit.disabled = true
	else:
		$MarginContainer/Layout/HBoxContainer2/Commit.disabled = false
	
	var i = clist.get_selected_items()
	if len(i) > 0:
		$MarginContainer/Layout/VSplitContainer/VBoxContainer2/HBoxContainer/StageSelected.disabled = false
	else:
		$MarginContainer/Layout/VSplitContainer/VBoxContainer2/HBoxContainer/StageSelected.disabled = true
			
	
# fill status clist	
func _on_Status_pressed():
	if not run_command(['status', '--porcelain']):
		return
	slist.clear()
	clist.clear()
	for line in output:
		if len(line) == 0:
			continue
		var code = line.substr(0,2)
		var fname = line.substr(3, len(line)-3)	
		if code == ' M':
			append_to_list(clist, fname, Color.green, status_changed, 'M' )
		if code == '??':
			append_to_list(clist, fname, Color.yellow, status_untracked, '?' )
		if code == 'A ':
			append_to_list(clist, fname, Color.cyan, status_added, 'A' )
		if code == 'D ':
			append_to_list(clist, fname, Color.gray, status_deleted, 'D' )
			
	if run_command(['rev-parse', '--abbrev-ref', 'HEAD']):
		$MarginContainer/Layout/HBoxContainer2/Branch.text = output[0]		
	update_ui()

# run the commit command	
func _on_Commit_pressed():
	print('foo')
	var msg = ''
	var cnt = ctext.get_line_count()
	if cnt == 1 and ctext.get_line(0) == '':
		show_error("No commit message")
		return
	for i in range(cnt):
		msg = msg + ctext.get_line(i) + "\n"
	var tmp = File.new()
	tmp.open(tmp_filename, File.WRITE)
	tmp.store_line(msg)
	tmp.close()
	var dir = Directory.new()
	run_command(['commit', '-a', '-F', tmp_filename])
	dir.remove(tmp_filename)
	_on_Status_pressed()	

# add files, if they are untracked, and move to the staged list slist
func _on_StageAll_pressed():
	slist.clear()
	while clist.get_item_count() > 0:
		if clist.get_item_metadata(0) == '?':
			run_command(['add', clist.get_item_text(0)])
			clist.set_item_metadata(0, 'A')
			clist.set_item_custom_fg_color(0, Color.cyan)
			clist.set_item_icon(0, status_added)
		append_to_list(slist, clist.get_item_text(0), clist.get_item_custom_fg_color(0), clist.get_item_icon(0), clist.get_item_metadata(0))
		clist.remove_item(0)
	clist.clear()
	update_ui()

# try and push
func _on_Push_pressed():
	run_command(['push', '--porcelain'])

# TODO: break this into fetch->merge ??? or at lest report conflicts
# try and fetch	
func _on_Fetch_pressed():
	run_command(['pull'])

# user wants to git init
func _on_ConfirmationDialog_confirmed():
	$FileDialog.popup_centered()

# user picked a directory	
func _on_FileDialog_dir_selected(dir):
	if not run_command(['init', dir]):
		return
	var d = Directory.new()
	# check for .gitignore and if not found use the template and create one
	if not d.file_exists(dir + "/.gitignore"):
		var f = File.new()
		if f.file_exists("res://addons/gitaddon2/settings/gitignore.txt"):
			f.open("res://addons/gitaddon2/settings/gitignore.txt", File.READ)
			var data = f.get_as_text()
			f.close()
			var of = File.new()
			if of.open(dir + "/.gitignore", File.WRITE) == OK:
				of.store_string(data)
				of.close()
	show_error(output[0])

# stage selected items
func _on_StageSelected_pressed():
	var items = clist.get_selected_items()
	if len(items) == 0:
		return
	for i in items:
		if clist.get_item_metadata(i) == '?':
			run_command(['add', clist.get_item_text(i)])
			clist.set_item_metadata(0, 'A')
			clist.set_item_custom_fg_color(i, Color.cyan)
			clist.set_item_icon(i, status_added)
		append_to_list(slist, clist.get_item_text(i), clist.get_item_custom_fg_color(i), clist.get_item_icon(i), clist.get_item_metadata(i))
	for i in items:
		clist.remove_item(i)
	update_ui()		

# an item was selected
func _on_ChangedList_item_selected(index):
	update_ui()

# an item was selected
func _on_ChangedList_multi_selected(index, selected):
	update_ui()
