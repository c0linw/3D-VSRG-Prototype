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
var chart_file = "res://Songs/Roku Chounen to Ichiya Monogatari/roku_sp.json"
var chart

var offset_option = 0.175
var note_speed = 10.5
var lane_length = 12.0
var note_screen_time
var note_units_per_sec

var notes_to_spawn = []
var scrollmod_list = []
var onscreen_notes = []
var onscreen_slides = []

var scrollmod = 1.0
var last_timestamp = 0.0
var chart_timestamp = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	note_screen_time = (12.0 - note_speed) / 2.0
	note_units_per_sec = lane_length/note_screen_time
	audio = load(audio_file)
	chart = load_chart(chart_file)
	$Conductor.stream = audio
	process_notes()
	$Conductor.volume_db = -10.0
	$Conductor.play_from_beat(0, 0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var timestamp = $Conductor.song_position
	var curr_note_screen_time = note_screen_time/scrollmod
	var chart_timestamp_diff_split = [] # contains dicts that pair timespans with scrollmods. Iterate to apply each one so that positions stay accurate at boundary changes.
	
	for sv in scrollmod_list:
		if timestamp >= sv["time"]:
			var new_segment = {}
			new_segment["time_diff"] = (sv["time"]-last_timestamp)*scrollmod
			new_segment["scrollmod"] = scrollmod
			chart_timestamp_diff_split.append(new_segment)
			
			chart_timestamp += (sv["time"]-last_timestamp)*scrollmod # account for any bit of the old scrollmod that was missed
			scrollmod = sv["velocity"]
			last_timestamp = sv["time"] # set up to add remaining part under new scrollmod
			curr_note_screen_time = note_screen_time/scrollmod
			scrollmod_list.erase(sv)
		else: 
			break
	
	var last_chart_timestamp = chart_timestamp
	var new_segment = {}
	new_segment["time_diff"] = (timestamp-last_timestamp)*scrollmod
	new_segment["scrollmod"] = scrollmod
	chart_timestamp_diff_split.append(new_segment)
	chart_timestamp += (timestamp-last_timestamp)*scrollmod
	
	for note_data in notes_to_spawn:
		if chart_timestamp >= note_data["chart_time"] - note_screen_time:
			spawn_note(note_data)
		else:
			break # assumes all notes are stored in ascending time
	for note in onscreen_notes:
		if chart_timestamp >= note.chart_time + 8:
			delete_note(note)
		if note.type == "slide_start" || note.type == "slide_tick":
			if chart_timestamp >= note.chart_time:
				if chart_timestamp >= note.slidertail_time:
					delete_note(note)
				else:
					var new_x = note.lane - 4 + (note.slidertail_lane-note.lane) * ((chart_timestamp-note.chart_time)/(note.slidertail_time-note.chart_time))
					note.translation = Vector3(new_x,0,0)
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

