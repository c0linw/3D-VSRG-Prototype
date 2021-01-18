extends Spatial

var note_obj = preload("res://Note_Tap.tscn")
var note_flick_obj = preload("res://Note_Flick.tscn")
var note_slide_start_obj = preload("res://Note_Slide_Start.tscn")
var note_slide_end_obj = preload("res://Note_Slide_End.tscn")
var note_slide_flick_obj = preload("res://Note_Slide_Flick.tscn")
var note_slide_tick_obj = preload("res://Note_Slide_Tick.tscn")
var note_hold_start_obj = preload("res://Note_Hold_Start.tscn")
var note_hold_end_obj = preload("res://Note_Hold_End.tscn")
var note_hold_flick_obj = preload("res://Note_Hold_Flick.tscn")
var sliderbody = preload("res://SliderBody.tscn")
var perfect_plus_graphic = preload("res://Perfect_Plus.tscn")
var perfect_graphic = preload("res://Perfect.tscn")
var great_graphic = preload("res://Great.tscn")
var miss_graphic = preload("res://Miss.tscn")

# var audio_file = "res://Songs/Fortnite/fortnite.ogg"
# var audio_file = "res://Songs/Bon Appetit S/bonappetit.ogg"
# var audio_file = "res://Songs/Unite! From A to Z/bgm125.wav"
# var audio_file = "res://Songs/Dantalion/dantalion.wav"
var audio_file = "res://Songs/Roku Chounen to Ichiya Monogatari/bgm128.wav"
var audio
# var chart_file = "res://Songs/Ringing Bloom/ringingbloom.json"
# var chart_file = "res://Songs/Fortnite/fortnite.json"
# var chart_file = "res://Songs/Bon Appetit S/bonappetit.json"
# var chart_file = "res://Songs/Unite! From A to Z/etuze.json"
# var chart_file = "res://Songs/Dantalion/dantalion.json"
var chart_file = "res://Songs/Roku Chounen to Ichiya Monogatari/roku_holds.json"
var chart

var offset_option = 0.080
var note_speed = 10.5
var lane_length = 12.0
var note_screen_time
var note_units_per_sec

var notes_to_spawn = []
var scrollmod_list = []
var onscreen_notes = []
var onscreen_slides = []
var touch_bindings = [] # stores dicts that contain the note type and its lane/slide_pos (depending on type)

var scrollmod = 1.0
var last_timestamp = 0.0
var chart_timestamp = 0.0

# at 2164 x 1080 resolution:
# lane is 1522 pixels wide (at the top of judgement line) - half of that is 761
	# 1522/7 = 217.4285. Since the middle is wider, let's use 218 for lane width.
	# exact lane width is 0.20 * screen height
# lane is 864 pixels from the top of the screen (to the top of the judgement line) - that's 80% of the height.
var lane_hitboxes = []

# Array of arrays of note results. Each inner array stores the hit error of the notes for a given judgement category.
# for example, PERFECT+ judgements are stored in judge_results[0] and might look like [0.004, -0.020, 0.015, ...]
var judge_results = [[],[],[],[]] 

# Called when the node enters the scene tree for the first time.
func _ready():
	var view_coords = get_viewport().size
	for i in range(0,7):
		# exact horizontal hitbox for each lane is 0.2 * height (and then with a half-lane leniency on each side)
		# vertical hitbox spans the lower 40% of the screen
		lane_hitboxes.append([view_coords[0]/2 + view_coords[1]*0.2*(i-3.5) - view_coords[1]*0.1, 
							view_coords[0]/2 + view_coords[1]*0.2*(i-2.5) + view_coords[1]*0.1, 
							view_coords[1]*0.6, 
							view_coords[1]]) 
	for i in range(0,20):
		touch_bindings.append(null)
	
	note_screen_time = (12.0 - note_speed) / 2.0
	note_units_per_sec = lane_length/note_screen_time
	audio = load(audio_file)
	chart = load_chart(chart_file)
	$Conductor.stream = audio
	process_notes()
	$Conductor.volume_db = -10.0
	$Conductor.play_from_beat(0, 0)
	
