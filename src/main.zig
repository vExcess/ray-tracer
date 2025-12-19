const std = @import("std");

const zcanvas = @import("zcanvas");
const Canvas = zcanvas.Canvas;
const color = zcanvas.color;

const Window = zcanvas.Window;
const Key = Window.Key;
const WindowEvent = Window.Event;

const vexlib = @import("vexlib");
const Math = vexlib.Math;
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

const Tracer = @import("./tracer.zig");

const Frame = struct {
    pixels: Uint8Array,
    pixelMappings: Uint32Array,
    width: u32,
    height: u32,
    f32Width: f32,
    f32Height: f32,
    scene: *Array(Tracer.Object),
    lights: Array(*Tracer.Object),
    currI: u32,
    done: bool,

    fn alloc(width: u32, height: u32, scene: *Array(Tracer.Object)) Frame {
        var pixels = Uint8Array.alloc(width * height * 4);
        pixels.fill(0, -1);
        pixels.len = pixels.capacity();

        const pixelCount = width * height;
        var randomMappings = Uint32Array.alloc(pixelCount);
        {var i: u32 = 0; while (i < pixelCount) : (i += 1) {
            randomMappings.append(i);
        }}
        
        {var i: u32 = 0; while (i < pixelCount) : (i += 1) {
            const j = @as(u32, @intFromFloat(Math.random(f32, 0.0, @as(f32, @floatFromInt(pixelCount)))));
            const temp = randomMappings.get(i);
            randomMappings.set(i, randomMappings.get(j));
            randomMappings.set(j, temp);
        }}

        var lights = Array(*Tracer.Object).alloc(1);
        {var i: u32 = 0; while (i < scene.len) : (i += 1) {
            const light = scene.getPtr(i);
            const isEmmisive = switch (light.*) { inline else => |o| o.emissive };
            if (isEmmisive) {
                lights.append(light);
            }
        }}

        return Frame{
            .pixels = pixels,
            .pixelMappings = randomMappings,
            .width = width,
            .height = height,
            .f32Width = @as(f32, @floatFromInt(width)),
            .f32Height = @as(f32, @floatFromInt(height)),
            .scene = scene,
            .lights = lights,
            .currI = 0,
            .done = false,
        };
    }

    fn renderPixel(self: *Frame, idx: u32) void {
        // const i = self.pixelMappings.get(idx) * 4;
        var i = idx * 4 * 2;
        const isSecondRun = i >= self.pixels.len;
        if (isSecondRun) {
            i = i - self.pixels.len + 4;
        }

        const shiftedI = @as(f32, @floatFromInt(i >> 2));

        const xPos: f32 = @mod(shiftedI, self.f32Width);
        const yPos = Math.floor(shiftedI / self.f32Width);

        // calculate the ray's x and y direction
        const heightRatio = self.f32Height / self.f32Width;
        const xVel = Math.map(xPos, 0.0, self.f32Width, -0.5, 0.5);
        const yVel = Math.map(yPos, 0.0, self.f32Height, 0.5 * heightRatio, -0.5 * heightRatio);

        // return the ray
        var myRay = Tracer.Ray{
            .pos = .{xVel, yVel, 1},
            .dir = .{xVel, yVel, 1},

            // stores whether the ray has hit something
            .hit = false,

            .isShadow = false,

            // stores the color the ray hit
            .clr = .{0, 0, 0}
        };

        const trace = Tracer.rayTrace(self.scene, self.lights, &myRay, 0);
        var clr = trace.shapeClr * trace.availLight;
        clr[0] = Math.constrain(clr[0] * 255, 0, 255);
        clr[1] = Math.constrain(clr[1] * 255, 0, 255);
        clr[2] = Math.constrain(clr[2] * 255, 0, 255);

        const gamma: f32 = 0.7;
        clr[0] = Math.pow(clr[0], gamma) / Math.pow(255.0, gamma) * 255.0;
        clr[1] = Math.pow(clr[1], gamma) / Math.pow(255.0, gamma) * 255.0;
        clr[2] = Math.pow(clr[2], gamma) / Math.pow(255.0, gamma) * 255.0;
        
        const r = @as(u8, @intFromFloat(clr[0]));
        const g = @as(u8, @intFromFloat(clr[1]));
        const b = @as(u8, @intFromFloat(clr[2]));
        self.pixels.set(i, r);
        self.pixels.set(i+1, g);
        self.pixels.set(i+2, b);
        if (!isSecondRun) {
            self.pixels.set(i+4, r);
            self.pixels.set(i+1+4, g);
            self.pixels.set(i+2+4, b);
        }
    }

    fn dealloc(self: *Frame) void {
        self.pixels.dealloc();
        self.pixelMappings.dealloc();
        self.lights.dealloc();
    }

    fn update(self: *Frame, amt: u32) void {
        const end = Math.min(self.currI + amt, self.pixelMappings.len - 1);
        while (self.currI < end) : (self.currI += 1) {
            self.renderPixel(self.currI);
        }
        self.done = self.currI == self.pixels.len / 4 - 1;
    }

    fn display(frame_: Frame, buff: []u8, width: u32) void {
        var frame = frame_;
        var i: u32 = 0; while (i < frame.pixels.len) : (i += 4) {
            const x = (i >> 2) % frame.width;
            const y = ((i >> 2) / frame.width);
            const scale = width / frame.width;
            {var xOff: u32 = 0; while (xOff < scale) : (xOff += 1) {
                {var yOff: u32 = 0; while (yOff < scale) : (yOff += 1) {
                    const mappedIdx = @as(usize, @intCast((x * scale + xOff) + (y * scale + yOff) * width)) << 2;
                    buff[mappedIdx] = frame.pixels.get(i);
                    buff[mappedIdx+1] = frame.pixels.get(i+1);
                    buff[mappedIdx+2] = frame.pixels.get(i+2);
                    buff[mappedIdx+3] = 255;
                }}
            }}
        }
    }
};

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
    println("Game running");

    // create canvas & rendering context
    var canvas = Canvas.alloc(allocator, myWin.width, myWin.height, 1.5, zcanvas.RendererType.Software);
    defer canvas.dealloc();
    const ctx = try canvas.getContext("2d", .{});


    // attach canvas to window
    myWin.setCanvas(&canvas);

    // setup scene
    var scene = Array(Tracer.Object).alloc(0);
    defer scene.dealloc();
    // light
    var light = Tracer.sphere(
        -3, 3, 9,
        0.1, 
        .{1.0, 0.0, 0.0}, 1.0
    );
    light.sphere.emissive = true;
    scene.append(light);

    var light2 = Tracer.sphere(
        3, 3, 9,
        0.1, 
        .{0.0, 0.0, 1.0}, 1.0
    );
    light2.sphere.emissive = true;
    scene.append(light2);

    var light3 = Tracer.box(
        0, 3.91, 10,
        2, 0.1, 2,
        .{0.0, 1.0, 0.0}, 1.0
    );
    light3.box.emissive = true;
    scene.append(light3);

    // walls
    scene.append(Tracer.plane(
        0, 4, 0,
        0, -1, 0, 
        .{0, 1, 0}, 1.0
    ));
    scene.append(Tracer.plane(
        0, 0, 17,
        0, 0, -1, 
        .{1, 1, 1}, 1.0
    ));
    
    // floor
    scene.append(Tracer.plane(
        0, -4, 0,
        0, 1, 0, 
        .{0.75, 0.5, 0}, 1.0
    ));

    // more walls
    scene.append(Tracer.plane(
        -4, 0, 0,
        1, 0, 0, 
        .{1.0, 0, 0}, 1.0
    ));
    scene.append(Tracer.plane(
        4, 0, 0,
        -1, 0, 0, 
        .{0, 0, 1.0}, 1.0
    ));

    // scene objects
    scene.append(Tracer.sphere(
        2.1, 0.0, 14.0,
        1.8, 
        .{1.0, 0, 0}, 1.0
    ));
    scene.append(Tracer.sphere(
        -1.0, 3.8, 13.0, 
        1.3, 
        .{0, 0, 1.0}, 1.0
    ));
    scene.append(Tracer.box(
        0, -3.0, 12.0, 
        1, 2, 1, 
        .{0, 1.0, 1.0}, 1.0
    ));
    scene.append(Tracer.triangle(
        -2.5, 2, 13,
        -4, -3.7, 14,
        1, -3.8, 16,
        .{1.0, 1.0, 1.0}, 1.0
    ));


    // initial frame
    var frame1 = Frame.alloc(myWin.width, myWin.height, &scene);
    defer frame1.dealloc();

    var frameCount: f32 = 0;
    while (running) {
        // check for events
        myWin.pollInput();

        // run raytrace
        if (!frame1.done) {
            frame1.update(100);
            Frame.display(frame1, ctx._softItems.imgData.data.buffer, myWin.width);

            // print(frame1.currI * 100 / frame1.pixelMappings.len);
            // println("%");

            if (frame1.done) {
                println("DONE");
            }
        }

        // render frame
        try myWin.render();

        // wait for 16ms
        Window.wait(16);

        frameCount += 1.0;
    }

    // clean up
    myWin.dealloc();
    
}