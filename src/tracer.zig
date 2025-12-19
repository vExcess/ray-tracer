const vexlib = @import("vexlib");
const Math = vexlib.Math;
const Array = vexlib.ArrayList;

// const Vector = @import("./lib/vec.zig");
const Vec3 = @Vector(3, f32);

fn v3Splat(val: anytype) Vec3 {
    return @as(Vec3, @splat(val));
}

fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{x, y, z};
}

fn color(x: f32, y: f32, z: f32) Vec3 {
    return .{x, y, z};
}

const EPSILON = 0.000003;

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

pub const Ray = struct {
    // the ray's x, y, z positions
    pos: Vec3,
    dir: Vec3,

    // stores whether the ray has hit something
    hit: bool,

    isShadow: bool,

    // stores the color the ray hit
    clr: Vec3,

    fn createShadowRay(self: *Ray, newVel: *const Vec3) Ray {
        return Ray{
            .pos = self.pos + (newVel.*) * v3Splat(EPSILON),
            .dir = newVel.*,
            .hit = false,
            .isShadow = true,
            .clr = self.clr
        };
    }
};

fn getPointOnRay(ray: *Ray, d: f32) Vec3 {
    return ray.pos + ray.dir * v3Splat(d);
}


fn getNormalVector(intersection: *const Vec3, ray: *Ray, obj: *const Object) Vec3 {
    var normalVector: Vec3 = undefined;
    
    switch (obj.*) {
        .sphere => |*mySphere| {
            normalVector = vec3(
                intersection[0] - mySphere.x, 
                intersection[1] - mySphere.y, 
                intersection[2] - mySphere.z
            );
            normalVector = Math.normalize(normalVector);
        },
        .box => |*myBox| {
            normalVector = vec3(0, 0, 0);
            if (intersection[0] < myBox.x - myBox.w / 2.0 + EPSILON) {
                normalVector[0] = -1.0;
            } else if (intersection[0] > myBox.x + myBox.w / 2.0 - EPSILON) {
                normalVector[0] = 1.0;
            }
            
            if (intersection[1] < myBox.y - myBox.h / 2.0 + EPSILON) {
                normalVector[1] = -1.0;
            } else if (intersection[1] > myBox.y + myBox.h / 2.0 - EPSILON) {
                normalVector[1] = 1.0;
            }

            if (intersection[2] < myBox.z - myBox.l / 2.0 + EPSILON) {
                normalVector[2] = -1.0;
            } else if (intersection[2] > myBox.z + myBox.l / 2.0 - EPSILON) {
                normalVector[2] = 1.0;
            }
        },
        .triangle => |*myTriangle| {
            const A = myTriangle.v2 - myTriangle.v1;
            const B = myTriangle.v3 - myTriangle.v1;
            normalVector = Math.normalize(-vec3(
                A[1] * B[2] - A[2] * B[1], 
                A[2] * B[0] - A[0] * B[2], 
                A[0] * B[1] - A[1] * B[0]
            ));
            if (Math.dot(ray.pos, normalVector) < 0.0) {
                // normalVector = -normalVector;
            }
        },
        .plane => |*myPlane| {
            normalVector = myPlane.normal;
        }
    }
    
    return normalVector;
}

fn sphereSDF(ray: *Ray, mySphere: *const Sphere) ?f32 {
    const l = vec3(
        ray.pos[0] - mySphere.x,
        ray.pos[1] - mySphere.y,
        ray.pos[2] - mySphere.z
    );
    const a = Math.dot(ray.dir, ray.dir);
    const b = 2.0 * Math.dot(ray.dir, l);
    const c = Math.dot(l, l) - (mySphere.d * mySphere.d);
    const discr = b * b - 4.0 * a * c;
    if (discr < 0.0 or b > 0.0) {
        return null;
    } else {
        return (-b - Math.sqrt(discr)) / (2.0 * a);
    }
}

fn boxSDF(ray: *Ray, myBox: *const Box) ?f32 {
    const halfW = myBox.w / 2.0;
    const halfH = myBox.h / 2.0;
    const halfL = myBox.l / 2.0;

    const bx_min_x = myBox.x - halfW;
    const bx_min_y = myBox.y - halfH;
    const bx_min_z = myBox.z - halfL;
    const bx_max_x = myBox.x + halfW;
    const bx_max_y = myBox.y + halfH;
    const bx_max_z = myBox.z + halfL;
    
    const rayNorm = v3Splat(1.0) / ray.dir;

    const tx1 = (bx_min_x - ray.pos[0]) * rayNorm[0];
    const tx2 = (bx_max_x - ray.pos[0]) * rayNorm[0];
    
    var tmin = Math.min(tx1, tx2);
    var tmax = Math.max(tx1, tx2);
    
    const ty1 = (bx_min_y - ray.pos[1]) * rayNorm[1];
    const ty2 = (bx_max_y - ray.pos[1]) * rayNorm[1];
    
    tmin = Math.max(tmin, Math.min(ty1, ty2));
    tmax = Math.min(tmax, Math.max(ty1, ty2));
    
    const tz1 = (bx_min_z - ray.pos[2]) * rayNorm[2];
    const tz2 = (bx_max_z - ray.pos[2]) * rayNorm[2];
    
    tmin = Math.max(tmin, Math.min(tz1, tz2));
    tmax = Math.min(tmax, Math.max(tz1, tz2));
    
    if (tmax < tmin) {
        return null;
    } else {
        const d = if (tmin < 0) tmax else tmin;
        return if (d < 0) null else d;
    }
}

