//////////////////////////////////////////////////////////////////////
// LibFile: attachments.scad
//   The modules in this file allows you to attach one object to another by making one object the child of another object.
//   You can place the child object in relation to its parent object and control the position and orientation
//   relative to the parent.  The modifiers allow you to treat children in different ways that simple union, such
//   as differencing them from the parent, or changing their color.  Attachment only works when the parent and child
//   are both written to support attachment.  Also included in this file  are the tools to make your own "attachable" objects.
// Includes:
//   include <BOSL2/std.scad>
//////////////////////////////////////////////////////////////////////


// Default values for attachment code.
$tags = "";
$overlap = 0;
$color = undef;//"yellow";

$attach_to = undef;
$attach_anchor = [CENTER, CENTER, UP, 0];
$attach_norot = false;

$parent_anchor = BOTTOM;
$parent_spin = 0;
$parent_orient = UP;

$parent_size = undef;
$parent_geom = undef;

$tags_shown = [];
$tags_hidden = [];


// Section: Anchors, Spin, and Orientation
//   This library adds the concept of anchoring, spin and orientation to the `cube()`, `cylinder()`
//   and `sphere()` builtins, as well as to most of the shapes provided by this library itself.
//   - An anchor is a place on an object which you can align the object to, or attach other objects
//     to using `attach()` or `position()`.  An anchor has a position, a direction, and a spin.
//     The direction and spin are used to orient other objects to match when using `attach()`.
//   - Spin is a simple rotation around the Z axis.
//   - Orientation is rotating an object so that its top is pointed towards a given vector.
//   An object will first be translated to its anchor position, then spun, then oriented.
//   .
//   ## Anchor
//   Anchoring is specified with the `anchor` argument in most shape modules.  Specifying `anchor`
//   when creating an object will translate the object so that the anchor point is at the origin
//   (0,0,0).  Anchoring always occurs before spin and orientation are applied.
//   .
//   An anchor can be referred to in one of two ways; as a directional vector, or as a named anchor string.
//   .
//   When given as a vector, it points, in a general way, towards the face, edge, or corner of the
//   object that you want the anchor for, relative to the center of the object.  There are directional
//   constants named `TOP`, `BOTTOM`, `FRONT`, `BACK`, `LEFT`, and `RIGHT` that you can add together
//   to specify an anchor point.
//   .
//   For example:
//   - `[0,0,1]` is the same as `TOP` and refers to the center of the top face.
//   - `[-1,0,1]` is the same as `TOP+LEFT`, and refers to the center of the top-left edge.
//   - `[1,1,-1]` is the same as `BOTTOM+BACK+RIGHT`, and refers to the bottom-back-right corner.
//   .
//   When the object is cylindrical, conical, or spherical in nature, the anchors will be located
//   around the surface of the cylinder, cone, or sphere, relative to the center.  The direction of a
//   face anchor will be perpendicular to the face, pointing outward.  The direction of a edge anchor
//   will be the average of the anchor directions of the two faces the edge is between.  The direction
//   of a corner anchor will be the average of the anchor directions of the three faces the corner is
//   on.  The spin of all standard anchors is 0.
//   .
//   Some more complex objects, like screws and stepper motors, have named anchors to refer to places
//   on the object that are not at one of the standard faces, edges or corners.  For example, stepper
//   motors have anchors for `"screw1"`, `"screw2"`, etc. to refer to the various screwholes on the
//   stepper motor shape.  The names, positions, directions, and spins of these anchors will be
//   specific to the object, and will be documented when they exist.
//   .
//   ## Spin
//   Spin is specified with the `spin` argume//   nt in most shape modules.  Specifying a scalar `spin`
//   when creating an object will rotate the object counter-clockwise around the Z axis by the given
//   number of degrees.  If given as a 3D vector, the object will be rotated around each of the X, Y, Z
//   axes by the number of degrees in each component of the vector.  Spin is always applied after
//   anchoring, and before orientation.
//   .
//   ## Orient
//   Orientation is specified with the `orient` argument in most shape modules.  Specifying `orient`
//   when creating an object will rotate the object such that the top of the object will be pointed
//   at the vector direction given in the `orient` argument.  Orientation is always applied after
//   anchoring and spin.  The constants `UP`, `DOWN`, `FRONT`, `BACK`, `LEFT`, and `RIGHT` can be
//   added together to form the directional vector for this.  ie: `LEFT+BACK`
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].


// Section: Attachment Positioning

// Module: position()
// Usage:
//   position(from) {...}
//
// Topics: Attachments
// See Also: attachable(), attach(), orient()
//
// Description:
//   Attaches children to a parent object at an anchor point.  For a more step-by-step explanation
//   of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   from = The vector, or name of the parent anchor point to attach to.
// Example:
//   spheroid(d=20) {
//       position(TOP) cyl(l=10, d1=10, d2=5, anchor=BOTTOM);
//       position(RIGHT) cyl(l=10, d1=10, d2=5, anchor=BOTTOM);
//       position(FRONT) cyl(l=10, d1=10, d2=5, anchor=BOTTOM);
//   }
module position(from)
{
    assert($parent_geom != undef, "No object to attach to!");
    anchors = (is_vector(from)||is_string(from))? [from] : from;
    for (anchr = anchors) {
        anch = _find_anchor(anchr, $parent_geom);
        $attach_to = undef;
        $attach_anchor = anch;
        $attach_norot = true;
        translate(anch[1]) children();
    }
}


// Module: orient()
// Usage:
//   orient(dir, <spin=>) ...
//   orient(anchor=, <spin=>) ...
// Topics: Attachments
// Description:
//   Orients children such that their top is tilted towards the given direction, or towards the
//   direction of a given anchor point on the parent.  For a more step-by-step explanation of
//   attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   dir = The direction to orient towards.
//   ---
//   anchor = The anchor on the parent which you want to match the orientation of.  Use instead of `dir`.
//   spin = The spin to add to the children.  (Overrides anchor spin.)
// See Also: attachable(), attach(), orient()
// Example: Orienting by Vector
//   prismoid([50,50],[30,30],h=40) {
//       position(TOP+RIGHT)
//           orient(RIGHT)
//               prismoid([30,30],[0,5],h=20,anchor=BOT+LEFT);
//   }
// Example: When orienting to an anchor, the spin of the anchor may cause confusion:
//   prismoid([50,50],[30,30],h=40) {
//       position(TOP+RIGHT)
//           orient(anchor=RIGHT)
//               prismoid([30,30],[0,5],h=20,anchor=BOT+LEFT);
//   }
// Example: You can override anchor spin with `spin=`.
//   prismoid([50,50],[30,30],h=40) {
//       position(TOP+RIGHT)
//           orient(anchor=RIGHT,spin=0)
//               prismoid([30,30],[0,5],h=20,anchor=BOT+LEFT);
//   }
// Example: Or you can anchor the child from the back
//   prismoid([50,50],[30,30],h=40) {
//       position(TOP+RIGHT)
//           orient(anchor=RIGHT)
//               prismoid([30,30],[0,5],h=20,anchor=BOT+BACK);
//   }
module orient(dir, anchor, spin) {
    if (!is_undef(dir)) {
        assert(anchor==undef, "Only one of dir= or anchor= may be given to orient()");
        assert(is_vector(dir));
        spin = default(spin, 0);
        assert(is_finite(spin));
        rot(spin, from=UP, to=dir) children();
    } else {
        assert(dir==undef, "Only one of dir= or anchor= may be given to orient()");
        assert($parent_geom != undef, "No parent to orient from!");
        assert(is_string(anchor) || is_vector(anchor));
        anch = _find_anchor(anchor, $parent_geom);
        two_d = _attach_geom_2d($parent_geom);
        fromvec = two_d? BACK : UP;
        $attach_to = undef;
        $attach_anchor = anch;
        $attach_norot = true;
        spin = default(spin, anch[3]);
        assert(is_finite(spin));
        rot(spin, from=fromvec, to=anch[2]) children();
    }
}




// Module: attach()
// Usage:
//   attach(from, [overlap=], [norot=]) {...}
//   attach(from, to, [overlap=], [norot=]) {...}
// Topics: Attachments
// See Also: attachable(), position(), face_profile(), edge_profile(), corner_profile()
// Description:
//   Attaches children to a parent object at an anchor point and orientation.  Attached objects will
//   be overlapped into the parent object by a little bit, as specified by the `$overlap`
//   value (0 by default), or by the overriding `overlap=` argument.  This is to prevent OpenSCAD
//   from making non-manifold objects.  You can define `$overlap=` as an argument in a parent
//   module to set the default for all attachments to it.  For a more step-by-step explanation of
//   attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   from = The vector, or name of the parent anchor point to attach to.
//   to = Optional name of the child anchor point.  If given, orients the child such that the named anchors align together rotationally.
//   ---
//   overlap = Amount to sink child into the parent.  Equivalent to `down(X)` after the attach.  This defaults to the value in `$overlap`, which is `0` by default.
//   norot = If true, don't rotate children when attaching to the anchor point.  Only translate to the anchor point.
// Example:
//   spheroid(d=20) {
//       attach(TOP) down(1.5) cyl(l=11.5, d1=10, d2=5, anchor=BOTTOM);
//       attach(RIGHT, BOTTOM) down(1.5) cyl(l=11.5, d1=10, d2=5);
//       attach(FRONT, BOTTOM, overlap=1.5) cyl(l=11.5, d1=10, d2=5);
//   }
module attach(from, to, overlap, norot=false)
{
    assert($parent_geom != undef, "No object to attach to!");
    overlap = (overlap!=undef)? overlap : $overlap;
    anchors = (is_vector(from)||is_string(from))? [from] : from;
    for (anchr = anchors) {
        anch = _find_anchor(anchr, $parent_geom);
        two_d = _attach_geom_2d($parent_geom);
        $attach_to = to;
        $attach_anchor = anch;
        $attach_norot = norot;
        olap = two_d? [0,-overlap,0] : [0,0,-overlap];
        if (norot || (norm(anch[2]-UP)<1e-9 && anch[3]==0)) {
            translate(anch[1]) translate(olap) children();
        } else {
            fromvec = two_d? BACK : UP;
            translate(anch[1]) rot(anch[3],from=fromvec,to=anch[2]) translate(olap) children();
        }
    }
}

// Section: Attachment Modifiers

