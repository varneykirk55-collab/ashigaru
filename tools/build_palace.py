"""Original, deterministic beveled architectural modules and textured landscape.
Run: blender --background --python tools/build_palace.py
Coordinates below are gameplay x/y/z; converted to Blender x/-z/y.
"""
import bpy,math,json,random,os
from mathutils import Vector
random.seed(31)
ROOT='/workspace/ashigaru'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
collisions=[];covers=[]
def material(name,color,rough=.8,metal=0,kind='stone'):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 # Bakeable original UV texture: avoids relying on Blender-only shader nodes in glTF.
 import numpy as np
 size=256;y,x=np.mgrid[:size,:size];rng=np.random.default_rng(17)
 if kind=='wood':v=.7+.15*np.sin(x*.29+3*np.sin(y*.03))+.07*rng.random((size,size))
 elif kind=='plaster':v=.9+.1*rng.random((size,size))
 elif kind=='tile':v=.65+.25*np.cos(x*math.pi/32)**2+.04*rng.random((size,size))
 else:v=.75+.2*rng.random((size,size))+.06*np.sin(x*.11)*np.sin(y*.17)
 pixels=np.ones((size,size,4),dtype=np.float32)
 for i in range(3):pixels[:,:,i]=v*color[i]
 img=bpy.data.images.new(name+'_original',width=size,height=size);img.pixels.foreach_set(pixels.ravel());img.pack()
 tex=n.new('ShaderNodeTexImage');tex.image=img;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 return m
wood=material('Weathered cedar',(.22,.115,.061),kind='wood');plaster=material('Warm lime plaster',(.73,.69,.59),kind='plaster');stone=material('Granite',(.31,.34,.33));tile=material('Charcoal ceramic roof',(.095,.13,.145),.42,.15,'tile');red=material('Oxide red lacquer',(.36,.075,.035),.48,kind='wood');grass=material('Garden soil moss',(.16,.23,.13));gold=material('Bronze details',(.48,.33,.12),.38,.6);leaf=material('Pine needles',(.10,.20,.12));sand=material('Raked gravel',(.47,.45,.36));floor=material('Cedar floor',(.39,.24,.12),kind='wood')
def conv(p):return(p[0],-p[2],p[1])
def box(name,p,s,mat,solid=False,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=conv(p));o=bpy.context.object;o.name=name;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('Soft crafted edges','BEVEL');mod.width=bevel;mod.segments=2
  o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
 if solid:collisions.append({'p':p,'s':s})
 return o
def column(p,r=.17,h=4.4):
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=h,location=conv((p[0],p[1]+h/2,p[2])));o=bpy.context.object;o.data.materials.append(wood)
 box('Column stone shoe',(p[0],p[1]+.12,p[2]),(.48,.24,.48),stone,True)
def roof(cx,cz,w,d,y):
 # Curved hipped roof with raised eaves and a ridge; each slope has 8 curved segments.
 verts=[];faces=[]
 for side in [-1,1]:
  start=len(verts)
  for i in range(9):
   t=i/8;xx=side*w*.5*t;yy=y+2.9*(1-t)**1.35+.45*t**6
   for zz in [-d/2,d/2]:verts.append(conv((cx+xx,yy,cz+zz)))
  for i in range(8):a=start+i*2;faces.append((a,a+1,a+3,a+2))
 mesh=bpy.data.meshes.new('Curved roof surface');mesh.from_pydata(verts,[],faces);mesh.materials.append(tile);o=bpy.data.objects.new('Sweeping ceramic eaves',mesh);bpy.context.collection.objects.link(o)
 sol=o.modifiers.new('Roof thickness','SOLIDIFY');sol.thickness=.16
 # Raised tile ribs give the roof modeled depth, without thousands of objects.
 for z in [cz-d/2+i*.65 for i in range(int(d/.65)+1)]:
  curve=bpy.data.curves.new('Ceramic rib','CURVE');curve.dimensions='3D';curve.bevel_depth=.045;curve.bevel_resolution=1
  for side in [-1,1]:
   spline=curve.splines.new('POLY');spline.points.add(8)
   for i in range(9):
    t=i/8;spline.points[i].co=(*conv((cx+side*w*.5*t,y+2.9*(1-t)**1.35+.45*t**6+.05,z)),1)
  obj=bpy.data.objects.new('Tile rib',curve);bpy.context.collection.objects.link(obj);obj.data.materials.append(tile)
 box('Roof ridge',(cx,y+3.05,cz),(.3,.3,d+.7),tile)
def wall(p,s):
 box('Plaster panel',p,s,plaster,True)
 box('Stone foundation',(p[0],.22,p[2]),(s[0]+.12,.44,s[2]+.12),stone)
 box('Wall cap',(p[0],p[1]+s[1]/2,p[2]),(s[0]+.25,.18,s[2]+.25),tile)
def hall(cx,cz,w,d):
 box('Hall floor',(cx,.025,cz),(w,.05,d),floor)
 # Entrances in the middle of all four sides; continuous accessible floor.
 for sign in [-1,1]:
  for off in [-1,1]:
   wall((cx+off*(w/4+2),2.1,cz+sign*d/2),(w/2-4,4.2,.3))
   wall((cx+sign*w/2,2.1,cz+off*(d/4+1.5)),(.3,4.2,d/2-3))
 for x in [cx-w/2+i*4 for i in range(int(w/4)+1)]:
  for z in [cz-d/2,cz+d/2]:column((x,0,z));box('Exposed lintel',(x,3.8,z),(4,.22,.3),wood)
 for x in [cx-w/2,cx+w/2]:
  for z in [cz-d/2+i*4 for i in range(int(d/4)+1)]:column((x,0,z))
 roof(cx,cz,w+4,d+4,4.5)
 # Panel frames and slender timber slats, spaced on opaque wall segments.
 for sign in [-1,1]:
  for x in [cx-w/2+2+i*2 for i in range(int(w/2)-1)]:
   if abs(x-cx)<4:continue
   box('Cedar wall framing',(x,2,cz+sign*(d/2+.17)),(.08,3.7,.07),wood,False,.01)
   box('Lower panel rail',(x,1.05,cz+sign*(d/2+.19)),(2,.08,.08),wood,False,.01)
