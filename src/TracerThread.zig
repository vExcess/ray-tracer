const std = @import("std");
const Thread = std.Thread;

const vexlib = @import("vexlib");
const Math = vexlib.Math;
const ArrayList = vexlib.ArrayList;

const Tracer = @import("./tracer.zig");
const libmain = @import("./main.zig");
const Frame = libmain.Frame;

pub const TracerThread = struct {
    thread: Thread = undefined,
    running: bool = undefined,

    pub fn spawn(threadId: u32, frame: *Frame, start: u32, end: u32) !*TracerThread {
        const heapTracerThread = vexlib.allocatorPtr.*.create(TracerThread) catch @panic("AudioProcessorThread mem alloc fail");
        heapTracerThread.running = true;
        heapTracerThread.thread = try Thread.spawn(.{}, TracerThread.job, .{ threadId, frame, start, end });
        return heapTracerThread;
    }

    fn job(threadId: u32, frame: *Frame, start: u32, end: u32) void {
        var rayStack = ArrayList(Tracer.Ray).alloc(150);
        rayStack.len = rayStack.capacity();
        defer rayStack.dealloc();
        var i = start; while (i < end) : (i += 1) {
            // const idx: u32 = frame.pixelMappings.get(i) * 4;
            const idx = i * 4;
            const clr = TracerThread.tracePixel(frame, idx, &rayStack);
            frame.pixels.set(idx, clr[0]);
            frame.pixels.set(idx+1, clr[1]);
            frame.pixels.set(idx+2, clr[2]);
        }
        libmain.threadsFinished[threadId] = 1;
    }
    
    fn createRay(frame: *Frame, idx: u32) Tracer.Ray {
        const shiftedI = @as(f32, @floatFromInt(idx >> 2));

        const f32Width = @as(f32, @floatFromInt(frame.width));
        const f32Height = @as(f32, @floatFromInt(frame.height));

        const xPos: f32 = @mod(shiftedI, f32Width);
        const yPos = Math.floor(shiftedI / f32Width);

        // calculate the ray's x and y direction
        const heightRatio = f32Height / f32Width;
        const xVel = Math.map(xPos, 0.0, f32Width, -0.5, 0.5);
        const yVel = Math.map(yPos, 0.0, f32Height, 0.5 * heightRatio, -0.5 * heightRatio);

        // return the ray
        return Tracer.Ray{
            .pos = .{xVel, yVel, 1},
            .dir = .{xVel, yVel, 1},

            // stores whether the ray has hit something
            .hit = false,

            .isShadow = false,

            // stores the color the ray hit
            .clr = .{0, 0, 0}
        };
    }

    fn tracePixel(frame: *Frame, idx: u32, rayStack: *ArrayList(Tracer.Ray)) [3]u8 {
        var myRay = TracerThread.createRay(frame, idx);

        const trace = Tracer.rayTrace(frame.scene, &myRay, 0, rayStack);
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

        return [_]u8{r, g, b};
    }
};