// Module: tags()
// Usage:
//   tags(tags) {...}
// Topics: Attachments
// See Also: recolor(), hide(), show(), diff(), intersect()
// Description:
//   Marks all children with the given tags, so that they will `hide()`/`show()`/`diff()`  correctly.
//   This is especially useful for working with children that are not attachment enhanced, such as:
//   - `square()`  (or use [`rect()`](shapes2d.scad#rect))
//   - `circle()`  (or use [`oval()`](shapes2d.scad#oval))
//   - `polygon()`
//   - `text()`
//   - `projection()`
//   - `polyhedron()`  (or use [`vnf_polyhedron()`](vnf.scad#vnf_polyhedron))
//   - `linear_extrude()`  (or use [`linear_sweep()`](regions.scad#linear_sweep))
//   - `rotate_extrude()`
//   - `surface()`
//   - `import()`
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   tags = String containing space delimited set of tags to apply.
module tags(tags)
{
    $tags = tags;
    if(_attachment_is_shown(tags)) {
        children();
    }
}


// Module: recolor()
// Usage:
//   recolor(c) {...}
// Topics: Attachments
// See Also: tags(), hide(), show(), diff(), intersect()
// Description:
//   Sets the color for children that can use the $color special variable.  For a more step-by-step
//   explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   c = Color name or RGBA vector.
// Example:
//   recolor("red") cyl(l=20, d=10);
module recolor(c)
{
    $color = c;
    children();
}


// Module: hide()
// Usage:
//   hide(tags) {...}
// Topics: Attachments
// See Also: tags(), recolor(), show(), diff(), intersect()
// Description:
//   Hides all children with the given tags.  Overrides any previous `hide()` or `show()` calls.
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Example:
//   hide("A") cube(50, anchor=CENTER, $tags="Main") {
//       attach(LEFT, BOTTOM) cylinder(d=30, l=30, $tags="A");
//       attach(RIGHT, BOTTOM) cylinder(d=30, l=30, $tags="B");
//   }
module hide(tags="")
{
    $tags_hidden = tags==""? [] : str_split(tags, " ");
    $tags_shown = [];
    children();
}


// Module: show()
// Usage:
//   show(tags) {...}
// Topics: Attachments
// See Also: tags(), recolor(), hide(), diff(), intersect()
// Description:
//   Shows only children with the given tags.  Overrides any previous `hide()` or `show()` calls.
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Example:
//   show("A B") cube(50, anchor=CENTER, $tags="Main") {
//       attach(LEFT, BOTTOM) cylinder(d=30, l=30, $tags="A");
//       attach(RIGHT, BOTTOM) cylinder(d=30, l=30, $tags="B");
//   }
module show(tags="")
{
    $tags_shown = tags==""? [] : str_split(tags, " ");
    $tags_hidden = [];
    children();
}


// Module: diff()
// Usage:
//   diff(neg, [keep]) {...}
//   diff(neg, pos, [keep]) {...}
// Topics: Attachments
// See Also: tags(), recolor(), show(), hide(), intersect()
// Description:
//   If `neg` is given, takes the union of all children with tags that are in `neg`, and differences
//   them from the union of all children with tags in `pos`.  If `pos` is not given, then all items in
//   `neg` are differenced from all items not in `neg`.  If `keep` is given, all children with tags in
//   `keep` are then unioned with the result.  If `keep` is not given, all children without tags in
//   `pos` or `neg` are then unioned with the result.
//   Cannot be used in conjunction with `intersect()` or `hulling()` on the same parent object.
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   neg = String containing space delimited set of tag names of children to difference away.
//   pos = String containing space delimited set of tag names of children to be differenced away from.
//   keep = String containing space delimited set of tag names of children to keep whole.
// Example:
//   diff("neg", "pos", keep="axle")
//   sphere(d=100, $tags="pos") {
//       attach(CENTER) xcyl(d=40, l=120, $tags="axle");
//       attach(CENTER) cube([40,120,100], anchor=CENTER, $tags="neg");
//   }
// Example: Masking
//   diff("mask")
//   cube([80,90,100], center=true) {
//       edge_mask(FWD)
//           rounding_edge_mask(l=max($parent_size)*1.01, r=25);
//   }
// Example: Working with Non-Attachables Like rotate_extrude()
//   back_half()
//     diff("remove")
//       cuboid(40) {
//         attach(TOP)
//           recolor("lightgreen")
//             cyl(l=10,d=30);
//         position(TOP+RIGHT)
//           tags("remove")
//             xrot(90)
//               rotate_extrude()
//                 right(20)
//                   circle(5);
//       }
module diff(neg, pos, keep)
{
    // Don't perform the operation if the current tags are hidden
    if (_attachment_is_shown($tags)) {
        difference() {
            if (pos != undef) {
                show(pos) children();
            } else {
                if (keep == undef) {
                    hide(neg) children();
                } else {
                    hide(str(neg," ",keep)) children();
                }
            }
            show(neg) children();
        }
    }
    if (keep!=undef) {
        show(keep) children();
    } else if (pos!=undef) {
        hide(str(pos," ",neg)) children();
    }
}


// Module: intersect()
// Usage:
//   intersect(a, [keep=]) {...}
//   intersect(a, b, [keep=]) {...}
// Topics: Attachments
// See Also: tags(), recolor(), show(), hide(), diff()
// Description:
//   If `a` is given, takes the union of all children with tags that are in `a`, and `intersection()`s
//   them with the union of all children with tags in `b`.  If `b` is not given, then the union of all
//   items with tags in `a` are intersection()ed with the union of all items without tags in `a`.  If
//   `keep` is given, then the result is unioned with all the children with tags in `keep`.  If `keep`
//   is not given, all children without tags in `a` or `b` are unioned with the result.
//   Cannot be used in conjunction with `diff()` or `hulling()` on the same parent object.
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   a = String containing space delimited set of tag names of children.
//   b = String containing space delimited set of tag names of children.
//   ---
//   keep = String containing space delimited set of tag names of children to keep whole.
// Example:
//   intersect("wheel", "mask", keep="axle")
//   sphere(d=100, $tags="wheel") {
//       attach(CENTER) cube([40,100,100], anchor=CENTER, $tags="mask");
//       attach(CENTER) xcyl(d=40, l=100, $tags="axle");
//   }
// Example: Working with Non-Attachables
//   intersect("A", "B")
//   cuboid(50, $tags="A") {
//       tags("B")
//         hull() {
//           down(25)
//             linear_extrude(height=0.01)
//               square(55,center=true);
//           up(25)
//             linear_extrude(height=0.01)
//               circle(d=45);
//         }
//   }
module intersect(a, b=undef, keep=undef)
{
    // Don't perform the operation if the current tags are hidden
    if (_attachment_is_shown($tags)) {
        intersection() {
            if (b != undef) {
                show(b) children();
            } else {
                if (keep == undef) {
                    hide(a) children();
                } else {
                    hide(str(a," ",keep)) children();
                }
            }
            show(a) children();
        }
    }
    if (keep!=undef) {
        show(keep) children();
    } else if (b!=undef) {
        hide(str(a," ",b)) children();
    }
}



// Module: hulling()
// Usage:
//   hulling(a) {...}
// Topics: Attachments
// See Also: tags(), recolor(), show(), hide(), diff(), intersect()
// Description:
//   If `a` is not given, then all children are `hull()`ed together.
//   If `a` is given as a string, then all children with `$tags` that are in `a` are
//   `hull()`ed together and the result is then unioned with all the remaining children.
//   Cannot be used in conjunction with `diff()` or `intersect()` on the same parent object.
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   a = String containing space delimited set of tag names of children to hull.
// Example:
//   hulling("body")
//   sphere(d=100, $tags="body") {
//       attach(CENTER) cube([40,90,90], anchor=CENTER, $tags="body");
//       attach(CENTER) xcyl(d=40, l=120, $tags="other");
//   }
module hulling(a)
{
    if (is_undef(a)) {
        hull() children();
    } else {
        hull() show(a) children();
        children();
    }
}



// Section: Attachable Masks


// Module: edge_mask()
// Usage:
//   edge_mask([edges], [except]) {...}
// Topics: Attachments
// See Also: attachable(), position(), attach(), face_profile(), edge_profile(), corner_mask()
// Description:
//   Takes a 3D mask shape, and attaches it to the given edges, with the appropriate orientation to be
//   `diff()`ed away.  The mask shape should be vertically oriented (Z-aligned) with the back-right
//   quadrant (X+Y+) shaped to be diffed away from the edge of parent attachable shape.
//   For details on specifying the edges to mask see [Specifying Edges](edges.scad#section-specifying-edges).
//   For a step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Figure: A Typical Edge Rounding Mask
//   module roundit(l,r) difference() {
//       translate([-1,-1,-l/2])
//           cube([r+1,r+1,l]);
//       translate([r,r])
//           cylinder(h=l+1,r=r,center=true, $fn=quantup(segs(r),4));
//   }
//   roundit(l=30,r=10);
// Arguments:
//   edges = Edges to mask.  See [Specifying Edges](edges.scad#section-specifying-edges).  Default: All edges.
//   except = Edges to explicitly NOT mask.  See [Specifying Edges](edges.scad#section-specifying-edges).  Default: No edges.
// Side Effects:
//   Sets `$tags = "mask"` for all children.
// Example:
//   diff("mask")
//   cube([50,60,70],center=true)
//       edge_mask([TOP,"Z"],except=[BACK,TOP+LEFT])
//           rounding_edge_mask(l=71,r=10);
module edge_mask(edges=EDGES_ALL, except=[]) {
    assert($parent_geom != undef, "No object to attach to!");
    edges = _edges(edges, except=except);
    vecs = [
        for (i = [0:3], axis=[0:2])
        if (edges[axis][i]>0)
        EDGE_OFFSETS[axis][i]
    ];
    for (vec = vecs) {
        vcount = (vec.x?1:0) + (vec.y?1:0) + (vec.z?1:0);
        assert(vcount == 2, "Not an edge vector!");
        anch = _find_anchor(vec, $parent_geom);
        $attach_to = undef;
        $attach_anchor = anch;
        $attach_norot = true;
        $tags = "mask";
        rotang =
            vec.z<0? [90,0,180+v_theta(vec)] :
            vec.z==0 && sign(vec.x)==sign(vec.y)? 135+v_theta(vec) :
            vec.z==0 && sign(vec.x)!=sign(vec.y)? [0,180,45+v_theta(vec)] :
            [-90,0,180+v_theta(vec)];
        translate(anch[1]) rot(rotang) children();
    }
}


