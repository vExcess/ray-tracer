const std = @import("std");

const zcanvas = @import("zcanvas");
const Canvas = zcanvas.Canvas;
const color = zcanvas.color;

const Window = zcanvas.Window;
const Key = Window.Key;
const WindowEvent = Window.Event;

const vexlib = @import("vexlib");
const Math = vexlib.Math;
const As = vexlib.As;
const Time = vexlib.Time;
const Array = vexlib.ArrayList;
const Uint8Array = vexlib.Uint8Array;
const Uint32Array = vexlib.Uint32Array;
const print = vexlib.print;
const println = vexlib.println;

var running = true;

pub fn eventHandler(event: WindowEvent) void {
    switch (event.which) {
        .Quit => {
            running = false;
        },
        .KeyDown => {
            if (event.data == Key.Escape) {
                running = false;
            }
        },
        .Unknown => {

        }
    }
}

pub fn main() !void {
    // setup allocator
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);

    // init SDL
    try Window.initSDL(Window.INIT_EVERYTHING);

    // create a window
    var myWin = try Window.SDLWindow.alloc(.{
        .title = "Raytracer",
        .width = 400,
        .height = 400,
        .flags = Window.WINDOW_SHOWN | Window.WINDOW_ALLOW_HIGHDPI
    });
    myWin.eventHandler = eventHandler; // attach event handler

    // print dimensions
    println("Port of https://www.khanacademy.org/computer-programming/new-program/5036061020831744 to Zig");

    // create canvas & rendering context
    var canvas = Canvas.alloc(allocator, myWin.width, myWin.height, 1.5, zcanvas.RendererType.Software);
    defer canvas.dealloc();
    const ctx = try canvas.getContext("2d", .{});

    // attach canvas to window
    myWin.setCanvas(&canvas);

    const focalLength: f32 = 6;
    const aperture: f32 = 0.4;
    const camxrot: f32 = 0.3;
    const camyrot: f32 = 0;

    const _sqrt = Math.sqrt;
    // const _max = Math.max;
    // const _min = Math.min;
    const _lerp = Math.lerp;
    // var _noise = this.noise;
    const _random = Math.random;
    const _width = myWin.width;
    const _height = myWin.height;
    const _cos = Math.cos;
    const _sin = Math.sin;
    const _pow = Math.pow;
    
    const scamx = _sin(camxrot);
    const scamy = _sin(camyrot);
    const ccamx = _cos(camxrot);
    const ccamy = _cos(camyrot);
    
    var scene = Array([4]f32).alloc(3);
    scene.append([_]f32{3, 0, 1, 1});
    scene.append([_]f32{0, 0, 5, 1});
    scene.append([_]f32{-1, -100001, 10, 100000});

    var materials = Array([6]f32).alloc(3);
    materials.append([_]f32{1, 0.9, 0.5, 10, 0, 0});
    materials.append([_]f32{1, 0, 0, 0.5, 1, 0.08});
    materials.append([_]f32{1, 1, 1, 0.5, 1, 0.5});
    
    {var i: u32 = 0; while (i < 20) : (i += 1) {
        scene.append([_]f32{_random(f32, -10, 10), _random(f32, 0, 3), _random(f32, 0, 20), _random(f32, 0.25, 2)});
        if(Math.floor(_random(f32, 0, 5)) == 0){
            materials.append([_]f32{_random(f32, 0, 1), _random(f32, 0, 1), _random(f32, 0, 1), 5, _random(f32, 0, 1), _random(f32, 0, 1)});
        }else{
            materials.append([_]f32{_random(f32, 0, 1), _random(f32, 0, 1), _random(f32, 0, 1), 0.5, _random(f32, 0, 1), _random(f32, 0, 1)});
        }
    }}
    
    var colorBuffer = Array(f32).alloc(_width*_height << 2);
    colorBuffer.len = colorBuffer.capacity();
    colorBuffer.fill(0, -1);
    
    var id = ctx._softItems.imgData.data;
    
    var its: u32 = 1;

    var frameCounter: u32 = 0;
    var displayFrameCount: u32 = 0;
    var lastFrameStamp = Time.millis();

    while (running) {
        // check for events
        myWin.pollInput();

        its += 1;

        {var i: u32 = 0; while (i < _width) : (i += 1) {
            var j: u32 = 0; while (j < _height) : (j += 1) {
                const ci = (i + j * _height) << 2;
                const u = (As.f32(i) + _random(f32, -0.5, 0.5) - 0.5 * As.f32(_width)) / As.f32(_height);
                const v = (As.f32(j) + _random(f32, -0.5, 0.5) - 0.5 * As.f32(_height)) / As.f32(_height);
                
                var cr: f32 = 1;
                var cg: f32 = 1;
                var cb: f32 = 1;
                
                const ox = 0;
                const oy = 3;
                const oz = 0;
                
                var dx = u * ccamy + 0.5 * scamy;
                var dy = -v * ccamx - 0.5 * scamx;
                var dz = 0.5 * ccamx - v * scamx - v * scamy;
                const nd = 1 / _sqrt(dx * dx + dy * dy + dz * dz);
                dx *= nd;
                dy *= nd;
                dz *= nd;
                
                var osx: f32 = undefined;
                var osy: f32 = undefined;
                const osz = 0;
                while (true) {
                    osx = _random(f32, -1, 1);
                    osy = _random(f32, -1, 1);
                    if (_sqrt(osx * osx + osy * osy) <= 1) {
                        break;
                    }
                }
                
                const uosx = osx;
                const uosy = osy * ccamx + osz * scamx;
                const uosz = -scamx * osy + ccamx * osz;
                
                var sox = ox + uosx * aperture;
                var soy = oy + uosy * aperture;
                var soz = oz + uosz * aperture;
                
                const fpx = ox + dx * focalLength;
                const fpy = oy + dy * focalLength;
                const fpz = oz + dz * focalLength;
                
                var sdx = fpx - sox;
                var sdy = fpy - soy;
                var sdz = fpz - soz;
                
                const nsd = 1 / _sqrt(sdx * sdx + sdy * sdy + sdz * sdz);
                sdx *= nsd;
                sdy *= nsd;
                sdz *= nsd;
                
                var l: u32 = 0; while (l < 12) : (l += 1) {
                    var h = false;
                    var t: f32 = 1000000;
                    var nx: f32 = undefined;
                    var ny: f32 = undefined;
                    var nz: f32 = undefined;
                    var mat: [6]f32 = undefined;
                    var k: u32 = 0; while (k < scene.len) : (k += 1) {
                        const px = scene.get(k)[0];
                        const py = scene.get(k)[1];
                        const pz = scene.get(k)[2];
                        const ocx = sox - px;
                        const ocy = soy - py;
                        const ocz = soz - pz;
                        const rad = scene.get(k)[3];
                        const a = sdx * sdx + sdy * sdy + sdz * sdz;
                        const b = 2 * (sdx * ocx + sdy * ocy + sdz * ocz);
                        const c = (ocx * ocx + ocy * ocy + ocz * ocz) - rad * rad;
                        const d = b * b - 4 * a * c;
                        
                        const currT = if (d > 0) (-b - _sqrt(d)) / (2 * a) else 1000000.0;
                        if (currT >= 0 and currT < t) {
                            t = currT;
                            h = true;
                            
                            nx = (sox + sdx * t - px) / rad;
                            ny = (soy + sdy * t - py) / rad;
                            nz = (soz + sdz * t - pz) / rad;
                            
                            mat = materials.get(k);
                        }
                    }
                    
                    if (h) {
                        sox = sox + sdx * t;
                        soy = soy + sdy * t;
                        soz = soz + sdz * t;
                        
                        var ddx: f32 = undefined;
                        var ddy: f32 = undefined;
                        var ddz: f32 = undefined;
                        
                        while (true) {
                            ddx = _random(f32, -1, 1);
                            ddy = _random(f32, -1, 1);
                            ddz = _random(f32, -1, 1);
                            
                            if (_sqrt(ddx * ddx + ddy * ddy + ddz * ddz) <= 1) {
                                break;
                            }
                        }
                        
                        var ndd = 1 / _sqrt(ddx * ddx + ddy * ddy + ddz * ddz);
                        ddx *= ndd;
                        ddy *= ndd;
                        ddz *= ndd;
                        
                        ddx += nx;
                        ddy += ny;
                        ddz += nz;
                        
                        ndd = 1 / _sqrt(ddx * ddx + ddy * ddy + ddz * ddz);
                        ddx *= ndd;
                        ddy *= ndd;
                        ddz *= ndd;
                        
                        const dn = nx * sdx + ny * sdy + nz * sdz;
                        
                        var rdx = dx - 2 * nx * dn;
                        var rdy = dy - 2 * ny * dn;
                        var rdz = dz - 2 * nz * dn;
                        
                        const nrd = 1 / _sqrt(rdx * rdx + rdy * rdy + rdz * rdz);
                        rdx *= nrd;
                        rdy *= nrd;
                        rdz *= nrd;
                        
                        const spec = As.f32(@intFromBool(_random(f32, 0, 1) < mat[5]));
                        
                        sdx = _lerp(ddx, rdx, mat[4] * spec);
                        sdy = _lerp(ddy, rdy, mat[4] * spec);
                        sdz = _lerp(ddz, rdz, mat[4] * spec);
                        
                        cr *= _lerp(mat[0] * mat[3], 1, spec);
                        cg *= _lerp(mat[1] * mat[3], 1, spec);
                        cb *= _lerp(mat[2] * mat[3], 1, spec);
                        
                        if (mat[3] > 1) {
                            break;
                        }
                    } else {
                        cr *= 0;
                        cg *= 0;
                        cb *= 0;
                        
                        break;
                    }
                }
                
                colorBuffer.set(ci, _lerp(colorBuffer.get(ci), cr, 1.0 / As.f32(its)));
                colorBuffer.set(ci + 1, _lerp(colorBuffer.get(ci + 1), cg, 1.0 / As.f32(its)));
                colorBuffer.set(ci + 2, _lerp(colorBuffer.get(ci + 2), cb, 1.0 / As.f32(its)));
                
                id.set(ci,     As.u8(Math.constrain(_pow(colorBuffer.get(ci    ), 1.0 / 2.2) * 255, 0, 255)));
                id.set(ci + 1, As.u8(Math.constrain(_pow(colorBuffer.get(ci + 1), 1.0 / 2.2) * 255, 0, 255)));
                id.set(ci + 2, As.u8(Math.constrain(_pow(colorBuffer.get(ci + 2), 1.0 / 2.2) * 255, 0, 255)));
                id.set(ci + 3, 255);
            }
        }}

        if (Time.millis() - lastFrameStamp > 1000) {
            displayFrameCount = frameCounter;
            frameCounter = 0;
            lastFrameStamp = Time.millis();
        }
        frameCounter += 1;

        print("FPS: ");
        println(displayFrameCount);


        // render frame
        try myWin.render();

        // wait for 16ms
        // Window.wait(1);        
    }

    // clean up
    myWin.dealloc();
    
}