func _input(event):
	if event is InputEventScreenTouch:
		$Conductor.update_song_position()
		var event_time = $Conductor.song_position
		if event.pressed == true: # tap input
			for note in onscreen_notes:
				if note.can_judge(event_time) && is_in_lane(event.position, note.lane):
					if note.type == "tap":
						# judge() returns [judgement type, hit error]
						var judgement = note.judge(event_time)
						# add the hit error to the corresponding sub-array
						judge_results[judgement[0]].append(judgement[1])
						draw_judgement(judgement, note.lane)
						delete_note(note)
					elif note.type == "hold_start" || note.type == "slide_start":
						# judge() returns [judgement type, hit error]
						var judgement = note.judge(event_time)
						# add the hit error to the corresponding sub-array
						judge_results[judgement[0]].append(judgement[1])
						draw_judgement(judgement, note.lane)
						touch_bindings[event.index] = note
						note.held = true
		else: # check hold ends and slide ends
			var end_reached = false
			for note in onscreen_notes:
				# TODO: check that the index is correct
				if (note.type == "hold_end" || note.type == "slide_end") && is_in_lane(event.position, note.lane) && note.can_judge(event_time):
					# judge() returns [judgement type, hit error]
					var judgement = note.judge(event_time)
					# add the hit error to the corresponding sub-array
					judge_results[judgement[0]].append(judgement[1])
					draw_judgement(judgement, note.lane)
					delete_note(note)
					end_reached = true
					break
			# TODO: change it so that touch binding note is unconditionally deleted upon release
			if touch_bindings[event.index] != null: # we released but did not hit any hold end, and also currently holding a note
				var note = touch_bindings[event.index]
				if !end_reached:
					# delete corressponding end to currently held note
					delete_end(note)
				delete_note(note)
			touch_bindings[event.index] = null
	elif event is InputEventScreenDrag: # check for active sliderticks or flicks
		pass
		
func is_in_lane(coords, lane):
	# check that it is within the rectangular hitbox of the current lane
	return coords[0] >= lane_hitboxes[lane-1][0] && coords[0] <= lane_hitboxes[lane-1][1] && coords[1] >= lane_hitboxes[lane-1][2] && coords[1] <= lane_hitboxes[lane-1][3]
	# the chart lanes are 1-indexed so we use i + 1
	
func delete_end(hold_start): 
	var end_found = false
	if hold_start.type == "hold_start":
		for note in onscreen_notes: # TODO: search through onscreen notes first
			if (note.type == "hold_end" || note.type ==  "hold_end_flick") && note.lane == hold_start.lane:
				judge_results[3].append(0) 
				draw_judgement([3,0], note.lane)
				delete_note(note)
				end_found = true
				break
		if !end_found: # if no onscreen hold end was found, delete the earliest corresponding hold end in notes_to_spawn
			for note_data in notes_to_spawn:
				if (note_data["notetype"] == "hold_end" || note_data["notetype"] == "hold_end_flick") && note_data["lane"] == hold_start.lane:
					judge_results[3].append(0) 
					draw_judgement([3,0], note_data["lane"])
					notes_to_spawn.erase(note_data)
					end_found = true
					break
	elif hold_start.type == "slide_start" || hold_start.type == "slide_tick":
		for note in onscreen_notes:
			if (note.type == "slide_tick" || note.type == "slide_end" || note.type == "slide_end_flick") && note.slide_pos == hold_start.slide_pos:
				judge_results[3].append(0) 
				draw_judgement([3,0], note.lane)
				delete_note(note)
				end_found = true
				break
		if !end_found: # if no onscreen slide end was found, delete the earliest corresponding slide end in notes_to_spawn
			for note_data in notes_to_spawn:
				if (note_data["notetype"] == "slide_tick" || note_data["notetype"] == "slide_end" || note_data["notetype"] == "slide_end_flick") && note_data["lane"] == hold_start.lane:
					judge_results[3].append(0) 
					draw_judgement([3,0], note_data["lane"])
					notes_to_spawn.erase(note_data)
					end_found = true
					break


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var timestamp = $Conductor.song_position
	var curr_note_screen_time = note_screen_time/scrollmod
	
	for sv in scrollmod_list:
		if timestamp >= sv["time"]:
			
			chart_timestamp += (sv["time"]-last_timestamp)*scrollmod # account for any bit of the old scrollmod that was missed
			scrollmod = sv["velocity"]
			last_timestamp = sv["time"] # set up to add remaining part under new scrollmod
			curr_note_screen_time = note_screen_time/scrollmod
			scrollmod_list.erase(sv)
		else: 
			break
	
	chart_timestamp += (timestamp-last_timestamp)*scrollmod
	
	for note_data in notes_to_spawn:
		if chart_timestamp >= note_data["chart_time"] - note_screen_time:
			spawn_note(note_data)
		else:
			break # assumes all notes are stored in ascending time
	for note in onscreen_notes:
		if timestamp >= note.time + note.late_great:
			if note.type == "slide_start" || note.type == "slide_tick" || note.type == "hold_start":
				# missed the timing window to start holding the note
				if !note.held:
					judge_results[3].append(0) 
					draw_judgement([3,0], note.lane)
					delete_end(note)
					delete_note(note)
				# otherwise the note is still being held and will keep existing until released (see _input) or reaching the next slide/hold note
			else:
				# judge_results[3] stores misses
				# append 0 because we don't bother calculating timing error on misses
				judge_results[3].append(0) 
				draw_judgement([3,0], note.lane)
				delete_note(note)
		if note.type == "slide_start" || note.type == "slide_tick" || note.type == "slide_end" || note.type == "slide_end_flick":
			if chart_timestamp >= note.chart_time && (note.type != "slide_end" && note.type != "slide_end_flick"):
				if chart_timestamp >= note.slidertail_time: # deletes note if we've reached the next slider node
					delete_note(note)
				else:
					var new_x = note.lane - 4 + (note.slidertail_lane-note.lane) * ((chart_timestamp-note.chart_time)/(note.slidertail_time-note.chart_time))
					note.translation = Vector3(new_x,0,0)
			else:
				note.translation = Vector3(note.lane-4,0,-lane_length*2*(note.chart_time-chart_timestamp)/note_screen_time)
		elif note.type == "hold_start":
			if note.held:
				note.translation = Vector3(note.lane-4,0,0)
			else:
				note.translation = Vector3(note.lane-4,0,-lane_length*2*(note.chart_time-chart_timestamp)/note_screen_time)
		else:
			note.translation = Vector3(note.lane-4,0,-lane_length*2*(note.chart_time-chart_timestamp)/note_screen_time)
	for slide in onscreen_slides:
		if slide != null:
			if slide.sliderhead_obj == null:
				remove_child(slide)
				onscreen_slides.erase(slide)
				slide.queue_free()
			else:
				var close_x = slide.sliderhead_obj.translation[0]
				var close_z = slide.sliderhead_obj.translation[2]
				var far_z = max(-lane_length*2*(slide.slidertail_time-chart_timestamp)/(note_screen_time), 
								-lane_length*2)
				# distance between head and "horizon" vs. distance between head and tail
				var x_time_interp_factor = (chart_timestamp-slide.sliderhead_time+note_screen_time)/(slide.slidertail_time-slide.sliderhead_time)
				var far_x = slide.sliderhead_lane + (slide.slidertail_lane-slide.sliderhead_lane) * min(x_time_interp_factor, 1) - 4
				slide.set_corners(close_x-0.4, close_z, close_x+0.4, close_z, far_x-0.4, far_z, far_x+0.4, far_z)
	last_timestamp = timestamp