fn triangleSDF(ray: *Ray, myTriangle: *const Triangle) ?f32 {
    const rayVector = ray.dir;
    const vertex1 = myTriangle.v1;
    const edge1 = myTriangle.v2 - vertex1;
    const edge2 = myTriangle.v3 - vertex1;
    const h = Math.cross(rayVector, edge2);
    const a = Math.dot(edge1, h);
    if (a > -EPSILON and a < EPSILON) {
        return null; // This ray is parallel to this triangle.
    }
    const f = 1.0 / a;
    const s = ray.pos - vertex1;
    const u = f * (Math.dot(s, h));
    if (u < 0.0 or u > 1.0) {
        return null;
    }
    const q = Math.cross(s, edge1);
    const v = f * Math.dot(rayVector, q);
    if (v < 0.0 or u + v > 1.0) {
        return null;
    }
    // At this stage we can compute t to find out where the intersection point is on the line.
    const t = f * Math.dot(edge2, q);
    if (t > EPSILON) {
        return t; // ray intersection
    } else {
        return null; // This means that there is a line intersection but not a ray intersection
    }
}

fn planeSDF(ray: *Ray, myPlane: *const Plane) ?f32 {
    // Plane collisions, but it messes up shadows
    // var denom = vec3.Math.dot(plane.normal, vec3.vector(ray.dir[0], ray.dir[1], ray.dir[2]));
    // if (denom < -EPSILON) {
    //     var v = vec3.sub(vec3.vector(plane.x, plane.y, plane.z), vec3.vector(0, 0, 0));
    //     var t = vec3.Math.dot(v, plane.normal) / denom;
    //     if (t >= 0) {
    //         return t;
    //     }
    // }
    // return false;

    // use box collisions for planes instead
    var planeBox = Box{
        .clr = undefined,
        .emissive = undefined,
        .roughness = undefined,
        .x = myPlane.x,
        .y = myPlane.y,
        .z = myPlane.z,
        .w = 1000,
        .h = 1000,
        .l = 1000
    };
    
    if (myPlane.normal[2] != 0) {
        planeBox.l = EPSILON;
    }
    if (myPlane.normal[1] != 0) {
        planeBox.h = EPSILON;
    }
    if (myPlane.normal[0] != 0) {
        planeBox.w = EPSILON;
    }
    
    return boxSDF(ray, &planeBox);
}

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

fn diffuseRay(normalVector: Vec3) Vec3 {
    var ptOnSphere: Vec3 = .{
        Math.randomGaussian(f32),
        Math.randomGaussian(f32),
        Math.randomGaussian(f32)
    };
    ptOnSphere = Math.normalize(ptOnSphere);
    const dot = Math.dot(ptOnSphere, normalVector);
    if (dot < 0) {
        return -ptOnSphere;
    }
    return ptOnSphere;
}

fn reflectRay(dir: Vec3, normalVector: Vec3) Vec3 {
    return dir - normalVector * v3Splat(Math.dot(dir, normalVector)) * v3Splat(2.0);
}

fn cosDiffuseRay(ray: *Ray, normalVector: Vec3, diffuseAmt: f32) void {
    if (diffuseAmt > 0.0) {
        const r0 = Math.random(f32, 0, 1);
        const r1 = Math.random(f32, 0, 1);
        const r = Math.sqrt(r0);
        const theta = 2.0 * @as(f32, @floatCast(Math.PI)) * r1;
        const ptOnSphere = vec3(
            r * Math.cos(theta),
            Math.sqrt(Math.max(0.0, 1.0 - r0)),
            r * Math.sin(theta)
        );
        ray.dir = Math.normalize(ptOnSphere + normalVector);
    }
}