// Module: corner_mask()
// Usage:
//   corner_mask([corners], [except]) {...}
// Topics: Attachments
// See Also: attachable(), position(), attach(), face_profile(), edge_profile(), edge_mask()
// Description:
//   Takes a 3D mask shape, and attaches it to the specified corners, with the appropriate orientation to
//   be `diff()`ed away.  The 3D corner mask shape should be designed to mask away the X+Y+Z+ octant.
//   See [Specifying Corners](edges.scad#section-specifying-corners) for information on how to specify corner sets.  
//   For a step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   corners = Corners to mask.  See [Specifying Corners](edges.scad#section-specifying-corners).  Default: All corners.
//   except = Corners to explicitly NOT mask.  See [Specifying Corners](edges.scad#section-specifying-corners).  Default: No corners.
// Side Effects:
//   Sets `$tags = "mask"` for all children.
// Example:
//   diff("mask")
//   cube(100, center=true)
//       corner_mask([TOP,FRONT],LEFT+FRONT+TOP)
//           difference() {
//               translate(-0.01*[1,1,1]) cube(20);
//               translate([20,20,20]) sphere(r=20);
//           }
module corner_mask(corners=CORNERS_ALL, except=[]) {
    assert($parent_geom != undef, "No object to attach to!");
    corners = _corners(corners, except=except);
    vecs = [for (i = [0:7]) if (corners[i]>0) CORNER_OFFSETS[i]];
    for (vec = vecs) {
        vcount = (vec.x?1:0) + (vec.y?1:0) + (vec.z?1:0);
        assert(vcount == 3, "Not an edge vector!");
        anch = _find_anchor(vec, $parent_geom);
        $attach_to = undef;
        $attach_anchor = anch;
        $attach_norot = true;
        $tags = "mask";
        rotang = vec.z<0?
            [  0,0,180+v_theta(vec)-45] :
            [180,0,-90+v_theta(vec)-45];
        translate(anch[1]) rot(rotang) children();
    }
}


// Module: face_profile()
// Usage:
//   face_profile(faces, r|d=, [convexity=]) {...}
// Topics: Attachments
// See Also: attachable(), position(), attach(), edge_profile(), corner_profile()
// Description:
//   Given a 2D edge profile, extrudes it into a mask for all edges and corners bounding each given face.
//   See  [Specifying Faces](edges.scad#section-specifying-faces) for information on specifying faces.  
//   For a step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   faces = Faces to mask edges and corners of.
//   r = Radius of corner mask.
//   ---
//   d = Diameter of corner mask.
//   convexity = Max number of times a line could intersect the perimeter of the mask shape.  Default: 10
// Side Effects:
//   Sets `$tags = "mask"` for all children.
// Example:
//   diff("mask")
//   cube([50,60,70],center=true)
//       face_profile(TOP,r=10)
//           mask2d_roundover(r=10);
module face_profile(faces=[], r, d, convexity=10) {
    faces = is_vector(faces)? [faces] : faces;
    assert(all([for (face=faces) is_vector(face) && sum([for (x=face) x!=0? 1 : 0])==1]), "Vector in faces doesn't point at a face.");
    r = get_radius(r=r, d=d, dflt=undef);
    assert(is_num(r) && r>0);
    edge_profile(faces) children();
    corner_profile(faces, convexity=convexity, r=r) children();
}


// Module: edge_profile()
// Usage:
//   edge_profile([edges], [except], [convexity]) {...}
// Topics: Attachments
// See Also: attachable(), position(), attach(), face_profile(), corner_profile()
// Description:
//   Takes a 2D mask shape and attaches it to the selected edges, with the appropriate orientation and
//   extruded length to be `diff()`ed away, to give the edge a matching profile.
//   For details on specifying the edges to mask see [Specifying Edges](edges.scad#section-specifying-edges).
//   For a step-by-step
//   explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   edges = Edges to mask.  See [Specifying Edges](edges.scad#section-specifying-edges).  Default: All edges.
//   except = Edges to explicitly NOT mask.  See [Specifying Edges](edges.scad#section-specifying-edges).  Default: No edges.
//   convexity = Max number of times a line could intersect the perimeter of the mask shape.  Default: 10
// Side Effects:
//   Sets `$tags = "mask"` for all children.
// Example:
//   diff("mask")
//   cube([50,60,70],center=true)
//       edge_profile([TOP,"Z"],except=[BACK,TOP+LEFT])
//           mask2d_roundover(r=10, inset=2);
module edge_profile(edges=EDGES_ALL, except=[], convexity=10) {
    assert($parent_geom != undef, "No object to attach to!");
    edges = _edges(edges, except=except);
    vecs = [
        for (i = [0:3], axis=[0:2])
        if (edges[axis][i]>0)
        EDGE_OFFSETS[axis][i]
    ];
    for (vec = vecs) {
        vcount = (vec.x?1:0) + (vec.y?1:0) + (vec.z?1:0);
        assert(vcount == 2, "Not an edge vector!");
        anch = _find_anchor(vec, $parent_geom);
        $attach_to = undef;
        $attach_anchor = anch;
        $attach_norot = true;
        $tags = "mask";
        psize = point3d($parent_size);
        length = [for (i=[0:2]) if(!vec[i]) psize[i]][0]+0.1;
        rotang =
            vec.z<0? [90,0,180+v_theta(vec)] :
            vec.z==0 && sign(vec.x)==sign(vec.y)? 135+v_theta(vec) :
            vec.z==0 && sign(vec.x)!=sign(vec.y)? [0,180,45+v_theta(vec)] :
            [-90,0,180+v_theta(vec)];
        translate(anch[1]) {
            rot(rotang) {
                linear_extrude(height=length, center=true, convexity=convexity) {
                    children();
                }
            }
        }
    }
}