# judgement is an array containing [judge_type, offset]
# lane is passed in as 1-indexed 
func draw_judgement(judgement, lane):
	var graphic
	match judgement[0]:
		0: 
			graphic = perfect_plus_graphic.instance()
		1:
			graphic = perfect_graphic.instance()
		2:
			graphic = great_graphic.instance()
		3:
			graphic = miss_graphic.instance()
	# x is centered in lane
	# y is slightly above judgement line
	graphic.position = Vector2((lane_hitboxes[lane-1][0]+lane_hitboxes[lane-1][1])/2 - get_viewport().size[1]*0.1,
								get_viewport().size[1]*0.7)
	$CanvasLayer.add_child(graphic)

func load_chart(file_path):
	var file = File.new()
	if not file.file_exists(file_path):
		print("Missing JSON file.")
	file.open(chart_file, File.READ)
	var content = file.get_as_text()
	file.close()
	return JSON.parse(content).get_result()

func process_notes():
	# "scrollmod" concept below:
	# https://cdn.discordapp.com/attachments/696602455626088478/738649275155742740/0.png
	var time_offset = offset_option
	var chart_time = offset_option
	var curr_scrollmod = 1.0
	var curr_beat = 0.0
	var curr_bpm = 120 # default value in case there is no BPM marker for some reason
	var initial_bpm_set = false
	for i in range(0, chart.size()):
		var data = chart[i]
		if data.type == "System":
			if data.cmd == "BPM":
				curr_bpm = data.bpm
				time_offset += (60.0/curr_bpm) * (data.beat - curr_beat)
				chart_time += (60.0/curr_bpm) * (data.beat - curr_beat) * curr_scrollmod
				curr_beat = data.beat
				if !initial_bpm_set:
					$Conductor.set_bpm(data.bpm)
			if data.cmd == "SV":
				var new_sv = {}
				time_offset += (60.0/curr_bpm) * (data.beat - curr_beat)
				chart_time += (60.0/curr_bpm) * (data.beat - curr_beat) * curr_scrollmod
				curr_scrollmod = data.velocity
				curr_beat = data.beat
				new_sv["time"] = time_offset
				new_sv["chart_time"] = chart_time
				new_sv["velocity"] = data.velocity
				scrollmod_list.append(new_sv)
		if data.type == "Note":
			var new_note = {}
			time_offset += (60.0/curr_bpm) * (data.beat - curr_beat)
			chart_time += (60.0/curr_bpm) * (data.beat - curr_beat) * curr_scrollmod
			curr_beat = data.beat
			new_note["time"] = time_offset
			new_note["chart_time"] = chart_time
			if data.has("velocity"):
				new_note["velocity"] = 1.0 # set to data.velocity if we have it implemented later
			else:
				new_note["velocity"] = 1.0
			new_note["spawntime"] = time_offset - (note_screen_time/new_note["velocity"])
			new_note["lane"] = data.lane
			if data.note == "Single":
				if data.has("flick") &&	 data.flick == true:
					new_note["notetype"] = "flick"
				else:
					new_note["notetype"] = "tap"
			elif data.note == "Slide":
				if data.has("start") && data.start == true:
					var slidestartresult = is_hold_start(data, i, curr_bpm, chart_time, curr_scrollmod) # contains a boolean and an int that represents the next "slide" note connected
					if slidestartresult[0] == true:
						new_note["notetype"] = "hold_start"
						new_note["next_slide_lane"] = slidestartresult[1]
						new_note["next_slide_time"] = slidestartresult[2]
						new_note["next_slide_velocity"] = slidestartresult[3]
					else:
						new_note["notetype"] = "slide_start"
						new_note["slide_pos"] = data.pos
						new_note["next_slide_lane"] = slidestartresult[1]
						new_note["next_slide_time"] = slidestartresult[2]
						new_note["next_slide_velocity"] = slidestartresult[3]
				elif data.has("end") && data.end == true:
					if is_hold_end(data, i):
						if data.has("flick") &&	 data.flick == true:
							new_note["notetype"] = "hold_end_flick"
						else:
							new_note["notetype"] = "hold_end"
					else:
						if data.has("flick") &&	 data.flick == true:
							new_note["notetype"] = "slide_end_flick"
							new_note["slide_pos"] = data.pos
						else:
							new_note["notetype"] = "slide_end"
							new_note["slide_pos"] = data.pos
				else:
					var slidetickresult = is_hold_start(data, i, curr_bpm, chart_time, curr_scrollmod)
					new_note["notetype"] = "slide_tick"
					new_note["slide_pos"] = data.pos
					new_note["next_slide_lane"] = slidetickresult[1]
					new_note["next_slide_time"] = slidetickresult[2]
					new_note["next_slide_velocity"] = slidetickresult[3]
			notes_to_spawn.append(new_note)
		
			
