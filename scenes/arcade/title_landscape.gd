extends Control
var age := 0.0
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
 age += delta
 queue_redraw()
func box(x: float,y: float,w: float,h: float,c: String) -> void:
 draw_rect(Rect2(x,y,w,h),Color(c))
func cloud(x: float,y: float) -> void:
 box(x,y+8,84,12,"c5e5dc")
 box(x+12,y,48,20,"f3f0d1")
 box(x+28,y-8,24,16,"f3f0d1")
func tree(x: float,y: float) -> void:
 box(x-6,y-22,12,54,"644c39")
 box(x-30,y-66,60,40,"235b53")
 box(x-22,y-86,44,36,"317969")
 box(x-12,y-99,24,23,"4b9676")
 box(x-26,y-52,12,16,"3c8067")
func chicken(x: float,y: float,flip := false) -> void:
 var bob := roundf(sin(age*3+x)*1.2)
 y += bob
 box(x,y,24,16,"f5e3af")
 box(x+14 if not flip else x-4,y-8,13,15,"fff2ce")
 box(x+18 if not flip else x-3,y-13,7,6,"c86b4c")
 box(x+26 if not flip else x-9,y-2,7,4,"e6ad58")
 box(x+22 if not flip else x,y-5,3,3,"243c44")
 box(x+4,y+16,3,7,"d69b4e")
 box(x+16,y+16,3,7,"d69b4e")
 box(x+5,y+4,10,7,"d3c695")
func _draw() -> void:
 draw_set_transform(Vector2.ZERO,0,size/Vector2(960,540))
 box(0,0,960,540,"183e55")
 box(0,0,960,140,"255d70")
 box(0,140,960,140,"347e84")
 box(0,280,960,120,"77a79a")
 box(0,360,960,90,"608b68")
 box(0,450,960,90,"284d43")
 box(75,63,52,52,"d9d9a2")
 box(68,75,66,28,"d9d9a2")
 for i in range(7):
  var x := fposmod(i*173+age*3,1120)-100
  cloud(x,58+(i%3)*48)
 for i in range(16):
  box(i*71,324-(i%4)*12,80,66,"487e70")
 for x in [30,100,830,924]: tree(x,356)
 # Barn and silo: deliberate chunky silhouettes, clear space around the title.
 box(50,348,162,102,"783f39")
 draw_colored_polygon(PackedVector2Array([Vector2(32,352),Vector2(128,284),Vector2(230,352)]),Color("3a3441"))
 draw_colored_polygon(PackedVector2Array([Vector2(43,348),Vector2(128,296),Vector2(216,348)]),Color("bb6f50"))
 for x in range(62,210,16): box(x,357,4,90,"995345")
 box(103,379,57,71,"303c3c")
 box(109,384,45,66,"bc8658")
 box(128,384,5,66,"e7c78c")
 box(109,409,45,5,"e7c78c")
 box(119,327,23,22,"e4bb73")
 box(127,327,5,22,"654b3d")
 box(119,335,23,5,"654b3d")
 box(743,327,42,117,"809a8a")
 box(748,310,32,17,"c0bc91")
 box(754,303,20,8,"e3ce99")
 box(785,365,113,79,"53684c")
 draw_colored_polygon(PackedVector2Array([Vector2(773,367),Vector2(841,326),Vector2(908,367)]),Color("d2a663"))
 box(825,392,30,52,"263f3d")
 # Far fence and winding farm path.
 for x in range(0,960,44):
  box(x,424,8,44,"b49d72")
 box(0,435,960,6,"d7c18b")
 box(0,454,960,5,"8f805e")
 draw_colored_polygon(PackedVector2Array([Vector2(445,440),Vector2(509,440),Vector2(598,540),Vector2(337,540)]),Color("bba277"))
 for i in range(45):
  var x := (i*137)%960
  var y := 477+(i*23)%63
  if x>330 and x<605: continue
  box(x,y,3,9,"67936b")
  box(x+4,y-4,3,8,"89a66c")
 for x in [240,280,680,720]:
  box(x,470,23,12,"466b45")
  box(x+4,464,16,16,"8fac71")
  box(x+9,462,5,14,"b5c58a")
 chicken(320,464)
 chicken(628,475,true)
 chicken(660,451,true)
 box(0,528,960,12,"142d30")