// Module: corner_profile()
// Usage:
//   corner_profile([corners], [except], <r=|d=>, [convexity=]) {...}
// Topics: Attachments
// See Also: attachable(), position(), attach(), face_profile(), edge_profile()
// Description:
//   Takes a 2D mask shape, rotationally extrudes and converts it into a corner mask, and attaches it
//   to the selected corners with the appropriate orientation.  Tags it as a "mask" to allow it to be
//   `diff()`ed away, to give the corner a matching profile.
//   See [Specifying Corners](edges.scad#section-specifying-corners) for information on how to specify corner sets.  
//   For a step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   corners = Corners to mask.  See [Specifying Corners](edges.scad#section-specifying-corners).  Default: All corners.
//   except = Corners to explicitly NOT mask.  See [Specifying Corners](edges.scad#section-specifying-corners).  Default: No corners.
//   ---
//   r = Radius of corner mask.
//   d = Diameter of corner mask.
//   convexity = Max number of times a line could intersect the perimeter of the mask shape.  Default: 10
// Side Effects:
//   Sets `$tags = "mask"` for all children.
// Example:
//   diff("mask")
//   cuboid([50,60,70],rounding=10,edges="Z",anchor=CENTER) {
//       corner_profile(BOT,r=10)
//           mask2d_teardrop(r=10, angle=40);
//   }
module corner_profile(corners=CORNERS_ALL, except=[], r, d, convexity=10) {
    assert($parent_geom != undef, "No object to attach to!");
    r = get_radius(r=r, d=d, dflt=undef);
    assert(is_num(r));
    corners = _corners(corners, except=except);
    vecs = [for (i = [0:7]) if (corners[i]>0) CORNER_OFFSETS[i]];
    for (vec = vecs) {
        vcount = (vec.x?1:0) + (vec.y?1:0) + (vec.z?1:0);
        assert(vcount == 3, "Not an edge vector!");
        anch = _find_anchor(vec, $parent_geom);
        $attach_to = undef;
        $attach_anchor = anch;
        $attach_norot = true;
        $tags = "mask";
        rotang = vec.z<0?
            [  0,0,180+v_theta(vec)-45] :
            [180,0,-90+v_theta(vec)-45];
        translate(anch[1]) {
            rot(rotang) {
                render(convexity=convexity)
                difference() {
                    translate(-0.1*[1,1,1]) cube(r+0.1, center=false);
                    right(r) back(r) zrot(180) {
                        rotate_extrude(angle=90, convexity=convexity) {
                            xflip() left(r) {
                                difference() {
                                    square(r,center=false);
                                    children();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


// Section: Making your objects attachable


// Module: attachable()
//
// Usage: Square/Trapezoid Geometry
//   attachable(anchor, spin, two_d=true, size=, [size2=], [shift=], ...) {...}
// Usage: Circle/Oval Geometry
//   attachable(anchor, spin, two_d=true, r=|d=, ...) {...}
// Usage: 2D Path/Polygon Geometry
//   attachable(anchor, spin, two_d=true, path=, [extent=], ...) {...}
// Usage: 2D Region Geometry
//   attachable(anchor, spin, two_d=true, region=, [extent=], ...) {...}
// Usage: Cubical/Prismoidal Geometry
//   attachable(anchor, spin, [orient], size=, [size2=], [shift=], ...) {...}
// Usage: Cylindrical Geometry
//   attachable(anchor, spin, [orient], r=|d=, l=, [axis=], ...) {...}
// Usage: Conical Geometry
//   attachable(anchor, spin, [orient], r1=|d1=, r2=|d2=, l=, [axis=], ...) {...}
// Usage: Spheroid/Ovoid Geometry
//   attachable(anchor, spin, [orient], r=|d=, ...) {...}
// Usage: Extruded Path/Polygon Geometry
//   attachable(anchor, spin, path=, l=|h=, [extent=], ...) {...}
// Usage: Extruded Region Geometry
//   attachable(anchor, spin, region=, l=|h=, [extent=], ...) {...}
// Usage: VNF Geometry
//   attachable(anchor, spin, [orient], vnf=, [extent=], ...) {...}
//
// Topics: Attachments
// See Also: reorient()
//
// Description:
//   Manages the anchoring, spin, orientation, and attachments for a 3D volume or 2D area.
//   A managed 3D volume is assumed to be vertically (Z-axis) oriented, and centered.
//   A managed 2D area is just assumed to be centered.  The shape to be managed is given
//   as the first child to this module, and the second child should be given as `children()`.
//   For example, to manage a conical shape:
//   ```openscad
//   attachable(anchor, spin, orient, r1=r1, r2=r2, l=h) {
//       cyl(r1=r1, r2=r2, l=h);
//       children();
//   }
//   ```
//   .
//   If this is *not* run as a child of `attach()` with the `to` argument
//   given, then the following transformations are performed in order:
//   * Translates so the `anchor` point is at the origin (0,0,0).
//   * Rotates around the Z axis by `spin` degrees counter-clockwise.
//   * Rotates so the top of the part points towards the vector `orient`.
//   .
//   If this is called as a child of `attach(from,to)`, then the info
//   for the anchor points referred to by `from` and `to` are fetched,
//   which will include position, direction, and spin.  With that info,
//   the following transformations are performed:
//   * Translates this part so it's anchor position matches the parent's anchor position.
//   * Rotates this part so it's anchor direction vector exactly opposes the parent's anchor direction vector.
//   * Rotates this part so it's anchor spin matches the parent's anchor spin.
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
//
// Arguments:
//   anchor = Translate so anchor point is at origin (0,0,0).  See [anchor](attachments.scad#anchor).  Default: `CENTER`
//   spin = Rotate this many degrees around the Z axis after anchor.  See [spin](attachments.scad#spin).  Default: `0`
//   orient = Vector to rotate top towards, after spin.  See [orient](attachments.scad#orient).  Default: `UP`
//   ---
//   size = If given as a 3D vector, contains the XY size of the bottom of the cuboidal/prismoidal volume, and the Z height.  If given as a 2D vector, contains the front X width of the rectangular/trapezoidal shape, and the Y length.
//   size2 = If given as a 2D vector, contains the XY size of the top of the prismoidal volume.  If given as a number, contains the back width of the trapezoidal shape.
//   shift = If given as a 2D vector, shifts the top of the prismoidal or conical shape by the given amount.  If given as a number, shifts the back of the trapezoidal shape right by that amount.  Default: No shift.
//   r = Radius of the cylindrical/conical volume.  Can be a scalar, or a list of sizes per axis.
//   d = Diameter of the cylindrical/conical volume.  Can be a scalar, or a list of sizes per axis.
//   r1 = Radius of the bottom of the conical volume.  Can be a scalar, or a list of sizes per axis.
//   r2 = Radius of the top of the conical volume.  Can be a scalar, or a list of sizes per axis.
//   d1 = Diameter of the bottom of the conical volume.  Can be a scalar, a list of sizes per axis.
//   d2 = Diameter of the top of the conical volume.  Can be a scalar, a list of sizes per axis.
//   l/h = Length of the cylindrical, conical, or extruded path volume along axis.
//   vnf = The [VNF](vnf.scad) of the volume.
//   path = The path to generate a polygon from.
//   region = The region to generate a shape from.
//   extent = If true, calculate anchors by extents, rather than intersection, for VNFs and paths.  Default: true.
//   cp = If given, specifies the centerpoint of the volume.  Default: `[0,0,0]`
//   offset = If given, offsets the perimeter of the volume around the centerpoint.
//   anchors = If given as a list of anchor points, allows named anchor points.
//   two_d = If true, the attachable shape is 2D.  If false, 3D.  Default: false (3D)
//   axis = The vector pointing along the axis of a cylinder geometry.  Default: UP
//
// Side Effects:
//   `$parent_anchor` is set to the parent object's `anchor` value.
//   `$parent_spin` is set to the parent object's `spin` value.
//   `$parent_orient` is set to the parent object's `orient` value.
//   `$parent_geom` is set to the parent object's `geom` value.
//   `$parent_size` is set to the parent object's cubical `[X,Y,Z]` volume size.
//
// Example(NORENDER): Cubical Shape
//   attachable(anchor, spin, orient, size=size) {
//       cube(size, center=true);
//       children();
//   }
//
// Example(NORENDER): Prismoidal Shape
//   attachable(
//       anchor, spin, orient,
//       size=point3d(botsize,h),
//       size2=topsize,
//       shift=shift
//   ) {
//       prismoid(botsize, topsize, h=h, shift=shift);
//       children();
//   }
//
// Example(NORENDER): Cylindrical Shape, Z-Axis Aligned
//   attachable(anchor, spin, orient, r=r, l=h) {
//       cyl(r=r, l=h);
//       children();
//   }
//
// Example(NORENDER): Cylindrical Shape, Y-Axis Aligned
//   attachable(anchor, spin, orient, r=r, l=h, axis=BACK) {
//       cyl(r=r, l=h);
//       children();
//   }
//
// Example(NORENDER): Cylindrical Shape, X-Axis Aligned
//   attachable(anchor, spin, orient, r=r, l=h, axis=RIGHT) {
//       cyl(r=r, l=h);
//       children();
//   }
//
// Example(NORENDER): Conical Shape, Z-Axis Aligned
//   attachable(anchor, spin, orient, r1=r1, r2=r2, l=h) {
//       cyl(r1=r1, r2=r2, l=h);
//       children();
//   }
//
// Example(NORENDER): Conical Shape, Y-Axis Aligned
//   attachable(anchor, spin, orient, r1=r1, r2=r2, l=h, axis=BACK) {
//       cyl(r1=r1, r2=r2, l=h);
//       children();
//   }
//
// Example(NORENDER): Conical Shape, X-Axis Aligned
//   attachable(anchor, spin, orient, r1=r1, r2=r2, l=h, axis=RIGHT) {
//       cyl(r1=r1, r2=r2, l=h);
//       children();
//   }
//
// Example(NORENDER): Spherical Shape
//   attachable(anchor, spin, orient, r=r) {
//       sphere(r=r);
//       children();
//   }
//
// Example(NORENDER): Extruded Polygon Shape, by Extents
//   attachable(anchor, spin, orient, path=path, l=length) {
//       linear_extrude(height=length, center=true)
//           polygon(path);
//       children();
//   }
//
// Example(NORENDER): Extruded Polygon Shape, by Intersection
//   attachable(anchor, spin, orient, path=path, l=length, extent=false) {
//       linear_extrude(height=length, center=true)
//           polygon(path);
//       children();
//   }
//
// Example(NORENDER): Arbitrary VNF Shape, by Extents
//   attachable(anchor, spin, orient, vnf=vnf) {
//       vnf_polyhedron(vnf);
//       children();
//   }
//
// Example(NORENDER): Arbitrary VNF Shape, by Intersection
//   attachable(anchor, spin, orient, vnf=vnf, extent=false) {
//       vnf_polyhedron(vnf);
//       children();
//   }
//
// Example(NORENDER): 2D Rectangular Shape
//   attachable(anchor, spin, orient, two_d=true, size=size) {
//       square(size, center=true);
//       children();
//   }
//
// Example(NORENDER): 2D Trapezoidal Shape
//   attachable(
//       anchor, spin, orient,
//       two_d=true,
//       size=[x1,y],
//       size2=x2,
//       shift=shift
//   ) {
//       trapezoid(w1=x1, w2=x2, h=y, shift=shift);
//       children();
//   }
//
// Example(NORENDER): 2D Circular Shape
//   attachable(anchor, spin, orient, two_d=true, r=r) {
//       circle(r=r);
//       children();
//   }
//
// Example(NORENDER): Arbitrary 2D Polygon Shape, by Extents
//   attachable(anchor, spin, orient, two_d=true, path=path) {
//       polygon(path);
//       children();
//   }
//
// Example(NORENDER): Arbitrary 2D Polygon Shape, by Intersection
//   attachable(anchor, spin, orient, two_d=true, path=path, extent=false) {
//       polygon(path);
//       children();
//   }
module attachable(
    anchor, spin, orient,
    size, size2, shift,
    r,r1,r2, d,d1,d2, l,h,
    vnf, path, region,
    extent=true,
    cp=[0,0,0],
    offset=[0,0,0],
    anchors=[],
    two_d=false,
    axis=UP
) {
    dummy1 =
        assert($children==2, "attachable() expects exactly two children; the shape to manage, and the union of all attachment candidates.")
        assert(is_undef(anchor) || is_vector(anchor) || is_string(anchor), str("Got: ",anchor))
        assert(is_undef(spin)   || is_vector(spin,3) || is_num(spin), str("Got: ",spin))
        assert(is_undef(orient) || is_vector(orient,3), str("Got: ",orient));
    anchor = default(anchor, CENTER);
    spin =   default(spin,   0);
    orient = default(orient, UP);
    region = !is_undef(region)? region :
        !is_undef(path)? [path] :
        undef;
    geom = _attach_geom(
        size=size, size2=size2, shift=shift,
        r=r, r1=r1, r2=r2, h=h,
        d=d, d1=d1, d2=d2, l=l,
        vnf=vnf, region=region, extent=extent,
        cp=cp, offset=offset, anchors=anchors,
        two_d=two_d, axis=axis
    );
    m = _attach_transform(anchor,spin,orient,geom);
    multmatrix(m) {
        $parent_anchor = anchor;
        $parent_spin   = spin;
        $parent_orient = orient;
        $parent_geom   = geom;
        $parent_size   = _attach_geom_size(geom);
        $attach_to   = undef;
        do_show = _attachment_is_shown($tags);
        if (do_show) {
            if (is_undef($color)) {
                children(0);
            } else color($color) {
                $color = undef;
                children(0);
            }
        }
        children(1);
    }
}





// Function: named_anchor()
// Usage:
//   a = named_anchor(name, pos, [orient], [spin]);
// Topics: Attachments
// See Also: reorient(), attachable()
// Description:
//   Creates an anchor data structure.  For a more step-by-step explanation of attachments,
//   see the [[Attachments Tutorial|Tutorial-Attachments]].
// Arguments:
//   name = The string name of the anchor.  Lowercase.  Words separated by single dashes.  No spaces.
//   pos = The [X,Y,Z] position of the anchor.
//   orient = A vector pointing in the direction parts should project from the anchor position.
//   spin = If needed, the angle to rotate the part around the direction vector.
function named_anchor(name, pos=[0,0,0], orient=UP, spin=0) = [name, pos, orient, spin];


// Function: reorient()
//
// Usage: Square/Trapezoid Geometry
//   mat = reorient(anchor, spin, [orient], two_d=true, size=, [size2=], [shift=], ...);
//   pts = reorient(anchor, spin, [orient], two_d=true, size=, [size2=], [shift=], p=, ...);
// Usage: Circle/Oval Geometry
//   mat = reorient(anchor, spin, [orient], two_d=true, r=|d=, ...);
//   pts = reorient(anchor, spin, [orient], two_d=true, r=|d=, p=, ...);
// Usage: 2D Path/Polygon Geometry
//   mat = reorient(anchor, spin, [orient], two_d=true, path=, [extent=], ...);
//   pts = reorient(anchor, spin, [orient], two_d=true, path=, [extent=], p=, ...);
// Usage: 2D Region/Polygon Geometry
//   mat = reorient(anchor, spin, [orient], two_d=true, region=, [extent=], ...);
//   pts = reorient(anchor, spin, [orient], two_d=true, region=, [extent=], p=, ...);
// Usage: Cubical/Prismoidal Geometry
//   mat = reorient(anchor, spin, [orient], size=, [size2=], [shift=], ...);
//   pts = reorient(anchor, spin, [orient], size=, [size2=], [shift=], p=, ...);
// Usage: Cylindrical Geometry
//   mat = reorient(anchor, spin, [orient], r=|d=, l=, [axis=], ...);
//   pts = reorient(anchor, spin, [orient], r=|d=, l=, [axis=], p=, ...);
// Usage: Conical Geometry
//   mat = reorient(anchor, spin, [orient], r1=|d1=, r2=|d2=, l=, [axis=], ...);
//   pts = reorient(anchor, spin, [orient], r1=|d1=, r2=|d2=, l=, [axis=], p=, ...);
// Usage: Spheroid/Ovoid Geometry
//   mat = reorient(anchor, spin, [orient], r|d=, ...);
//   pts = reorient(anchor, spin, [orient], r|d=, p=, ...);
// Usage: Extruded Path/Polygon Geometry
//   mat = reorient(anchor, spin, [orient], path=, l=|h=, [extent=], ...);
//   pts = reorient(anchor, spin, [orient], path=, l=|h=, [extent=], p=, ...);
// Usage: Extruded Region Geometry
//   mat = reorient(anchor, spin, [orient], region=, l=|h=, [extent=], ...);
//   pts = reorient(anchor, spin, [orient], region=, l=|h=, [extent=], p=, ...);
// Usage: VNF Geometry
//   mat = reorient(anchor, spin, [orient], vnf, [extent], ...);
//   pts = reorient(anchor, spin, [orient], vnf, [extent], p=, ...);
//
// Topics: Attachments
// See Also: reorient(), attachable()
//
// Description:
//   Given anchor, spin, orient, and general geometry info for a managed volume, this calculates
//   the transformation matrix needed to be applied to the contents of that volume.  A managed 3D
//   volume is assumed to be vertically (Z-axis) oriented, and centered.  A managed 2D area is just
//   assumed to be centered.
//   .
//   If `p` is not given, then the transformation matrix will be returned.
//   If `p` contains a VNF, a new VNF will be returned with the vertices transformed by the matrix.
//   If `p` contains a path, a new path will be returned with the vertices transformed by the matrix.
//   If `p` contains a point, a new point will be returned, transformed by the matrix.
//   .
//   If `$attach_to` is not defined, then the following transformations are performed in order:
//   * Translates so the `anchor` point is at the origin (0,0,0).
//   * Rotates around the Z axis by `spin` degrees counter-clockwise.
//   * Rotates so the top of the part points towards the vector `orient`.
//   .
//   If `$attach_to` is defined, as a consequence of `attach(from,to)`, then
//   the following transformations are performed in order:
//   * Translates this part so it's anchor position matches the parent's anchor position.
//   * Rotates this part so it's anchor direction vector exactly opposes the parent's anchor direction vector.
//   * Rotates this part so it's anchor spin matches the parent's anchor spin.
//   .
//   For a more step-by-step explanation of attachments, see the [[Attachments Tutorial|Tutorial-Attachments]].
//
// Arguments:
//   anchor = Translate so anchor point is at origin (0,0,0).  See [anchor](attachments.scad#anchor).  Default: `CENTER`
//   spin = Rotate this many degrees around the Z axis after anchor.  See [spin](attachments.scad#spin).  Default: `0`
//   orient = Vector to rotate top towards, after spin.  See [orient](attachments.scad#orient).  Default: `UP`
//   ---
//   size = If given as a 3D vector, contains the XY size of the bottom of the cuboidal/prismoidal volume, and the Z height.  If given as a 2D vector, contains the front X width of the rectangular/trapezoidal shape, and the Y length.
//   size2 = If given as a 2D vector, contains the XY size of the top of the prismoidal volume.  If given as a number, contains the back width of the trapezoidal shape.
//   shift = If given as a 2D vector, shifts the top of the prismoidal or conical shape by the given amount.  If given as a number, shifts the back of the trapezoidal shape right by that amount.  Default: No shift.
//   r = Radius of the cylindrical/conical volume.  Can be a scalar, or a list of sizes per axis.
//   d = Diameter of the cylindrical/conical volume.  Can be a scalar, or a list of sizes per axis.
//   r1 = Radius of the bottom of the conical volume.  Can be a scalar, or a list of sizes per axis.
//   r2 = Radius of the top of the conical volume.  Can be a scalar, or a list of sizes per axis.
//   d1 = Diameter of the bottom of the conical volume.  Can be a scalar, a list of sizes per axis.
//   d2 = Diameter of the top of the conical volume.  Can be a scalar, a list of sizes per axis.
//   l/h = Length of the cylindrical, conical, or extruded path volume along axis.
//   vnf = The [VNF](vnf.scad) of the volume.
//   path = The path to generate a polygon from.
//   region = The region to generate a shape from.
//   extent = If true, calculate anchors by extents, rather than intersection.  Default: false.
//   cp = If given, specifies the centerpoint of the volume.  Default: `[0,0,0]`
//   offset = If given, offsets the perimeter of the volume around the centerpoint.
//   anchors = If given as a list of anchor points, allows named anchor points.
//   two_d = If true, the attachable shape is 2D.  If false, 3D.  Default: false (3D)
//   axis = The vector pointing along the axis of a cylinder geometry.  Default: UP
//   p = The VNF, path, or point to transform.
function reorient(
    anchor, spin, orient,
    size, size2, shift,
    r,r1,r2, d,d1,d2, l,h,
    vnf, path, region,
    extent=true,
    offset=[0,0,0],
    cp=[0,0,0],
    anchors=[],
    two_d=false,
    axis=UP,
    p=undef
) = 
    assert(is_undef(anchor) || is_vector(anchor) || is_string(anchor), str("Got: ",anchor))
    assert(is_undef(spin)   || is_vector(spin,3) || is_num(spin), str("Got: ",spin))
    assert(is_undef(orient) || is_vector(orient,3), str("Got: ",orient))
    let(
        anchor = default(anchor, CENTER),
        spin =   default(spin,   0),
        orient = default(orient, UP),
        region = !is_undef(region)? region :
            !is_undef(path)? [path] :
            undef
    )
    (anchor==CENTER && spin==0 && orient==UP && p!=undef)? p : let(
        geom = _attach_geom(
            size=size, size2=size2, shift=shift,
            r=r, r1=r1, r2=r2, h=h,
            d=d, d1=d1, d2=d2, l=l,
            vnf=vnf, region=region, extent=extent,
            cp=cp, offset=offset, anchors=anchors,
            two_d=two_d, axis=axis
        ),
        $attach_to = undef
    ) _attach_transform(anchor,spin,orient,geom,p);



//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Attachment internal functions


/// Internal Function: _attach_geom()
//
// Usage: Square/Trapezoid Geometry
//   geom = _attach_geom(two_d=true, size=, [size2=], [shift=], ...);
// Usage: Circle/Oval Geometry
//   geom = _attach_geom(two_d=true, r=|d=, ...);
// Usage: 2D Path/Polygon/Region Geometry
//   geom = _attach_geom(two_d=true, region=, [extent=], ...);
// Usage: Cubical/Prismoidal Geometry
//   geom = _attach_geom(size=, [size2=], [shift=], ...);
// Usage: Cylindrical Geometry
//   geom = _attach_geom(r=|d=, l=|h=, [axis=], ...);
// Usage: Conical Geometry
//   geom = _attach_geom(r1|d1=, r2=|d2=, l=, [axis=], ...);
// Usage: Spheroid/Ovoid Geometry
//   geom = _attach_geom(r=|d=, ...);
// Usage: Extruded 2D Path/Polygon/Region Geometry
//   geom = _attach_geom(region=, l=|h=, [extent=], ...);
// Usage: VNF Geometry
//   geom = _attach_geom(vnf=, [extent=], ...);
//
/// Topics: Attachments
/// See Also: reorient(), attachable()
//
// Description:
//   Given arguments that describe the geometry of an attachable object, returns the internal geometry description.
//   This will probably not not ever need to be called by the end user.
//
// Arguments:
//   ---
//   size = If given as a 3D vector, contains the XY size of the bottom of the cuboidal/prismoidal volume, and the Z height.  If given as a 2D vector, contains the front X width of the rectangular/trapezoidal shape, and the Y length.
//   size2 = If given as a 2D vector, contains the XY size of the top of the prismoidal volume.  If given as a number, contains the back width of the trapezoidal shape.
//   shift = If given as a 2D vector, shifts the top of the prismoidal or conical shape by the given amount.  If given as a number, shifts the back of the trapezoidal shape right by that amount.  Default: No shift.
//   r = Radius of the cylindrical/conical volume.  Can be a scalar, or a list of sizes per axis.
//   d = Diameter of the cylindrical/conical volume.  Can be a scalar, or a list of sizes per axis.
//   r1 = Radius of the bottom of the conical volume.  Can be a scalar, or a list of sizes per axis.
//   r2 = Radius of the top of the conical volume.  Can be a scalar, or a list of sizes per axis.
//   d1 = Diameter of the bottom of the conical volume.  Can be a scalar, a list of sizes per axis.
//   d2 = Diameter of the top of the conical volume.  Can be a scalar, a list of sizes per axis.
//   l/h = Length of the cylindrical, conical or extruded region volume along axis.
//   vnf = The [VNF](vnf.scad) of the volume.
//   region = The region to generate a shape from.
//   extent = If true, calculate anchors by extents, rather than intersection.  Default: true.
//   cp = If given, specifies the centerpoint of the volume.  Default: `[0,0,0]`
//   offset = If given, offsets the perimeter of the volume around the centerpoint.
//   anchors = If given as a list of anchor points, allows named anchor points.
//   two_d = If true, the attachable shape is 2D.  If false, 3D.  Default: false (3D)
//   axis = The vector pointing along the axis of a cylinder geometry.  Default: UP
//
// Example(NORENDER): Cubical Shape
//   geom = _attach_geom(size=size);
//
// Example(NORENDER): Prismoidal Shape
//   geom = _attach_geom(
//       size=point3d(botsize,h),
//       size2=topsize, shift=shift
//   );
//
// Example(NORENDER): Cylindrical Shape, Z-Axis Aligned
//   geom = _attach_geom(r=r, h=h);
//
// Example(NORENDER): Cylindrical Shape, Y-Axis Aligned
//   geom = _attach_geom(r=r, h=h, axis=BACK);
//
// Example(NORENDER): Cylindrical Shape, X-Axis Aligned
//   geom = _attach_geom(r=r, h=h, axis=RIGHT);
//
// Example(NORENDER): Conical Shape, Z-Axis Aligned
//   geom = _attach_geom(r1=r1, r2=r2, h=h);
//
// Example(NORENDER): Conical Shape, Y-Axis Aligned
//   geom = _attach_geom(r1=r1, r2=r2, h=h, axis=BACK);
//
// Example(NORENDER): Conical Shape, X-Axis Aligned
//   geom = _attach_geom(r1=r1, r2=r2, h=h, axis=RIGHT);
//
// Example(NORENDER): Spherical Shape
//   geom = _attach_geom(r=r);
//
// Example(NORENDER): Ovoid Shape
//   geom = _attach_geom(r=[r_x, r_y, r_z]);
//
// Example(NORENDER): Arbitrary VNF Shape, Anchored by Extents
//   geom = _attach_geom(vnf=vnf);
//
// Example(NORENDER): Arbitrary VNF Shape, Anchored by Intersection
//   geom = _attach_geom(vnf=vnf, extent=false);
//
// Example(NORENDER): 2D Rectangular Shape
//   geom = _attach_geom(two_d=true, size=size);
//
// Example(NORENDER): 2D Trapezoidal Shape
//   geom = _attach_geom(two_d=true, size=[x1,y], size2=x2, shift=shift);
//
// Example(NORENDER): 2D Circular Shape
//   geom = _attach_geom(two_d=true, r=r);
//
// Example(NORENDER): 2D Oval Shape
//   geom = _attach_geom(two_d=true, r=[r_x, r_y]);
//
// Example(NORENDER): Arbitrary 2D Region Shape, Anchored by Extents
//   geom = _attach_geom(two_d=true, region=region);
//
// Example(NORENDER): Arbitrary 2D Region Shape, Anchored by Intersection
//   geom = _attach_geom(two_d=true, region=region, extent=false);
//
// Example(NORENDER): Extruded Region, Anchored by Extents
//   geom = _attach_geom(region=region, l=height);
//
// Example(NORENDER): Extruded Region, Anchored by Intersection
//   geom = _attach_geom(region=region, l=length, extent=false);
//
function _attach_geom(
    size, size2, shift,
    r,r1,r2, d,d1,d2, l,h,
    vnf, region,
    extent=true,
    cp=[0,0,0],
    offset=[0,0,0],
    anchors=[],
    two_d=false,
    axis=UP
) =
    assert(is_bool(extent))
    assert(is_vector(cp) || is_string(cp))
    assert(is_vector(offset))
    assert(is_list(anchors))
    assert(is_bool(two_d))
    assert(is_vector(axis))
    !is_undef(size)? (
        two_d? (
            let(
                size2 = default(size2, size.x),
                shift = default(shift, 0)
            )
            assert(is_vector(size,2))
            assert(is_num(size2))
            assert(is_num(shift))
            ["rect", point2d(size), size2, shift, cp, offset, anchors]
        ) : (
            let(
                size2 = default(size2, point2d(size)),
                shift = default(shift, [0,0])
            )
            assert(is_vector(size,3))
            assert(is_vector(size2,2))
            assert(is_vector(shift,2))
            ["cuboid", size, size2, shift, axis, cp, offset, anchors]
        )
    ) : !is_undef(vnf)? (
        assert(is_vnf(vnf))
        assert(two_d == false)
        extent? ["vnf_extent", vnf, cp, offset, anchors] :
        ["vnf_isect", vnf, cp, offset, anchors]
    ) : !is_undef(region)? (
        assert(is_region(region),2)
        let( l = default(l, h) )
        two_d==true
          ? assert(is_undef(l))
            extent==true
              ? ["rgn_extent", region, cp, offset, anchors]
              : ["rgn_isect",  region, cp, offset, anchors]
          : assert(is_finite(l))
            extent==true
              ? ["xrgn_extent", region, l, cp, offset, anchors]
              : ["xrgn_isect",  region, l, cp, offset, anchors]
    ) :
    let(
        r1 = get_radius(r1=r1,d1=d1,r=r,d=d,dflt=undef)
    )
    !is_undef(r1)? (
        let( l = default(l, h) )
        !is_undef(l)? (
            let(
                shift = default(shift, [0,0]),
                r2 = get_radius(r1=r2,d1=d2,r=r,d=d,dflt=undef)
            )
            assert(is_num(r1) || is_vector(r1,2))
            assert(is_num(r2) || is_vector(r2,2))
            assert(is_num(l))
            assert(is_vector(shift,2))
            ["cyl", r1, r2, l, shift, axis, cp, offset, anchors]
        ) : (
            two_d? (
                assert(is_num(r1) || is_vector(r1,2))
                ["circle", r1, cp, offset, anchors]
            ) : (
                assert(is_num(r1) || is_vector(r1,3))
                ["spheroid", r1, cp, offset, anchors]
            )
        )
    ) :
    assert(false, "Unrecognizable geometry description.");



/// Internal Function: _attach_geom_2d()
// Usage:
//   bool = _attach_geom_2d(geom);
/// Topics: Attachments
/// See Also: reorient(), attachable()
// Description:
//   Returns true if the given attachment geometry description is for a 2D shape.
function _attach_geom_2d(geom) =
    let( type = geom[0] )
    type == "rect" || type == "circle" ||
    type == "rgn_isect" || type == "rgn_extent";


/// Internal Function: _attach_geom_size()
// Usage:
//   bounds = _attach_geom_size(geom);
/// Topics: Attachments
/// See Also: reorient(), attachable()
// Description:
//   Returns the `[X,Y,Z]` bounding size for the given attachment geometry description.
function _attach_geom_size(geom) =
    let( type = geom[0] )
    type == "cuboid"? ( //size, size2, shift
        let(
            size=geom[1], size2=geom[2], shift=point2d(geom[3]),
            maxx = max(size.x,size2.x),
            maxy = max(size.y,size2.y),
            z = size.z
        ) [maxx, maxy, z]
    ) : type == "cyl"? ( //r1, r2, l, shift
        let(
            r1=geom[1], r2=geom[2], l=geom[3],
            shift=point2d(geom[4]), axis=point3d(geom[5]),
            rx1 = default(r1[0],r1),
            ry1 = default(r1[1],r1),
            rx2 = default(r2[0],r2),
            ry2 = default(r2[1],r2),
            maxxr = max(rx1,rx2),
            maxyr = max(ry1,ry2)
        )
        approx(axis,UP)? [2*maxxr,2*maxyr,l] :
        approx(axis,RIGHT)? [l,2*maxyr,2*maxxr] :
        approx(axis,BACK)? [2*maxxr,l,2*maxyr] :
        [2*maxxr, 2*maxyr, l]
    ) : type == "spheroid"? ( //r
        let( r=geom[1] )
        is_num(r)? [2,2,2]*r : v_mul([2,2,2],point3d(r))
    ) : type == "vnf_extent" || type=="vnf_isect"? ( //vnf
        let(
            vnf = geom[1]
        ) vnf==EMPTY_VNF? [0,0,0] :
        let(
            mm = pointlist_bounds(geom[1][0]),
            delt = mm[1]-mm[0]
        ) delt
    ) : type == "xrgn_isect" || type == "xrgn_extent"? ( //path, l
        let(
            mm = pointlist_bounds(flatten(geom[1])),
            delt = mm[1]-mm[0]
        ) [delt.x, delt.y, geom[2]]
    ) : type == "rect"? ( //size, size2
        let(
            size=geom[1], size2=geom[2], shift=geom[3],
            maxx = max(size.x,size2+abs(shift))
        ) [maxx, size.y]
    ) : type == "circle"? ( //r
        let( r=geom[1] )
        is_num(r)? [2,2]*r : v_mul([2,2],point2d(r))
    ) : type == "rgn_isect" || type == "rgn_extent"? ( //path
        let(
            mm = pointlist_bounds(flatten(geom[1])),
            delt = mm[1]-mm[0]
        ) [delt.x, delt.y]
    ) :
    assert(false, "Unknown attachment geometry type.");


/// Internal Function: _attach_transform()
// Usage: To Get a Transformation Matrix
//   mat = _attach_transform(anchor, spin, orient, geom);
// Usage: To Transform Points, Paths, Patches, or VNFs
//   new_p = _attach_transform(anchor, spin, orient, geom, p);
/// Topics: Attachments
/// See Also: reorient(), attachable()
// Description:
//   Returns the affine3d transformation matrix needed to `anchor`, `spin`, and `orient`
//   the given geometry `geom` shape into position.
// Arguments:
//   anchor = Anchor point to translate to the origin `[0,0,0]`.  See [anchor](attachments.scad#anchor).  Default: `CENTER`
//   spin = Rotate this many degrees around the Z axis after anchor.  See [spin](attachments.scad#spin).  Default: `0`
//   orient = Vector to rotate top towards, after spin.  See [orient](attachments.scad#orient).  Default: `UP`
//   geom = The geometry description of the shape.
//   p = If given as a VNF, path, or point, applies the affine3d transformation matrix to it and returns the result.
function _attach_transform(anchor, spin, orient, geom, p) =
    assert(is_undef(anchor) || is_vector(anchor) || is_string(anchor), str("Got: ",anchor))
    assert(is_undef(spin)   || is_vector(spin,3) || is_num(spin), str("Got: ",spin))
    assert(is_undef(orient) || is_vector(orient,3), str("Got: ",orient))
    let(
        anchor = default(anchor, CENTER),
        spin   = default(spin,   0),
        orient = default(orient, UP),
        two_d = _attach_geom_2d(geom),
        m = ($attach_to != undef)? (
            let(
                anch = _find_anchor($attach_to, geom),
                pos = anch[1]
            ) two_d? (
                assert(two_d && is_num(spin))
                affine3d_zrot(spin) *
                rot(to=FWD, from=point3d(anch[2])) *
                affine3d_translate(point3d(-pos))
            ) : (
                assert(is_num(spin) || is_vector(spin,3))
                let(
                    ang = vector_angle(anch[2], DOWN),
                    axis = vector_axis(anch[2], DOWN),
                    ang2 = (anch[2]==UP || anch[2]==DOWN)? 0 : 180-anch[3],
                    axis2 = rot(p=axis,[0,0,ang2])
                )
                affine3d_rot_by_axis(axis2,ang) * (
                    is_num(spin)? affine3d_zrot(ang2+spin) : (
                        affine3d_zrot(spin.z) *
                        affine3d_yrot(spin.y) *
                        affine3d_xrot(spin.x) *
                        affine3d_zrot(ang2)
                    )
                ) * affine3d_translate(point3d(-pos))
            )
        ) : (
            let(
                pos = _find_anchor(anchor, geom)[1]
            ) two_d? (
                assert(two_d && is_num(spin))
                affine3d_zrot(spin) *
                affine3d_translate(point3d(-pos))
            ) : (
                assert(is_num(spin) || is_vector(spin,3))
                let(
                    axis = vector_axis(UP,orient),
                    ang = vector_angle(UP,orient)
                )
                affine3d_rot_by_axis(axis,ang) * (
                    is_num(spin)? affine3d_zrot(spin) : (
                        affine3d_zrot(spin.z) *
                        affine3d_yrot(spin.y) *
                        affine3d_xrot(spin.x)
                    )
                ) * affine3d_translate(point3d(-pos))
            )
        )
    ) is_undef(p)? m :
    is_vnf(p)? [(p==EMPTY_VNF? p : apply(m, p[0])), p[1]] :
    apply(m, p);


function _get_cp(geom) =
    let(cp=select(geom,-3))
    is_vector(cp) ? cp
  : let(
        type = in_list(geom[0],["vnf_extent","vnf_isect"]) ? "vnf"
             : in_list(geom[0],["rgn_extent","rgn_isect"]) ? "path"
             : "other"
    )
    assert(type!="other", "Invalid cp value")
    cp=="centroid" ? centroid(geom[1])
  : let(points = type=="vnf"?geom[1][0]:flatten(force_region(geom[1])))
    cp=="mean" ? mean(points)
  : cp=="box" ? mean(pointlist_bounds(points))
  : assert(false,"Invalid cp specification");


/// Internal Function: _find_anchor()
// Usage:
//   anchorinfo = _find_anchor(anchor, geom);
/// Topics: Attachments
/// See Also: reorient(), attachable()
// Description:
//   Calculates the anchor data for the given `anchor` vector or name, in the given attachment
//   geometry.  Returns `[ANCHOR, POS, VEC, ANG]` where `ANCHOR` is the requested anchorname
//   or vector, `POS` is the anchor position, `VEC` is the direction vector of the anchor, and
//   `ANG` is the angle to align with around the rotation axis of th anchor direction vector.
// Arguments:
//   anchor = Vector or named anchor string.
//   geom = The geometry description of the shape.
function _find_anchor(anchor, geom) =
    let( 
        cp = _get_cp(geom),
        offset_raw = select(geom,-2),
        offset = [for (i=[0:2]) anchor[i]==0? 0 : offset_raw[i]],  // prevents bad centering.
        anchors = last(geom),
        type = geom[0]
    )
    is_string(anchor)? (  
          anchor=="origin"? [anchor, CENTER, UP, 0]
        : let(found = search([anchor], anchors, num_returns_per_match=1)[0])
          assert(found!=[], str("Unknown anchor: ",anchor))
          anchors[found]
    ) : 
    assert(is_vector(anchor),str("anchor=",anchor))
    let(anchor = point3d(anchor))
    anchor==CENTER? [anchor, cp, UP, 0] :
    let(
        oang = (
            approx(point2d(anchor), [0,0])? 0 :
            atan2(anchor.y, anchor.x)+90
        )
    )
    type == "cuboid"? ( //size, size2, shift
        let(all_comps_good = [for (c=anchor) if (c!=sign(c)) 1]==[])
        assert(all_comps_good, "All components of an anchor for a cuboid/prismoid must be -1, 0, or 1")
        let(
            size=geom[1], size2=geom[2],
            shift=point2d(geom[3]), axis=point3d(geom[4]),
            anch = rot(from=axis, to=UP, p=anchor),
            h = size.z,
            u = (anch.z+1)/2,  // u is one of 0, 0.5, or 1
            axy = point2d(anch),
            bot = point3d(v_mul(point2d(size)/2,axy),-h/2),
            top = point3d(v_mul(point2d(size2)/2,axy)+shift,h/2),
            pos = point3d(cp) + lerp(bot,top,u) + offset,
            vecs = [
                if (anchor.x!=0) unit(rot(from=UP, to=unit([(top-bot).x,0,h]), p=[axy.x,0,0]), UP),
                if (anchor.y!=0) unit(rot(from=UP, to=unit([0,(top-bot).y,h]), p=[0,axy.y,0]), UP),
                if (anchor.z!=0) anch==CENTER? UP : unit([0,0,anch.z],UP)
            ],
            vec = unit(sum(vecs) / len(vecs)),
            pos2 = rot(from=UP, to=axis, p=pos),
            vec2 = rot(from=UP, to=axis, p=vec)
        ) [anchor, pos2, vec2, oang]
    ) : type == "cyl"? ( //r1, r2, l, shift
        assert(anchor.z == sign(anchor.z), "The Z component of an anchor for a cylinder/cone must be -1, 0, or 1")
        let(
            rr1=geom[1], rr2=geom[2], l=geom[3],
            shift=point2d(geom[4]), axis=point3d(geom[5]),
            r1 = is_num(rr1)? [rr1,rr1] : point2d(rr1),
            r2 = is_num(rr2)? [rr2,rr2] : point2d(rr2),
            anch = rot(from=axis, to=UP, p=anchor),
            u = (anch.z+1)/2,
            axy = unit(point2d(anch),[0,0]),
            bot = point3d(v_mul(r1,axy), -l/2),
            top = point3d(v_mul(r2,axy)+shift, l/2),
            pos = point3d(cp) + lerp(bot,top,u) + offset,
            sidevec = rot(from=UP, to=top-bot, p=point3d(axy)),
            vvec = anch==CENTER? UP : unit([0,0,anch.z],UP),
            vec = anch==CENTER? UP :
                approx(axy,[0,0])? unit(anch,UP) :
                approx(anch.z,0)? sidevec :
                unit((sidevec+vvec)/2,UP),
            pos2 = rot(from=UP, to=axis, p=pos),
            vec2 = rot(from=UP, to=axis, p=vec)
        ) [anchor, pos2, vec2, oang]
    ) : type == "spheroid"? ( //r
        let(
            rr = geom[1],
            r = is_num(rr)? [rr,rr,rr] : point3d(rr),
            anchor = unit(point3d(anchor),CENTER),
            pos = point3d(cp) + v_mul(r,anchor) + point3d(offset),
            vec = unit(v_mul(r,anchor),UP)
        ) [anchor, pos, vec, oang]
    ) : type == "vnf_isect"? ( //vnf
        let(
            vnf=geom[1]
        ) vnf==EMPTY_VNF? [anchor, [0,0,0], unit(anchor), 0] :
        let(
            eps = 1/2048,
            points = vnf[0],
            faces = vnf[1],
            rpts = apply(rot(from=anchor, to=RIGHT) * move(-cp), points),
            hits = [
                for (face = faces)
                    let(
                        verts = select(rpts, face),
                        ys = column(verts,1),
                        zs = column(verts,2)
                    )
                    if (max(ys) >= -eps && max(zs) >= -eps &&
                        min(ys) <=  eps &&  min(zs) <=  eps)
                        let(
                            poly = select(points, face),
                            isect = polygon_line_intersection(poly, [cp,cp+anchor], eps=eps),
                            ptlist = is_undef(isect) ? [] :
                                     is_vector(isect) ? [isect]
                                                      : flatten(isect),   // parallel to a face
                            n = len(ptlist)>0 ? polygon_normal(poly) : undef
                        )
                        for(pt=ptlist) [anchor * (pt-cp), n, pt]
            ]
        )
        assert(len(hits)>0, "Anchor vector does not intersect with the shape.  Attachment failed.")
        let(
            furthest = max_index(column(hits,0)),
            dist = hits[furthest][0],
            pos = hits[furthest][2],
            hitnorms = [for (hit = hits) if (approx(hit[0],dist,eps=eps)) hit[1]],
            unorms = [
                      for (i = idx(hitnorms))
                          let(
                              thisnorm = hitnorms[i],
                              isdup = [
                                       for (j = [i+1:1:len(hitnorms)-1])
                                           if (approx(thisnorm, hitnorms[j])) 1
                                      ] != []
                          )
                          if (!isdup) thisnorm
                     ],
            n = unit(sum(unorms)),
            oang = approx(point2d(n), [0,0])? 0 : atan2(n.y, n.x) + 90
        )
        [anchor, pos, n, oang]
    ) : type == "vnf_extent"? ( //vnf
        let(
            vnf=geom[1]
        ) vnf==EMPTY_VNF? [anchor, [0,0,0], unit(anchor), 0] :
        let(
            rpts = apply(rot(from=anchor, to=RIGHT) * move(point3d(-cp)), vnf[0]),
            maxx = max(column(rpts,0)),
            idxs = [for (i = idx(rpts)) if (approx(rpts[i].x, maxx)) i],
            avep = sum(select(rpts,idxs))/len(idxs),
            mpt = approx(point2d(anchor),[0,0])? [maxx,0,0] : avep,
            pos = point3d(cp) + rot(from=RIGHT, to=anchor, p=mpt)
        ) [anchor, pos, anchor, oang]
    ) : type == "rect"? ( //size, size2, shift
        assert(anchor.z==0, "The Z component of an anchor for a 2D shape must be 0.")
        let(all_comps_good = [for (c=anchor) if (c!=sign(c)) 1]==[])
        assert(all_comps_good, "All components of an anchor for a rectangle/trapezoid must be -1, 0, or 1")
        let(
            size=geom[1], size2=geom[2], shift=geom[3],
            u = (anchor.y+1)/2,  // 0<=u<=1
            frpt = [size.x/2*anchor.x, -size.y/2],
            bkpt = [size2/2*anchor.x+shift,  size.y/2],
            pos = point2d(cp) + lerp(frpt, bkpt, u) + point2d(offset),
            svec = point3d(line_normal(bkpt,frpt)*anchor.x),
            vec = anchor.y < 0? (
                    anchor.x == 0? FWD :
                    size.x == 0? unit(-[shift,size.y], FWD) :
                    unit((point3d(svec) + FWD) / 2, FWD)
                ) :
                anchor.y == 0? ( anchor.x == 0? BACK : svec ) :
                (  // anchor.y > 0
                    anchor.x == 0? BACK :
                    size2 == 0? unit([shift,size.y], BACK) :
                    unit((point3d(svec) + BACK) / 2, BACK)
                )
        ) [anchor, pos, vec, 0]
    ) : type == "circle"? ( //r
        assert(anchor.z==0, "The Z component of an anchor for a 2D shape must be 0.")
        let( 
            rr = geom[1],
            r = is_num(rr)? [rr,rr] : point2d(rr),
            pos = approx(anchor.x,0) ? [0,sign(anchor.y)*r.y]
                      : let(
                             m = anchor.y/anchor.x,
                             px = sign(anchor.x) * sqrt(1/(1/sqr(r.x) + m*m/sqr(r.y)))
                        )
                        [px,m*px],
            anchor = unit(point2d(anchor),[0,0]),
            vec = unit([r.y/r.x*pos.x, r.x/r.y*pos.y])
        ) [anchor, point2d(cp+offset)+pos, vec, 0]
    ) : type == "rgn_isect"? ( //region
        assert(anchor.z==0, "The Z component of an anchor for a 2D shape must be 0.")
        let(
            rgn_raw = move(-point2d(cp), p=geom[1]),
            rgn = is_region(rgn_raw)? rgn_raw : [rgn_raw],
            anchor = point2d(anchor),
            isects = [
                for (path=rgn, t=triplet(path,true)) let(
                    seg1 = [t[0],t[1]],
                    seg2 = [t[1],t[2]],
                    isect = line_intersection([[0,0],anchor], seg1,RAY,SEGMENT),
                    n = is_undef(isect)? [0,1] :
                        !approx(isect, t[1])? line_normal(seg1) :
                        unit((line_normal(seg1)+line_normal(seg2))/2,[0,1]),
                    n2 = vector_angle(anchor,n)>90? -n : n
                )
                if(!is_undef(isect) && !approx(isect,t[0])) [norm(isect), isect, n2]
            ]
        )
        assert(len(isects)>0, "Anchor vector does not intersect with the shape.  Attachment failed.")
        let(
            maxidx = max_index(column(isects,0)),
            isect = isects[maxidx],
            pos = point2d(cp) + isect[1],
            vec = unit(isect[2],[0,1])
        ) [anchor, pos, vec, 0]
    ) : type == "rgn_extent"? ( //region
        assert(anchor.z==0, "The Z component of an anchor for a 2D shape must be 0.")
        let(
            rgn = force_region(geom[1]),
            anchor = point2d(anchor),
            m = rot(from=anchor, to=RIGHT) * move(-[cp.x, cp.y, 0]),
            rpts = apply(m, flatten(rgn)),
            maxx = max(column(rpts,0)),
            idxs = [for (i = idx(rpts)) if (approx(rpts[i].x, maxx)) i],
            miny = min([for (i=idxs) rpts[i].y]),
            maxy = max([for (i=idxs) rpts[i].y]),
            midy = (miny+maxy)/2,
            pos = point2d(cp) + rot(from=RIGHT, to=anchor, p=[maxx,midy])
        ) [anchor, pos, anchor, 0]
    ) : type == "xrgn_isect"? ( //region
        assert(anchor.z==0, "The Z component of an anchor for a 2D shape must be 0.")
        let(
            rgn_raw = move(-point2d(cp), p=geom[1]),
            l = geom[2],
            rgn = is_region(rgn_raw)? rgn_raw : [rgn_raw],
            anchor = point3d(anchor),
            xyanch = point2d(anchor)
        ) approx(xyanch,[0,0])? [anchor, [0,0,anchor.z*l/2], unit(anchor,UP), 0] :
        let(
            isects = [
                for (path=rgn, t=triplet(path,true)) let(
                    seg1 = [t[0],t[1]],
                    seg2 = [t[1],t[2]],
                    isect = line_intersection([[0,0],xyanch], seg1, RAY, SEGMENT),
                    n = is_undef(isect)? [0,1] :
                        !approx(isect, t[1])? line_normal(seg1) :
                        unit((line_normal(seg1)+line_normal(seg2))/2,[0,1]),
                    n2 = vector_angle(xyanch,n)>90? -n : n
                )
                if(!is_undef(isect) && !approx(isect,t[0]))
                [norm(isect), isect, n2]
            ],
            maxidx = max_index(column(isects,0)),
            isect = isects[maxidx],
            pos = point3d(cp) + point3d(isect[1]) + unit([0,0,anchor.z],CENTER)*l/2,
            xyvec = unit(isect[2],[0,1]),
            vec = unit((point3d(xyvec)+UP*anchor.z)/2,UP),
            oang = approx(xyvec, [0,0])? 0 : atan2(xyvec.y, xyvec.x) + 90
        ) [anchor, pos, vec, oang]
    ) : type == "xrgn_extent"? ( //region
        assert(anchor.z==0, "The Z component of an anchor for a 2D shape must be 0.")
        let(
            rgn_raw = geom[1], l = geom[2],
            rgn = is_region(rgn_raw)? rgn_raw : [rgn_raw],
            anchor = point3d(anchor),
            xyanch = point2d(anchor),
            m = (
                approx(xyanch,[0,0])? [[1,0,0],[0,1,0],[0,0,1]] :
                rot(from=xyanch, to=RIGHT, planar=true)
            ) * move(-[cp.x, cp.y]),
            rpts = apply(m, flatten(rgn)),
            maxx = max(column(rpts,0)),
            idxs = [for (i = idx(rpts)) if (approx(rpts[i].x, maxx)) i],
            ys = [for (i=idxs) rpts[i].y],
            midy = (min(ys)+max(ys))/2,
            xypos = point2d(cp) + (
                approx(xyanch,[0,0])? [0,0] :
                rot(from=RIGHT, to=xyanch, p=[maxx,midy])
            ),
            pos = point3d(xypos) + unit([0,0,anchor.z],CENTER)*l/2,
            vec = unit((point3d(xyanch)+UP*anchor.z)/2,UP)
        ) [anchor, pos, vec, oang]
    ) :
    assert(false, "Unknown attachment geometry type.");


/// Internal Function: _attachment_is_shown()
// Usage:
//   bool = _attachment_is_shown(tags);
/// Topics: Attachments
/// See Also: reorient(), attachable()
// Description:
//   Returns true if shapes tagged with any of the given space-delimited string of tag names should currently be shown.
function _attachment_is_shown(tags) =
    assert(!is_undef($tags_shown))
    assert(!is_undef($tags_hidden))
    let(
        tags = str_split(tags, " "),
        shown  = !$tags_shown || any([for (tag=tags) in_list(tag, $tags_shown)]),
        hidden = any([for (tag=tags) in_list(tag, $tags_hidden)])
    ) shown && !hidden;


// Section: Visualizing Anchors

/// Internal Function: _standard_anchors()
/// Usage:
///   anchs = _standard_anchors([two_d]);
/// Description:
///   Return the vectors for all standard anchors.
/// Arguments:
///   two_d = If true, returns only the anchors where the Z component is 0.  Default: false
function _standard_anchors(two_d=false) = [
    for (
        zv = [
            if (!two_d) TOP,
            CENTER,
            if (!two_d) BOTTOM
        ],
        yv = [FRONT, CENTER, BACK],
        xv = [LEFT, CENTER, RIGHT]
    ) xv+yv+zv
];



// Module: show_anchors()
// Usage:
//   ... show_anchors([s], [std=], [custom=]);
// Description:
//   Show all standard anchors for the parent object.
// Arguments:
//   s = Length of anchor arrows.
//   ---
//   std = If true (default), show standard anchors.
//   custom = If true (default), show custom anchors.
// Example(FlatSpin,VPD=333):
//   cube(50, center=true) show_anchors();
module show_anchors(s=10, std=true, custom=true) {
    check = assert($parent_geom != undef) 1;
    two_d = _attach_geom_2d($parent_geom);
    if (std) {
        for (anchor=_standard_anchors(two_d=two_d)) {
            if(two_d) {
                attach(anchor) anchor_arrow2d(s);
            } else {
                attach(anchor) anchor_arrow(s);
            }
        }
    }
    if (custom) {
        for (anchor=last($parent_geom)) {
            attach(anchor[0]) {
                if(two_d) {
                    anchor_arrow2d(s, color="cyan");
                } else {
                    anchor_arrow(s, color="cyan");
                }
                color("black")
                noop($tags="anchor-arrow") {
                    xrot(two_d? 0 : 90) {
                        back(s/3) {
                            yrot_copies(n=2)
                            up(s/30) {
                                linear_extrude(height=0.01, convexity=12, center=true) {
                                    text(text=anchor[0], size=s/4, halign="center", valign="center");
                                }
                            }
                        }
                    }
                }
                color([1, 1, 1, 0.4])
                noop($tags="anchor-arrow") {
                    xrot(two_d? 0 : 90) {
                        back(s/3) {
                            zcopies(s/21) cube([s/4.5*len(anchor[0]), s/3, 0.01], center=true);
                        }
                    }
                }
            }
        }
    }
    children();
}



// Module: anchor_arrow()
// Usage:
//   anchor_arrow([s], [color], [flag]);
// Description:
//   Show an anchor orientation arrow.  By default, tagged with the name "anchor-arrow".
// Arguments:
//   s = Length of the arrows.  Default: `10`
//   color = Color of the arrow.  Default: `[0.333, 0.333, 1]`
//   flag = If true, draw the orientation flag on the arrowhead.  Default: true
// Example:
//   anchor_arrow(s=20);
module anchor_arrow(s=10, color=[0.333,0.333,1], flag=true, $tags="anchor-arrow") {
    $fn=12;
    recolor("gray") spheroid(d=s/6) {
        attach(CENTER,BOT) recolor(color) cyl(h=s*2/3, d=s/15) {
            attach(TOP,BOT) cyl(h=s/3, d1=s/5, d2=0) {
                if(flag) {
                    position(BOT)
                        recolor([1,0.5,0.5])
                            cuboid([s/100, s/6, s/4], anchor=FRONT+BOT);
                }
                children();
            }
        }
    }
}



// Module: anchor_arrow2d()
// Usage:
//   anchor_arrow2d([s], [color], [flag]);
// Description:
//   Show an anchor orientation arrow.
// Arguments:
//   s = Length of the arrows.
//   color = Color of the arrow.
// Example:
//   anchor_arrow2d(s=20);
module anchor_arrow2d(s=15, color=[0.333,0.333,1], $tags="anchor-arrow") {
    noop() color(color) stroke([[0,0],[0,s]], width=s/10, endcap1="butt", endcap2="arrow2");
}




// Module: expose_anchors()
// Usage:
//   expose_anchors(opacity) {child1() show_anchors(); child2() show_anchors(); ...}
// Description:
//   Used in combination with show_anchors() to display an object in transparent gray with its anchors in solid color.
//   Children will appear transparent and any anchor arrows drawn with will appear in solid color.  
// Arguments:
//   opacity = The opacity of the children.  0.0 is invisible, 1.0 is opaque.  Default: 0.2
// Example(FlatSpin,VPD=333):
//   expose_anchors() cube(50, center=true) show_anchors();
module expose_anchors(opacity=0.2) {
    show("anchor-arrow")
        children();
    hide("anchor-arrow")
        color(is_undef($color)? [0,0,0] :
              is_string($color)? $color :
                                 point3d($color), opacity)
            children();
}




// Module: frame_ref()
// Usage:
//   frame_ref(s, opacity);
// Description:
//   Displays X,Y,Z axis arrows in red, green, and blue respectively.
// Arguments:
//   s = Length of the arrows.
//   opacity = The opacity of the arrows.  0.0 is invisible, 1.0 is opaque.  Default: 1.0
// Examples:
//   frame_ref(25);
//   frame_ref(30, opacity=0.5);
module frame_ref(s=15, opacity=1) {
    cube(0.01, center=true) {
        attach([1,0,0]) anchor_arrow(s=s, flag=false, color=[1.0, 0.3, 0.3, opacity]);
        attach([0,1,0]) anchor_arrow(s=s, flag=false, color=[0.3, 1.0, 0.3, opacity]);
        attach([0,0,1]) anchor_arrow(s=s, flag=false, color=[0.3, 0.3, 1.0, opacity]);
        children();
    }
}



// vim: expandtab tabstop=4 shiftwidth=4 softtabstop=4 nowrap
