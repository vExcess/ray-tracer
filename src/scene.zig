const vexlib = @import("vexlib");
const ArrayList = vexlib.ArrayList;

const Vec3 = @Vector(3, f32);
fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{x, y, z};
}

// const Shapes = enum {
//     triangle,
//     plane,
//     box,
//     sphere,
//     torus,
//     triangleMesh
// };

pub const Sphere = struct {
    clr: Vec3,
    emissive: bool,
    roughness: f32,
    x: f32,
    y: f32,
    z: f32,
    d: f32
};

pub const Box = struct {
    clr: Vec3,
    emissive: bool,
    roughness: f32,
    x: f32,
    y: f32,
    z: f32,
    w: f32,
    h: f32,
    l: f32
};

pub const Triangle = struct {
    clr: Vec3,
    emissive: bool,
    roughness: f32,
    v1: Vec3,
    v2: Vec3,
    v3: Vec3,
};

pub const Plane = struct {
    clr: Vec3,
    emissive: bool,
    roughness: f32,
    x: f32,
    y: f32,
    z: f32,
    normal: Vec3,
};

pub const Object = union(enum) {
    sphere: Sphere,
    box: Box,
    triangle: Triangle,
    plane: Plane
};

pub fn sphere(x: f32, y: f32, z: f32, diameter: f32, clr: Vec3, roughness: f32) Object {
    return Object{
        .sphere = Sphere{
            .clr = clr,
            .emissive = false,
            .roughness = roughness,
            .x = x,
            .y = y,
            .z = z,
            .d = diameter
        }
    };
}

pub fn box(x: f32, y: f32, z: f32, w: f32, h: f32, l: f32, clr: Vec3, roughness: f32) Object {
    return Object{
        .box = Box{
            .clr = clr,
            .emissive = false,
            .roughness = roughness,
            .x = x,
            .y = y,
            .z = z,
            .w = w,
            .h = h,
            .l = l,
        }
    };
}

pub fn triangle(x1: f32, y1: f32, z1: f32, x2: f32, y2: f32, z2: f32, x3: f32, y3: f32, z3: f32, clr: Vec3, roughness: f32) Object {
    return Object{
        .triangle = Triangle{
            .clr = clr,
            .emissive = false,
            .roughness = roughness,
            .v1 = vec3(x1, y1, z1),
            .v2 = vec3(x2, y2, z2),
            .v3 = vec3(x3, y3, z3),
        }
    };
}

pub fn plane(x: f32, y: f32, z: f32, normalX: f32, normalY: f32, normalZ: f32, clr: Vec3, roughness: f32) Object {
    return Object{
        .plane = Plane{
            .clr = clr,
            .emissive = false,
            .roughness = roughness,
            .x = x,
            .y = y,
            .z = z,
            .normal = vec3(normalX, normalY, normalZ)
        }
    };
}

pub const Scene = struct {
    objects: ArrayList(Object),
    lights: ArrayList(*Object),

    pub fn alloc() Scene {
        return Scene{
            .objects = ArrayList(Object).alloc(8),
            .lights = ArrayList(*Object).alloc(8)
        };
    }

    pub fn dealloc(self: *Scene) void {
        self.objects.dealloc();
        self.lights.dealloc();
    }

    pub fn add(self: *Scene, obj: Object) void {
        self.objects.append(obj);
    }

    pub fn addLight(self: *Scene, obj: Object) void {
        self.objects.append(obj);
        const objIdx = self.objects.len - 1;
        const objPtr: *Object = self.objects.getPtr(objIdx);
        switch (objPtr.*) {
            .sphere => |*mySphere| {
                mySphere.emissive = true;
            },
            .box => |*myBox| {
                myBox.emissive = true;
            },
            .triangle => |*myTriangle| {
                myTriangle.emissive = true;
            },
            .plane => |*myPlane| {
                myPlane.emissive = true;
            }
        }
    }

    pub fn updateLightsArray(self: *Scene) void {
        self.lights.len = 0;
        {var i: u32 = 0; while (i < self.objects.len) : (i += 1) {
            const obj = self.objects.getPtr(i);
            const isEmmisive = switch (obj.*) { inline else => |o| o.emissive };
            if (isEmmisive) {
                self.lights.append(obj);
            }
        }}
    }
};
