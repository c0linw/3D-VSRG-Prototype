extends MeshInstance    
#export(FixedMaterial)    
var material   
var sliderhead_lane
var sliderhead_time
var slidertail_lane
var slidertail_time
var sliderhead_obj
var slidertail_velocity

func _ready():
	var surfTool = SurfaceTool.new()
	var mesh = Mesh.new()
	material = SpatialMaterial.new()
	material.flags_transparent = true
	material.albedo_color = Color(0.215, 0.722, 0.188, 0.70)
	# lower right triangle
	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surfTool.set_material(material)
	surfTool.add_uv(Vector2(0,0))
	surfTool.add_vertex(Vector3(-1,-0.001,0))
	surfTool.add_uv(Vector2(0.5,1))
	surfTool.add_vertex(Vector3(1,-0.001,-2))
	surfTool.add_uv(Vector2(1,0))
	surfTool.add_vertex(Vector3(1,-0.001,0))
	surfTool.generate_normals()
	surfTool.index()
	surfTool.commit(mesh)
	
	# upper left triangle
	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surfTool.set_material(material)
	surfTool.add_uv(Vector2(0,0))
	surfTool.add_vertex(Vector3(-1,-0.001,0))
	surfTool.add_uv(Vector2(0.5,1))
	surfTool.add_vertex(Vector3(-1,-0.001,-2))
	surfTool.add_uv(Vector2(1,0))
	surfTool.add_vertex(Vector3(1,-0.001,-2))
	surfTool.generate_normals()
	surfTool.index()
	surfTool.commit(mesh)
	self.set_mesh(mesh)        

# set corners passed in the following order: close left, close right, far left, far right
# assumes two triangles and nothing else
func set_corners(x1, z1, x2, z2, x3, z3, x4, z4):
	var mdt = MeshDataTool.new()
	var vertex
	var new_point
	
	#### LOWER RIGHT TRIANGLE ####
	mdt.create_from_surface(self.mesh, 0)

	vertex = mdt.get_vertex(0) # close left point
	new_point = Vector3(x1,-0.001,z1)
	mdt.set_vertex(0, new_point)
	
	vertex = mdt.get_vertex(1) # far right point
	new_point = Vector3(x4,-0.001,z4)
	mdt.set_vertex(1, new_point)
	
	vertex = mdt.get_vertex(2) # bottom right point
	new_point = Vector3(x2,-0.001,z2)
	mdt.set_vertex(2, new_point)
	
	mesh.surface_remove(0)
	mdt.commit_to_surface(mesh)
	
	#### UPPER LEFT TRIANGLE ####
	mdt.create_from_surface(self.mesh, 0)

	vertex = mdt.get_vertex(0) # close left point
	new_point = Vector3(x1,-0.001,z1)
	mdt.set_vertex(0, new_point)
	
	vertex = mdt.get_vertex(1) # far right point
	new_point = Vector3(x3,-0.001,z3)
	mdt.set_vertex(1, new_point)
	
	vertex = mdt.get_vertex(2) # bottom right point
	new_point = Vector3(x4,-0.001,z4)
	mdt.set_vertex(2, new_point)
	
	mesh.surface_remove(0)
	mdt.commit_to_surface(mesh)