func spawn_note(note):
	var note_instance
	var sliderbody_instance
	if note["notetype"] == "flick":
		note_instance = note_flick_obj.instance()
	elif note["notetype"] == "slide_start":
		note_instance = note_slide_start_obj.instance()
		note_instance.slide_pos = note["slide_pos"]
		note_instance.slidertail_lane = note["next_slide_lane"]
		note_instance.slidertail_time = note["next_slide_time"]
		sliderbody_instance = sliderbody.instance()
		sliderbody_instance.sliderhead_obj = note_instance
		sliderbody_instance.sliderhead_lane = note["lane"]
		sliderbody_instance.sliderhead_time = note["chart_time"]
		sliderbody_instance.slidertail_velocity = note["next_slide_velocity"]
		sliderbody_instance.slidertail_lane = note["next_slide_lane"]
		sliderbody_instance.slidertail_time = note["next_slide_time"]
		add_child(sliderbody_instance)
		onscreen_slides.append(sliderbody_instance)
	elif note["notetype"] == "slide_end":
		note_instance = note_slide_end_obj.instance()
		note_instance.slide_pos = note["slide_pos"]
	elif note["notetype"] == "slide_end_flick":
		note_instance = note_slide_flick_obj.instance()
		note_instance.slide_pos = note["slide_pos"]
	elif note["notetype"] == "slide_tick":
		note_instance = note_slide_tick_obj.instance()
		note_instance.slide_pos = note["slide_pos"]
		note_instance.slidertail_lane = note["next_slide_lane"]
		note_instance.slidertail_time = note["next_slide_time"]
		sliderbody_instance = sliderbody.instance()
		sliderbody_instance.sliderhead_obj = note_instance
		sliderbody_instance.sliderhead_lane = note["lane"]
		sliderbody_instance.sliderhead_time = note["chart_time"]
		sliderbody_instance.slidertail_velocity = note["next_slide_velocity"]
		sliderbody_instance.slidertail_lane = note["next_slide_lane"]
		sliderbody_instance.slidertail_time = note["next_slide_time"]
		add_child(sliderbody_instance)
		onscreen_slides.append(sliderbody_instance)
	elif note["notetype"] == "hold_start":
		note_instance = note_hold_start_obj.instance()
		sliderbody_instance = sliderbody.instance()
		sliderbody_instance.sliderhead_obj = note_instance
		sliderbody_instance.sliderhead_lane = note["lane"]
		sliderbody_instance.sliderhead_time = note["chart_time"]
		sliderbody_instance.slidertail_velocity = note["next_slide_velocity"]
		sliderbody_instance.slidertail_lane = note["next_slide_lane"]
		sliderbody_instance.slidertail_time = note["next_slide_time"]
		add_child(sliderbody_instance)
		onscreen_slides.append(sliderbody_instance)
	elif note["notetype"] == "hold_end":
		note_instance = note_hold_end_obj.instance()
	elif note["notetype"] == "hold_end_flick":
		note_instance = note_hold_flick_obj.instance()
	else:
		note_instance = note_obj.instance()
	note_instance.chart_time = note["chart_time"]
	note_instance.time = note["time"]
	note_instance.lane = note["lane"]
	note_instance.type = note["notetype"]
	note_instance.velocity = note["velocity"]
	add_child(note_instance)
	notes_to_spawn.erase(note)
	onscreen_notes.append(note_instance)

