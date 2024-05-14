const std = @import("std");

const vexlib = @import("lib/vexlib.zig");
const Math = vexlib.Math;
const ObjectArray = vexlib.ObjectArray;
const Uint8Array = vexlib.Uint8Array;
const Uint32Array = vexlib.Uint32Array;
const print = vexlib.print;
const println = vexlib.println;

const sdl = @cImport({
    @cInclude("lib/sdllib.h");
});

// SDL constants
const SDL_WINDOWPOS_CENTERED = 805240832;
const SDL_WINDOW_SHOWN = 4;
const SDL_WINDOW_BORDERLESS = 16;
const SDL_QUIT = 256;
const SDL_KEYDOWN = 768;

var sdlRunning: bool = true;

export fn handleSDLEvent(eventType: i32, eventData: i32) void {
    const KEY_ESCAPE = 27;

    switch (eventType) {
        SDL_QUIT => {
            sdlRunning = false;
        },
        SDL_KEYDOWN => {
            if (eventData == KEY_ESCAPE) {
                sdlRunning = false;
            }
        },
        else => {}
    }
}

fn rgbaToU32(r: u8, g: u8, b: u8, a: u8) u32 {
    return (@as(u32, @intCast(a)) << 24) | 
           (@as(u32, @intCast(r)) << 16) | 
           (@as(u32, @intCast(g)) <<  8) | 
           (@as(u32, @intCast(b))      );
}

fn u32ToRgba(val: u32) [4]u8 {
    return [4]u8{
        @as(u8, @intCast((val >> 16) & 255)),
        @as(u8, @intCast((val >>  8) & 255)),
        @as(u8, @intCast((val      ) & 255)),
        @as(u8, @intCast((val >> 24) & 255)),
    };
}

const Tracer = @import("./tracer.zig");

const Frame = struct {
    pixels: Uint8Array,
    pixelMappings: Uint32Array,
    width: u32,
    height: u32,
    f32Width: f32,
    f32Height: f32,
    scene: *ObjectArray(Tracer.Object),
    lights: ObjectArray(*Tracer.Object),
    currI: u32,
    done: bool,

    fn new(width: u32, height: u32, scene: *ObjectArray(Tracer.Object)) Frame {
        var pixels = Uint8Array.new(width * height * 4);
        pixels.fill(0, -1);
        pixels.len = pixels.capacity;

        const pixelCount = width * height;
        var randomMappings = Uint32Array.new(pixelCount);
        {var i: u32 = 0; while (i < pixelCount) : (i += 1) {
            randomMappings.append(i);
        }}
        
        {var i: u32 = 0; while (i < pixelCount) : (i += 1) {
            const j = @as(u32, @intFromFloat(Math.random(f32, 0.0, @as(f32, @floatFromInt(pixelCount)))));
            const temp = randomMappings.get(i);
            randomMappings.set(i, randomMappings.get(j));
            randomMappings.set(j, temp);
        }}

        var lights = ObjectArray(*Tracer.Object).new(1);
        {var i: u32 = 0; while (i < scene.len) : (i += 1) {
            const light = scene.get(i);
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

        const trace = Tracer.rayTrace(self.scene, &self.lights, &myRay, 0);
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

    fn free(self: *Frame) void {
        self.pixels.free();
        self.pixelMappings.free();
        self.lights.free();
    }

    fn update(self: *Frame, amt: u32) void {
        const end = Math.min(self.currI + amt, self.pixelMappings.len - 1);
        while (self.currI < end) : (self.currI += 1) {
            self.renderPixel(self.currI);
        }
        self.done = self.currI == self.pixels.len / 4 - 1;
    }

    fn display(frame_: Frame, buff: anytype, width: u32) void {
        var frame = frame_;
        var i: u32 = 0; while (i < frame.pixels.len) : (i += 4) {
            const x = (i >> 2) % frame.width;
            const y = ((i >> 2) / frame.width);
            const scale = width / frame.width;
            {var xOff: u32 = 0; while (xOff < scale) : (xOff += 1) {
                {var yOff: u32 = 0; while (yOff < scale) : (yOff += 1) {
                    const mappedIdx = @as(usize, @intCast((x * scale + xOff) + (y * scale + yOff) * width));
                    buff.*[mappedIdx] = rgbaToU32(
                        frame.pixels.get(i),
                        frame.pixels.get(i+1),
                        frame.pixels.get(i+2),
                        255.0
                    );
                }}
            }}
        }
    }
};

pub fn main() !void {
    // setup allocator
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalPurposeAllocator.deinit();
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);
    
    println("Game running");

    // render SDL window
    sdlRunning = sdl.createWindow(
        "demo", 
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 
        400, 400, 
        SDL_WINDOW_SHOWN
    ) > 0;

    const MASK_16 = (1 << 16) - 1;
    // const screenWidth: u32 = sdl.getScreenRes() >> 16;
    // const screenHeight: u32 = sdl.getScreenRes() & MASK_16;
    const pixels = sdl.getPixels();
    const windowWidth: u32 = sdl.getWindowRes() >> 16;
    const windowHeight: u32 = sdl.getWindowRes() & MASK_16;

    var scene = ObjectArray(Tracer.Object).new(0);
    defer scene.free();
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

    var frame1 = Frame.new(windowWidth, windowHeight, &scene);
    defer frame1.free();
    
    var frameCount: f32 = 0;
    while (sdlRunning) {
        sdl.pollInput();

        if (!frame1.done) {
            frame1.update(100);
            Frame.display(frame1, &pixels, windowWidth);

            // print(frame1.currI * 100 / frame1.pixelMappings.len);
            // println("%");

            if (frame1.done) {
                println("DONE");
            }
        }

        sdl.updateWindow();
        sdl.wait(1);
        frameCount += 1.0;
    }

    sdl.destroyWindow();
}