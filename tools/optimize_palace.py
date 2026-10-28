import bpy,json,math
R='/workspace/ashigaru'
bpy.ops.wm.open_mainfile(filepath=R+'/source_assets/Palace.blend')
layout=json.load(open(R+'/assets/palace/layout_base.json'))
for o in list(bpy.context.scene.objects):
 if o.name.startswith('Weathered garden rock'):
  for face in o.data.polygons:face.use_smooth=True
  sub=o.modifiers.new('Eroded stone curvature','SUBSURF');sub.levels=1;sub.render_levels=1
  layout['colliders'].append({'p':[o.location.x,.65,-o.location.y],'s':[o.scale.x*1.65,1.3,o.scale.y*1.65]})
# Original room furnishings and garden detail, added before spatial batching.
from mathutils import Vector
M={m.name:m for m in bpy.data.materials}
if 'Bronze details' not in M:
 m=bpy.data.materials.new('Bronze details');m.diffuse_color=(.48,.33,.12,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.48,.33,.12,1);p.inputs['Metallic'].default_value=.6;p.inputs['Roughness'].default_value=.38;M[m.name]=m
def prop(name,p,size,material,solid=False):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(p[0],-p[2],p[1]));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[material])
 mod=o.modifiers.new('Crafted bevel','BEVEL');mod.width=.025;mod.segments=2
 if solid:layout['colliders'].append({'p':p,'s':size})
 return o
for x in [-18,18]:
 for z in [-11,11]:
  prop('Woven room mat',(x,.07,z),(6,.02,6),'Raked gravel')
  prop('Low writing table',(x,.62,z),(2,.16,1.2),'Weathered cedar',True)
  for dx in [-.8,.8]:
   for dz in [-.4,.4]:prop('Table foot',(x+dx,.3,z+dz),(.12,.6,.12),'Weathered cedar')
  prop('Scroll rail',(x,2.8,(-15.7 if z<0 else 15.7)),(2,.1,.12),'Weathered cedar')
  prop('Indigo wall hanging',(x,2.1,(-15.72 if z<0 else 15.72)),(1.6,1.4,.035),'Charcoal ceramic roof')
  for i in range(3):prop('Gilt hanging emblem',(x+(i-1)*.27,2.2,(-15.68 if z<0 else 15.68)),(.17,.46,.04),'Bronze details')
for z in [-8,8]:
 prop('Hanging paper lantern',(0,3.3,z),(.7,.8,.7),'Warm lime plaster')
 for x in [-.36,.36]:prop('Lantern frame',(x,3.3,z),(.045,.9,.76),'Weathered cedar')
 prop('Lantern chain',(0,3.95,z),(.025,.5,.025),'Bronze details')
for x,z in [(-51,-44),(51,44),(-53,12),(51,-15)]:
 # Walkable gravel gardens edged by low timber. No artificial water collision.
 prop('Raked garden island',(x,.025,z),(15,.03,11),'Raked gravel')
 for side in [-1,1]:
  prop('Garden timber edging',(x+side*7.5,.07,z),(.12,.14,11),'Weathered cedar')
  prop('Garden timber edging',(x,.07,z+side*5.5),(15,.14,.12),'Weathered cedar')
 for r in [1.5,2.4,3.3,4.2]:
  curve=bpy.data.curves.new('Raked gravel contour','CURVE');curve.dimensions='3D';curve.bevel_depth=.012;curve.bevel_resolution=0
  spline=curve.splines.new('POLY');spline.points.add(47)
  for i in range(48):
   angle=i*math.tau/47;spline.points[i].co=(x+math.cos(angle)*r,-z+math.sin(angle)*r*.7,.055,1)
  o=bpy.data.objects.new('Concentric gravel rake',curve);bpy.context.collection.objects.link(o);o.data.materials.append(M['Granite'])
json.dump(layout,open(R+'/assets/palace/layout.json','w'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
groups={}
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':continue
 key=(o.data.materials[0].name if o.data.materials else '',math.floor(o.location.x/24),math.floor(o.location.y/24))
 groups.setdefault(key,[]).append(o)
for key,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.object.join();bpy.context.object.name='Palace_chunk_'+str(key)
bpy.ops.export_scene.gltf(filepath=R+'/assets/palace/Palace.glb',export_format='GLB',use_selection=False,export_apply=True)
print('OPTIMIZED',len(groups),'spatial material chunks')