func delete_note(note_to_delete):
	remove_child(note_to_delete)
	onscreen_notes.erase(note_to_delete)
	if note_to_delete.type == "hold_start" || note_to_delete.type == "slide_tick" || note_to_delete.type == "slide_start":
		var search_result = touch_bindings.find(note_to_delete)
		if search_result != -1:
			touch_bindings[search_result] = null
	note_to_delete.queue_free()

# Check for a corresponding end that is in the same lane and has no in-between nodes  
func is_hold_start(note_data, index, bpm, init_chart_time, init_scrollmod): # RETURN: isHoldStart, targetLane, targetTime
	var curr_bpm = bpm
	var curr_beat = note_data.beat
	var chart_time = init_chart_time
	var curr_scrollmod = init_scrollmod
	
	# iterate forwards starting from note after this one
	for i in range(index + 1, chart.size()):
		var velocity
		var other_note = chart[i]
		# if we find a slide note of the same type in the same lane:
		if other_note.type == "System":
			if other_note.cmd == "BPM":
				curr_bpm = other_note.bpm
				chart_time += (60.0/curr_bpm) * (other_note.beat - curr_beat) * curr_scrollmod
				curr_beat = other_note.beat - note_data.beat
			elif other_note.cmd == "SV":
				var new_sv = {}
				chart_time += (60.0/curr_bpm) * (other_note.beat - curr_beat) * curr_scrollmod
				curr_scrollmod = other_note.velocity
				curr_beat = other_note.beat
		elif other_note.note == "Slide" && other_note.pos == note_data.pos:
			if other_note.has("velocity"):
				velocity = other_note.velocity
			else:
				velocity = 1.0
			chart_time += (60.0/curr_bpm) * (other_note.beat - curr_beat) * curr_scrollmod
			curr_beat = other_note.beat - note_data.beat
			if other_note.has("end"):
				# it's a slider end? Good.
				if (other_note.lane == note_data.lane):
					return [true, other_note.lane, chart_time, velocity]
				else:
					return [false, other_note.lane, chart_time, velocity]
			else:
				# If it's not an end, it must be a slider tick - in which case the slider cannot be a hold.
				return [false, other_note.lane, chart_time, velocity]
	# no matching end found, return false by default
	return [false, -1, -1, -1]
		
# Check for a corresponding start that is in the same lane and has no in-between nodes  
func is_hold_end(note_data, index):
	# iterate backwards starting from note before this one
	for i in range(index - 1, -1, -1):
		var other_note = chart[i]
		# if we find a slide note of the same type in the same lane:
		if other_note.type == "System":
			pass
		elif other_note.note == "Slide" && other_note.pos == note_data.pos:
			if other_note.has("start"):
				# it's a slider start? Great.
				return note_data.lane == other_note.lane
			else:
				# Otherwise it must be a slider tick - in which case the slider cannot be a hold.
				return false
	# no matching start found, return false by default
	return false

func _on_Conductor_finished():
	if get_tree().change_scene("res://ResultScreen.tscn") != OK:
		print ("Error changing scene to ResultScreen")