# Enclosed world with gates aligned to circulation.
box('Palace grounds',(0,-.2,0),(150,.4,150),grass,True)
for sign in [-1,1]:
 for offset in [-1,1]:
  wall((offset*40,2.7,sign*74),(68,5.4,.65));wall((sign*74,2.7,offset*40),(.65,5.4,68))
 for x,z in [(0,sign*74),(sign*74,0)]:
  for side in [-1,1]:column((x+side*4.5,0,z),.3,5.5)
  roof(x,z,12,6,5.5)
# Main palace and upper architectural tier (upper floor intentionally not traversable).
hall(0,0,44,32);roof(0,-1,24,22,8.2)
box('Upper storey screens',(0,7.1,-1),(20,3.7,18),plaster)
for x in [-9,-6,-3,0,3,6,9]:box('Upper screen lattice',(x,7.2,8.08),(.12,3.2,.1),wood)
# Interior rooms flank the broad central processional hall.
for x in [-9,9]:
 for sign in [-1,1]:wall((x,2,sign*9.5),(.25,4,13))
for x in [-16,16]:
 for z in [-5.5,5.5]:
  for side in [-1,1]:wall((x+side*4,2,z),(5.5,4,.25))
# Timber ceilings and crossbeams; all at safe head clearance.
for z in range(-14,15,4):box('Interior ceiling beam',(0,4.15,z),(44,.3,.35),wood)
for x in range(-20,21,4):box('Floor plank seam',(x,.055,0),(.025,.012,32),wood,False,.001)
# Courtyard, processional roads and garden circuits.
box('Grand courtyard',(0,.008,36),(72,.016,34),sand)
for x in range(-32,33,4):
 for z in range(22,51,4):box('Dressed courtyard paver',(x,.022,z),(3.92,.025,3.92),stone,False,.015)
for x in [-40,40]:box('Garden stone route',(x,.018,0),(6,.025,120),sand)
for z in [-48,56]:box('Cross garden road',(0,.018,z),(120,.025,6),sand)
# Two flanking pavilions and long connected sheltered passages.
hall(-43,-22,14,18);hall(43,22,14,18)
for x in [-29,29]:
 for z in range(-32,33,8):
  box('Covered gallery floor',(x,.025,z),(5,.05,8),floor)
  for side in [-1,1]:column((x+side*2,0,z-4),.13,3.3)
  roof(x,z,7,8.1,3.3)
# Spawn lodges and protective baffles; two exits with routes into the battlefield.
for x,z in [(-57,40),(57,-40)]:
 hall(x,z,14,14)
 for off in [-1,1]:
  p=(x+off*8,1,z-8 if x<0 else z+8);box('Spawn sight baffle',p,(5,2,1),stone,True);covers.append([p[0],0,p[2]+(1.5 if x<0 else -1.5)])
# Cover groups break long sight lines without blocking the processional route.
for x,z in [(-18,30),(18,40),(-30,-40),(30,-34),(-45,12),(45,-12),(-12,-29),(12,-39),(-17,48),(17,24)]:
 box('Raised garden bed',(x,.65,z),(5.5,1.3,2.0),stone,True,.1)
 box('Bed soil',(x,1.32,z),(5.2,.08,1.7),grass)
 for side in [-1,1]:covers.append([x,0,z+side*2.0])
# Garden rocks and branching pines, with low clustered needle canopies.
for x,z in [(-52,-45),(-47,0),(-56,17),(50,44),(51,2),(42,-49),(-18,-49),(16,-53),(-60,-13),(60,15)]:
 for i in range(3):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=conv((x+random.uniform(-3,3),.7,z+random.uniform(-3,3))));o=bpy.context.object;o.name='Weathered garden rock';o.scale=(random.uniform(1,2),random.uniform(1,2),random.uniform(.8,1.5));o.data.materials.append(stone)
 column((x,0,z),.23,5.5)
 for i in range(6):
  dx=random.uniform(-2.5,2.5);dz=random.uniform(-2.5,2.5);height=random.uniform(4,7)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=conv((x+dx,height,z+dz)));o=bpy.context.object;o.name='Layered pine canopy';o.scale=(2.8,2.3,.85);o.data.materials.append(leaf)
  for poly in o.data.polygons:poly.use_smooth=True
# Lanterns and stone seats along the main routes.
for x in [-24,24]:
 for z in [-42,-22,22,42]:
  column((x,0,z),.16,1.5);box('Lantern light housing',(x,1.7,z),(.7,.5,.7),plaster);roof(x,z,1.1,1.0,2)
  box('Garden seat',(x+2,.42,z),(2.2,.18,.7),wood)
# Export reusable mesh modules in one scene, apply modifiers and preserve material textures.
bpy.ops.object.select_all(action='DESELECT')
for o in list(bpy.context.scene.objects):
 if o.type=='CURVE':
  o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');o.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/source_assets/Palace.blend')
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/palace/Palace.glb',export_format='GLB',use_selection=False,export_apply=True)
json.dump({'colliders':collisions,'cover':covers},open(ROOT+'/assets/palace/layout.json','w'))
json.dump({'colliders':collisions,'cover':covers},open(ROOT+'/assets/palace/layout_base.json','w'))
print('PALACE GENERATED',len(collisions),'colliders',len(covers),'cover positions')