pub fn rayTrace(scene_: *Array(Object), lights: Array(*Object), ray: *Ray, bounces: u32) struct{ closestObject: ?*Object, shapeClr: Vec3, availLight: Vec3 } {
    var scene = scene_;

    // find the closest object the ray hits
    var closestHitDist = Math.Infinity(f32);
    var closestObject: ?*Object = null;
    {var i = @as(i32, @intCast(scene.len)) - 1; while (i >= 0) : (i -= 1) {
        const object = scene.getPtr(@as(u32, @intCast(i)));
        var signedDist: ?f32 = null;

        switch (object.*) {
            .sphere => |*mySphere| {
                signedDist = sphereSDF(ray, mySphere);
            },
            .box => |*myBox| {
                signedDist = boxSDF(ray, myBox);
            },
            .triangle => |*myTriangle| {
                signedDist = triangleSDF(ray, myTriangle);
            },
            .plane => |*myPlane| {
                signedDist = planeSDF(ray, myPlane);
            }
        }

        if (signedDist) |dist| {
            if (dist < closestHitDist) {
                ray.hit = true;
                closestHitDist = dist;
                closestObject = object;
            }
        }
    }}

    // calculate color for rays that hit object
    if (ray.hit) {
        const closestObj = closestObject.?;
        var shapeClr = switch (closestObj.*) { inline else => |o| o.clr };
        var availLight = color(0, 0, 0);

        // don't need to calculate colors for a shadow ray
        if (!ray.isShadow) {
            const intersection = getPointOnRay(ray, closestHitDist - EPSILON);
            ray.pos = intersection;

            // calculate the normal vector
            const normalVector = getNormalVector(&intersection, ray, closestObj);        

            // calculate color for shapes
            const isEmissive = switch (closestObj.*) { inline else => |o| o.emissive };
            if (isEmissive) {
                shapeClr = shapeClr;
                availLight = shapeClr;
            } else {
                // do checkered pattern
                if (switch (closestObj.*) { .triangle => 0, inline else => |o| o.y } == -4) {
                    const temp: f32 = @mod(Math.floor(ray.pos[0]/1.0) + @mod(Math.floor(ray.pos[2]/1.0), 2.0), 2.0);
                    shapeClr[0] = temp;
                    shapeClr[1] = temp;
                    shapeClr[2] = temp;
                }

                // calc lighting
                var numLights: f32 = 0;
                {var i: u32 = 0; while (i < lights.len) : (i += 1) {
                    const light = lights.get(i);
                    switch (light.*) {
                        .triangle => {

                        },
                        inline else => |notTriangle| {
                            numLights += 1;
                            const lightVector = Math.normalize(vec3(
                                notTriangle.x - intersection[0], 
                                notTriangle.y - intersection[1],
                                notTriangle.z - intersection[2]
                            ));

                            // do shadows
                            if (bounces < 1) {
                                var shadowRay = ray.createShadowRay(&lightVector);
                                const shadowTrace = rayTrace(scene, lights, &shadowRay, bounces + 1);
                                const shadowClosestObject = shadowTrace.closestObject;

                                const lightStrength = Math.dot(lightVector, normalVector);
                                const lightClr = switch (light.*) { inline else => |o| o.clr };
                                if (shadowClosestObject == null or @intFromPtr(shadowClosestObject.?) == @intFromPtr(light)) {
                                    // there is not a shadow
                                    availLight += lightClr * v3Splat(lightStrength);
                                }
                            }
                        }
                    }
                }}

                // do reflections
                // roughness of 0.0 is mirror, roughness of 1.0 is flat
                const roughness = switch (closestObj.*) { inline else => |o| o.roughness };
                if (bounces < 1) {
                    var allocator = vexlib.allocatorPtr.*;
                    const numSamples = 1 + roughness * 25;
                    const sampleRays = allocator.alloc(Ray, @as(u32, @intFromFloat(numSamples))) catch unreachable;
                    defer allocator.free(sampleRays);

                    // initialize sample rays
                    {var i: u32 = 0; while (i < sampleRays.len) : (i += 1) {
                        var sampleRay = Ray{
                            .pos = ray.pos,
                            .dir = undefined,
                            .hit = false,
                            .isShadow = false,
                            .clr = ray.clr
                        };
                        if (roughness == 0.0) {
                            sampleRay.dir = reflectRay(ray.dir, normalVector);
                        } else if (roughness == 1.0) {
                            sampleRay.dir = diffuseRay(normalVector);
                        } else {
                            const diffuseDir = diffuseRay(normalVector);
                            const specularDir = reflectRay(ray.dir, normalVector);
                            sampleRay.dir = Math.lerp(specularDir, diffuseDir, roughness);
                        }
                        sampleRays[i] = sampleRay;
                    }}

                    // trace samples
                    {var i: u32 = 0; while (i < sampleRays.len) : (i += 1) {
                        const sampleRay = &sampleRays[i];
                        const mirrorTrace = rayTrace(scene, lights, sampleRay, bounces + 1);
                        const traceClr = (mirrorTrace.shapeClr * mirrorTrace.availLight);
                        availLight += traceClr / v3Splat(numSamples);
                    }}
                    availLight /= v3Splat(2);
                }
            }
        }
        
        return .{
            .closestObject = closestObj,
            .shapeClr = shapeClr,
            .availLight = availLight
        };
    } else {
        // if the ray hits nothing return black
        return .{
            .closestObject = null,
            .shapeClr = color(0, 0, 0),
            .availLight = color(0, 0, 0)
        };
    }
}