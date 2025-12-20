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

const libscene = @import("./scene.zig");
const Scene = libscene.Scene;
const Sphere = libscene.Sphere;
const Box = libscene.Box;
const Triangle = libscene.Triangle;
const Plane = libscene.Plane;
const Object = libscene.Object;

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

const TracerThread = @import("./TracerThread.zig").TracerThread;

pub const Frame = struct {
    pixels: Uint8Array,
    pixelMappings: Uint32Array,
    width: u32,
    height: u32,
    scene: *Scene,
    currI: u32,
    done: bool,

    fn alloc(width: u32, height: u32, scene: *Scene) Frame {
        var pixels = Uint8Array.alloc(width * height * 4);
        pixels.fill(0, -1);
        pixels.len = pixels.capacity();

        // randomMappings is a map of every pixel to one other random pixel index
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

        return Frame{
            .pixels = pixels,
            .pixelMappings = randomMappings,
            .width = width,
            .height = height,
            .scene = scene,
            .currI = 0,
            .done = false,
        };
    }

    fn dealloc(self: *Frame) void {
        self.pixels.dealloc();
        self.pixelMappings.dealloc();
    }

    fn renderBatch(self: *Frame, amt: u32) void {
        const end = Math.min(self.currI + amt, self.pixelMappings.len - 1);
        while (self.currI <= end) : (self.currI += 1) {
            const i: u32 = self.pixelMappings.get(self.currI) * 4;
            const clr = self.tracePixel(i);
            self.pixels.set(i, clr[0]);
            self.pixels.set(i+1, clr[1]);
            self.pixels.set(i+2, clr[2]);
        }
        self.done = self.currI > self.pixelMappings.len - 1;
    }

    fn copyToImageBuffer(self: *Frame, buff: []u8, width: u32) void {
        var i: u32 = 0; while (i < self.pixels.len) : (i += 4) {
            const x = (i >> 2) % self.width;
            const y = ((i >> 2) / self.width);
            const scale = width / self.width;
            {var xOff: u32 = 0; while (xOff < scale) : (xOff += 1) {
                {var yOff: u32 = 0; while (yOff < scale) : (yOff += 1) {
                    const mappedIdx = @as(usize, @intCast((x * scale + xOff) + (y * scale + yOff) * width)) << 2;
                    buff[mappedIdx] = self.pixels.get(i);
                    buff[mappedIdx+1] = self.pixels.get(i+1);
                    buff[mappedIdx+2] = self.pixels.get(i+2);
                    buff[mappedIdx+3] = 255;
                }}
            }}
        }
    }
};

fn buildScene() Scene {
    var scene = Scene.alloc();

    // light
    scene.addLight(libscene.sphere(
        -3, 3, 9,
        0.5, 
        .{1.0, 0.0, 0.0}, 1.0
    ));
    scene.addLight(libscene.sphere(
        3, 3, 9,
        0.5, 
        .{0.0, 0.0, 1.0}, 1.0
    ));
    scene.addLight(libscene.box(
        0, 3.91, 10,
        2, 0.1, 2,
        .{0.0, 1.0, 0.0}, 1.0
    ));

    // roof
    scene.add(libscene.plane(
        0, 4, 0,
        0, -1, 0, 
        .{1, 1, 1}, 0.99
    ));
    // back wall
    scene.add(libscene.plane(
        0, 0, 17,
        0, 0, -1, 
        .{1, 1, 1}, 0.99
    ));
    scene.add(libscene.plane(
        0, 0, 0,
        0, 0, 1, 
        .{1, 1, 1}, 0.99
    ));
    // floor
    scene.add(libscene.plane(
        0, -4, 0,
        0, 1, 0, 
        .{0.75, 0.5, 0}, 0.5
    ));
    // more walls
    scene.add(libscene.plane(
        -4, 0, 0,
        1, 0, 0, 
        .{1.0, 1.0, 1.0}, 0.99
    ));
    scene.add(libscene.plane(
        4, 0, 0,
        -1, 0, 0, 
        .{1.0, 1.0, 1.0}, 0.99
    ));

    // scene objects
    scene.add(libscene.sphere(
        2.1, 0.0, 14.0,
        1.8, 
        .{1.0, 0, 0}, 0.0
    ));
    scene.add(libscene.sphere(
        -1.0, 3.8, 13.0, 
        1.3, 
        .{0, 0, 1.0}, 0.5
    ));
    scene.add(libscene.box(
        0, -3.0, 12.0, 
        1, 2, 1, 
        .{0, 1.0, 1.0}, 0.5
    ));
    scene.add(libscene.triangle(
        -2.5, 2, 13,
        -4, -3.7, 14,
        1, -3.8, 16,
        .{1.0, 1.0, 1.0}, 0.5
    ));

    scene.updateLightsArray();

    return scene;
}

pub var threads: [8]*TracerThread = undefined;
pub var threadsFinished = [_]u8{0, 0, 0, 0, 0, 0, 0, 0};

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
        .width = 800,
        .height = 800,
        .flags = Window.WINDOW_SHOWN | Window.WINDOW_ALLOW_HIGHDPI
    });
    myWin.eventHandler = eventHandler; // attach event handler

    // print dimensions
    println("Starting...");

    // create canvas & rendering context
    var canvas = Canvas.alloc(allocator, myWin.width, myWin.height, 1.5, zcanvas.RendererType.Software);
    defer canvas.dealloc();
    const ctx = try canvas.getContext("2d", .{});

    // attach canvas to window
    myWin.setCanvas(&canvas);

    // setup scene
    var scene = buildScene();
    defer scene.dealloc();

    // initial frame
    var frame1 = Frame.alloc(myWin.width, myWin.height, &scene);
    defer frame1.dealloc();

    // distribute rendering
    const pixelCount = frame1.pixelMappings.len;
    const batchSize = @divTrunc(pixelCount,  8);
    {
        var i: u32 = 0;
        var batchNum: u32 = 0;
        while (batchNum < 8) {
            if (batchNum == 7) {
                threads[batchNum] = try TracerThread.spawn(batchNum, &frame1, i, pixelCount);
            } else {
                threads[batchNum] = try TracerThread.spawn(batchNum, &frame1, i, i + batchSize);
            }

            i += batchSize;
            batchNum += 1;
        }
    }

    var frameCount: f32 = 0;
    while (running) {
        // check for events
        myWin.pollInput();

        // run raytrace
        if (!frame1.done) {
            // frame1.renderBatch(1000);
            frame1.copyToImageBuffer(ctx._softItems.imgData.data.buffer, myWin.width);

            // print(frame1.currI * 100 / frame1.pixelMappings.len);
            // println("%");

            var isDone = true;
            {var i: usize = 0; while (i < threadsFinished.len) : (i += 1) {
                if (threadsFinished[i] == 0) {
                    isDone = false;
                }
            }}
            if (isDone) {
                frame1.done = true;
            }

            if (frame1.done) {
                println("DONE");
            }
        }

        // render frame
        try myWin.render();

        // wait for 16ms
        // if (frame1.done) {
            Window.wait(16);
        // }

        frameCount += 1.0;
    }

    // clean up
    myWin.dealloc();
}