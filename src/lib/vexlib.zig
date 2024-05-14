// v0.0.10

pub const wasmFreestanding: bool = false;

const std = @import("std");
const Prng = std.rand.DefaultPrng;
const http = std.http;

pub var allocatorPtr: *const std.mem.Allocator = undefined;
pub var prng: std.rand.DefaultPrng = undefined;

pub fn init(allocator: *const std.mem.Allocator) void {
    allocatorPtr = allocator;
    prng = std.rand.DefaultPrng.init(@intFromPtr(allocator));
}

var gaussianf32Y2: f32 = 0;
var gaussianf64Y2: f64 = 0;
var gaussianf32Previous = false;
var gaussianf64Previous = false;

pub const Math = struct {
    pub const PI: f64 = 3.141592653589793;
    pub const E = 2.71828182845904523536028747135266249775724709369995;

    pub fn abs(x: anytype) @TypeOf(x) {
        switch (@typeInfo(@TypeOf(x))) {
            .ComptimeInt, .Int => {
                return if (x < 0) -x else x;
            },
            .ComptimeFloat, .Float => {
                return if (x < 0.0) -x else x;
            },
            else => @compileError("Math.abs only accepts integers and floats")
        }
    }

    pub fn pow(x: anytype, y: anytype) @TypeOf(x, y) {
        return std.math.pow(@TypeOf(x, y), x, y);
    }

    pub fn loge(num: anytype) @TypeOf(num) {
        return std.math.log(@TypeOf(num), Math.E, num);
    }

    pub fn log(base: anytype, num: anytype) @TypeOf(num) {
        return std.math.log(@TypeOf(num), base, num);
    }

    pub fn sqrt(x: anytype) @TypeOf(x) {
        return std.math.sqrt(x);
    }

    pub fn round(x: anytype) @TypeOf(x) {
        return std.math.round(x);
    }

    pub fn floor(x: anytype) @TypeOf(x) {
        return std.math.floor(x);
    }

    pub inline fn cos(x: anytype) @TypeOf(x) {
        return std.math.cos(x);
    }

    pub inline fn sin(x: anytype) @TypeOf(x) {
        return std.math.sin(x);
    }

    pub fn atan2(y: anytype, x: anytype) @TypeOf(y) {
        return std.math.atan2(y, x);
    }

    pub fn factorial(x: anytype) @TypeOf(x) {
        var val = x;
        var i = 2;
        while (i < x) : (i += 1) {
            val *= i;
        }
        return val;
    }

    pub fn min(x: anytype, y: @TypeOf(x)) @TypeOf(x) {
        if (x < y) {
            return x;
        } else {
            return y;
        }
    }

    pub fn constrain(val: anytype, min_: @TypeOf(val), max_: @TypeOf(val)) @TypeOf(val) {
        if (val > max_) {
            return max_;
        } else if (val < min_) {
            return min_;
        } else {
            return val;
        }
    }

    pub fn max(x: anytype, y: anytype) @TypeOf(x, y) {
        if (x > y) {
            return x;
        } else {
            return y;
        }
    }

    pub fn map(value: anytype, istart: @TypeOf(value), istop: @TypeOf(value), ostart: @TypeOf(value), ostop: @TypeOf(value)) @TypeOf(value) {
        return ostart + (ostop - ostart) * ((value - istart) / (istop - istart));
    }

    pub fn lerp(val1: anytype, val2: anytype, amt: anytype) @TypeOf(val1, val2) {
        const valType = @TypeOf(val1, val2);
        switch (@typeInfo(@TypeOf(val1, val2))) {
            .Vector => |vecData| {
                const castedAmt = @as(vecData.child, @floatCast(amt));
                return ((val2 - val2) * @as(valType, @splat(castedAmt))) + val1;
            },
            else => {
                return ((val2 - val2) * @as(valType, @floatCast(amt))) + val1;
            }
        }
    }

    pub fn Infinity(val: type) val {
        const inf_u16: u16 = 0x7C00;
        const inf_u32: u32 = 0x7F800000;
        const inf_u64: u64 = 0x7FF0000000000000;
        const inf_u80: u80 = 0x7FFF8000000000000000;
        const inf_u128: u128 = 0x7FFF0000000000000000000000000000;

        return switch (val) {
            f16 => @as(f16, @bitCast(inf_u16)),
            f32 => @as(f32, @bitCast(inf_u32)),
            f64 => @as(f64, @bitCast(inf_u64)),
            f80 => @as(f80, @bitCast(inf_u80)),
            f128 => @as(f128, @bitCast(inf_u128)),
            else => @compileError("Math.Infinity only exists for f16, f32, f64, f80, f128")
        };
    }

    pub fn random(T: type, min_: T, max_: T) T {
        const num = prng.random().float(T);
        return num * (max_ - min_) + min_;
    }

    pub fn randomGaussian(T: type) T {
        var y1: T = undefined;
        var x1: T = undefined;
        var x2: T = undefined;
        var w: T = undefined;

        switch (T) {
            f32 => {
                if (gaussianf32Previous) {
                    y1 = gaussianf32Y2;
                    gaussianf32Previous = false;
                } else {
                    x1 = Math.random(T, -1, 1);
                    x2 = Math.random(T, -1, 1);
                    w = x1 * x1 + x2 * x2;
                    while (w >= 1) {
                        x1 = Math.random(T, -1, 1);
                        x2 = Math.random(T, -1, 1);
                        w = x1 * x1 + x2 * x2;
                    }
                    w = Math.sqrt(-2 * Math.loge(w) / w);
                    y1 = x1 * w;
                    gaussianf32Y2 = x2 * w;
                    gaussianf32Previous = true;
                }
            },
            f64 => {
                if (gaussianf64Previous) {
                    y1 = gaussianf64Y2;
                    gaussianf64Previous = false;
                } else {
                    x1 = Math.random(T, -1, 1);
                    x2 = Math.random(T, -1, 1);
                    w = x1 * x1 + x2 * x2;
                    while (w >= 1) {
                        x1 = Math.random(T, -1, 1);
                        x2 = Math.random(T, -1, 1);
                        w = x1 * x1 + x2 * x2;
                    }
                    w = Math.sqrt(-2 * Math.loge(w) / w);
                    y1 = x1 * w;
                    gaussianf64Y2 = x2 * w;
                    gaussianf64Previous = true;
                }
            },
            else => @compileError("Math.randomGaussian only accepts f32 or f64")
        }

        return y1;
    }

    // vector maths
    pub fn mag(v: anytype) @TypeOf(v[0]) {
        const sqd = v * v;
        switch (@typeInfo(@TypeOf(v))) {
            .Vector => |vecData| {
                switch (vecData.len) {
                    2 => return Math.sqrt(sqd[0] + sqd[1]),
                    3 => return Math.sqrt(sqd[0] + sqd[1] + sqd[2]),
                    4 => return Math.sqrt(sqd[0] + sqd[1] + sqd[2] + sqd[3]),
                    else => @compileError("unsupported vector length")
                }
            },
            else => @compileError("Math.mag only accepts vectors")
        }
    }

    pub fn normalize(v: anytype) @TypeOf(v) {
        const m = Math.mag(v);
        if (m > 0.0) {
            return v / @as(@TypeOf(v), @splat(m));
        }
        return v;
    }

    pub fn dot(v1: anytype, v2: anytype) @TypeOf(v1[0]) {
        switch (@typeInfo(@TypeOf(v1, v2))) {
            .Vector => |vecData| {
                switch (vecData.len) {
                    2 => return v1[0] * v2[0] + v1[1] * v2[1],
                    3 => return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2],
                    4 => return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3],
                    else => @compileError("unsupported vector length")
                }
            },
            else => @compileError("Math.dot only accepts vectors")
        }
    }

    pub fn cross(v1: anytype, v2: anytype) @TypeOf(v1, v2) {
        return .{
            v1[1] * v2[2] - v1[2] * v2[1],
            v1[2] * v2[0] - v1[0] * v2[2],
            v1[0] * v2[1] - v1[1] * v2[0]
        };
    }
};

pub const microseconds = if (wasmFreestanding)
    (struct {
        pub extern fn microseconds() i64;
    }).microseconds
else
    (struct {
        fn microseconds() i64 {
            return std.time.microTimestamp();
        }
    }).microseconds;

pub fn millis() i64 {
    return @divTrunc(microseconds(), 1000);
}

pub fn time() f64 {
    return @as(f64, @floatFromInt(millis() / 1000));
}

pub const fs_write = if (wasmFreestanding)
    (struct {
        pub extern fn fs_write(fid: i32, addr: usize, len: u32) void;
    }).fs_write
else
    (struct {
        fn fs_write(fid: i32, addr: usize, len: u32) void {
            const manyPtr: [*]u8 = @ptrFromInt(addr);
            const slice: []u8 = manyPtr[0..len];

            if (fid == 1) {
                std.debug.print("{s}\n", .{slice});
            }
        }
    }).fs_write;

pub fn print(data_: anytype) void {
    const write = std.debug.print;

    var outString: String = undefined;

    if (@TypeOf(data_) == String) {
        var temp = data_;
        if (wasmFreestanding) {
            outString = temp.toString();
            defer outString.free();
            fs_write(1, @intFromPtr(outString.bytes.buffer.?.ptr), outString.len);
        } else {
            write("{s}", .{temp.raw()});
        }
    } else {
        switch (@typeInfo(@TypeOf(data_))) {
            .Struct => {
                outString = String.newFrom(data_);
            },
            .Array, .Pointer => {
                // handle const strings
                if (std.meta.Elem(@TypeOf(data_)) == u8) {
                    outString = String.newFrom(data_);
                }
            },
            .Vector => |vecData| {
                outString = String.newFrom("@Vector<");
                outString.concat(@typeName(vecData.child));
                outString.concat(">{");
                var i: usize = 0; while (i < vecData.len) : (i += 1) {
                    var numStr = Float.toString(data_[i], 10);
                    defer numStr.free();
                    outString.concat(numStr);
                    if (i < vecData.len - 1) {
                        outString.concat(", ");
                    }
                }
                outString.concat("}");
            },
            else => {
                switch (@TypeOf(data_)) {
                    comptime_int, i8, u8, i16, u16, i32, u32, i64, u64, i128, u128, isize, usize => {
                        outString = Int.toString(data_, 10);
                    },
                    comptime_float, f16, f32, f64, f80, f128 => {
                        outString = Float.toString(data_, 10);
                    },
                    bool => {
                        if (data_) {
                            outString = String.newFrom("true");
                        } else {
                            outString = String.newFrom("false");
                        }
                    },
                    @TypeOf(null) => {
                        outString = String.newFrom("null");
                    },
                    @TypeOf(void) => {
                        outString = String.newFrom("void");
                    },
                    else => {
                        if (wasmFreestanding) {
                            outString = String.newFrom("error: unreachable code has been reached");
                        } else {
                            @compileError("attempted to print unsupported type of data");
                        }
                    }
                }
            },
        }

        if (wasmFreestanding) {
            fs_write(1, @intFromPtr(outString.bytes.buffer.?.ptr), outString.len);
        } else {
            write("{s}", .{outString.raw()});
        }
        outString.free();
    }
                        
}
pub fn println(data: anytype) void {
    print(data);
    print("\n");
}

const stdin = std.io.getStdIn().reader();
pub fn readln(maxLen: u32) !String {
    var out = String.new(maxLen);
    if (try stdin.readUntilDelimiterOrEof(out.bytes.buffer.?, '\n')) |user_input| {
        return out.slice(0, @as(u32, @intCast(user_input.len)));
    } else {
        return String.new(0);
    }
}

pub const HTTPResponse = struct {
    allocatorPtr: *const std.mem.Allocator = undefined,
    body: []u8 = undefined,
    // headers = .{},
    ok: bool = undefined,
    redirected: bool = undefined,
    status: bool = undefined,
    statusText: []u8 = undefined,
    url: String = undefined,
    
    pub fn text(self: *HTTPResponse) String {
        return String.newFrom(self.body);
    }

    pub fn free(self: *HTTPResponse) void {
        var allocator = self.allocatorPtr.*;
        allocator.free(self.body);
        self.url.free();
    }
};

pub fn fetch(url_: anytype, options: anytype) !HTTPResponse {
    // create String url
    var url: String = undefined;
    switch (@TypeOf(url_)) {
        // String
        String => {
            url = url_.toString();
        },
        // const string
        else => {
            url = String.newFrom(url_);
        },
    }

    var method = http.Method.GET;
    var hasBody = false;

    const Client = std.http.Client;
    const Value = Client.Request.Headers.Value;
    var headers = Client.Request.Headers{};
    headers.accept_encoding = Value.omit;
    headers.connection = Value.omit;

    inline for (@typeInfo(@TypeOf(options)).Struct.fields) |field| {
        const value = @field(options, field.name);
        if (@typeInfo(@TypeOf(value)) == .Struct) {
            if (std.mem.eql(u8, field.name, "headers")) {
                inline for (@typeInfo(@TypeOf(value)).Struct.fields) |subfield| {
                    const subValue = @field(value, subfield.name);
                    if (std.mem.eql(u8, subfield.name, "content_type")) {
                        headers.content_type = Value{ .override = subValue };
                    }
                }
            }
        } else {
            if (std.mem.eql(u8, field.name, "method")) {
                if (std.mem.eql(u8, value, "POST")) {
                    method = http.Method.POST;
                }
            } else if (std.mem.eql(u8, field.name, "body")) {
                method = http.Method.POST;
                hasBody = true;
            }
        }
    }

    const allocator = allocatorPtr.*;

    // create http client
    var httpClient = http.Client{ .allocator = allocator };
    defer httpClient.deinit();

    // create uri object
    const uri = try std.Uri.parse(url.raw());
    var server_header_buffer: [16 * 1024]u8 = undefined;

    var req = try httpClient.open(method, uri, .{
        .server_header_buffer = &server_header_buffer,
        .redirect_behavior = .unhandled,
        .headers = headers,
        // .extra_headers = options.extra_headers,
        // .privileged_headers = options.privileged_headers,
        // .keep_alive = options.keep_alive,
    });
    defer req.deinit();
    req.transfer_encoding = Client.RequestTransfer{ .content_length = options.body.len };

    try req.send(); // send headers
    if (hasBody) {
        try req.writeAll(options.body);  
    } 
    try req.finish(); // finish body
    try req.wait(); // wait for response

    const res = try req.reader().readAllAlloc(allocator, 1024);

    return HTTPResponse{
        .allocatorPtr = allocatorPtr,
        .body = res,
        // .headers = .{},
        .ok = req.response.status.class() == .success,
        // .redirected = false,
        // .status = 200,
        // .statusText = "",
        // .type = "",
        .url = url,
    };
}


pub fn IntArray(comptime T: type) type {
    return struct {
        len: u32 = 0,
        capacity: u32 = 0,
        buffer: ?[]T = null,
        allocatorPtr: *const std.mem.Allocator = undefined,

        const Self = @This();

        pub fn new(capacity: u32) Self {
            var allocator = allocatorPtr.*;
            const buffer = allocator.alloc(T, capacity) catch unreachable;
            return Self{
                .capacity = capacity,
                .buffer = buffer,
                .allocatorPtr = allocatorPtr,
            };
        }

        pub fn free(self: *Self) void {
            var allocator = self.allocatorPtr.*;
            allocator.free(self.buffer.?);
        }

        pub fn get(self: *Self, idx: u32) T {
            return self.buffer.?[idx];
        }

        pub fn set(self: *Self, idx: u32, val: T) void {
            self.buffer.?[idx] = val;
        }

        pub fn fill(self: *Self, val: T, len_: i32) void {
            const len: u32 = if (len_ == -1) @as(u32, @intCast(self.buffer.?.len)) else @as(u32, @intCast(len_));
            var i: u32 = 0;
            while (i < len) : (i += 1) {
                self.buffer.?[i] = val;
            }
            self.len = len;
        }

        pub fn resize(self: *Self, newCapacity: u32) void {
            var allocator = self.allocatorPtr.*;
            var newBuffer = allocator.alloc(T, newCapacity) catch unreachable;

            for (self.buffer.?, 0..) |val, idx| {
                newBuffer[idx] = val;
            }

            allocator.free(self.buffer.?);
            self.capacity = newCapacity;
            self.buffer = newBuffer;
        }

        pub fn append(self: *Self, val: T) void {
            const prevLen = self.len;
            if (prevLen == self.capacity) {
                if (self.capacity == 0) {
                    self.capacity = 1;
                }
                self.resize(self.capacity * 2);
            }
            self.buffer.?[prevLen] = val;
            self.len += 1;
        }

        pub fn remove(self: *Self, idx: u32, len: u32) void {
            const buff = self.buffer.?;
            var i = idx;
            while (i + len < self.len) : (i += 1) {
                buff[i] = buff[i + len];
            }
            self.len -= len;
        }

        pub fn indexOf(self: *Self, val: T) i32 {
            const buff = self.buffer.?;
            var i: usize = 0;
            while (i < self.len) : (i += 1) {
                if (buff[i] == val) {
                    return @as(i32, @intCast(i));
                }
            }
            return -1;
        }

        pub fn toString(self: *Self) String {
            var out = String.new(0);
            const buff = self.buffer.?;

            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                var temp = Int.toString(buff[i], 10);
                defer temp.free();
                out.concat(temp);
                if (i < self.len - 1) {
                    out.concat(",");
                }
            }

            return out;
        }
    };
}

pub fn FloatArray(comptime T: type) type {
    return struct {
        len: u32 = 0,
        capacity: u32 = 0,
        buffer: ?[]T = null,
        allocatorPtr: *const std.mem.Allocator = undefined,

        const Self = @This();

        pub fn new(capacity: u32) Self {
            var allocator = allocatorPtr.*;
            const buffer = allocator.alloc(T, capacity) catch unreachable;
            return Self{
                .capacity = capacity,
                .buffer = buffer,
                .allocatorPtr = allocatorPtr,
            };
        }

        pub fn free(self: *Self) void {
            var allocator = self.allocatorPtr.*;
            allocator.free(self.buffer.?);
        }

        pub fn get(self: *Self, idx: u32) T {
            return self.buffer.?[idx];
        }

        pub fn set(self: *Self, idx: u32, val: T) void {
            self.buffer.?[idx] = val;
        }

        pub fn fill(self: *Self, val: T, len_: i32) void {
            const len: u32 = if (len_ == -1) @as(u32, @intCast(self.buffer.?.len)) else @as(u32, @intCast(len_));
            var i: u32 = 0;
            while (i < len) : (i += 1) {
                self.buffer.?[i] = val;
            }
            self.len = len;
        }

        pub fn resize(self: *Self, newCapacity: u32) void {
            var allocator = self.allocatorPtr.*;
            var newBuffer = allocator.alloc(T, newCapacity) catch unreachable;

            for (self.buffer.?, 0..) |val, idx| {
                newBuffer[idx] = val;
            }

            allocator.free(self.buffer.?);
            self.capacity = newCapacity;
            self.buffer = newBuffer;
        }

        pub fn append(self: *Self, val: T) void {
            const prevLen = self.len;
            if (prevLen == self.capacity) {
                if (self.capacity == 0) {
                    self.capacity = 1;
                }
                self.resize(self.capacity * 2);
            }
            self.buffer.?[prevLen] = val;
            self.len += 1;
        }

        pub fn toString(self: *Self) String {
            var out = String.new(0);
            const buff = self.buffer.?;

            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                var temp = Float.toString(buff[i], 10);
                defer temp.free();
                out.concat(temp);
                if (i < self.len - 1) {
                    out.concat(",");
                }
            }

            return out;
        }
    };
}

pub fn ObjectArray(comptime T: type) type {
    return struct {
        len: u32 = 0,
        capacity: u32 = 0,
        buffer: ?[]T = null,
        allocatorPtr: *const std.mem.Allocator = undefined,

        const Self = @This();

        pub fn new(capacity: u32) Self {
            var allocator = allocatorPtr.*;
            const buffer = allocator.alloc(T, capacity) catch unreachable;
            return Self{
                .capacity = capacity,
                .buffer = buffer,
                .allocatorPtr = allocatorPtr,
            };
        }

        pub fn free(self: *Self) void {
            var allocator = self.allocatorPtr.*;
            allocator.free(self.buffer.?);
        }

        pub fn get(self: *Self, idx: u32) *T {
            return &self.buffer.?[idx];
        }

        pub fn getCopy(self: *Self, idx: u32) T {
            return self.buffer.?[idx];
        }

        pub fn set(self: *Self, idx: u32, val: T) void {
            self.buffer.?[idx] = val;
        }

        pub fn fill(self: *Self, val: T, len_: i32) void {
            const len: u32 = if (len_ == -1) @as(u32, @intCast(self.buffer.?.len)) else @as(u32, @intCast(len_));
            var i: u32 = 0;
            while (i < len) : (i += 1) {
                self.buffer.?[i] = val;
            }
            self.len = len;
        }

        pub fn resize(self: *Self, newCapacity: u32) void {
            var allocator = self.allocatorPtr.*;
            var newBuffer = allocator.alloc(T, newCapacity) catch unreachable;

            for (self.buffer.?, 0..) |val, idx| {
                newBuffer[idx] = val;
            }

            allocator.free(self.buffer.?);
            self.capacity = newCapacity;
            self.buffer = newBuffer;
        }

        pub fn append(self: *Self, val: T) void {
            const prevLen = self.len;
            if (prevLen == self.capacity) {
                if (self.capacity == 0) {
                    self.capacity = 1;
                }
                self.resize(self.capacity * 2);
            }
            self.buffer.?[prevLen] = val;
            self.len += 1;
        }

        pub fn toString(self: *Self) String {
            var out = String.new(0);

            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                var item = self.get(i);
                var temp = item.toString();
                defer temp.free();
                out.concat(temp);
                if (i < self.len - 1) {
                    out.concat(",");
                }
            }

            return out;
        }
    };
}

pub const Uint8Array = IntArray(u8);
pub const Int8Array = IntArray(i8);
pub const Uint16Array = IntArray(u16);
pub const Int16Array = IntArray(i16);
pub const Uint32Array = IntArray(u32);
pub const Int32Array = IntArray(i32);
pub const Uint64Array = IntArray(u64);
pub const Int64Array = IntArray(i64);
pub const Float32Array = FloatArray(f32);
pub const Float64Array = FloatArray(f64);

pub fn Map(comptime KeyType: type, comptime ValueType: type) type {
    return struct {
        keys: switch (@typeInfo(KeyType)) {
            .Float => Float32Array,
            .Int => Int32Array,
            else => ObjectArray(KeyType),
        } = undefined,
        values: switch (@typeInfo(ValueType)) {
            .Float => Float32Array,
            .Int => Int32Array,
            else => ObjectArray(ValueType),
        } = undefined,

        // const Self = @This();

        // pub fn new(capacity: u32) Self {
        //     var allocator = allocatorPtr.*;
        //     const buffer = allocator.alloc(T, capacity) catch unreachable;
        //     return Self{
        //         .capacity = capacity,
        //         .buffer = buffer,
        //         .allocatorPtr = allocatorPtr,
        //     };
        // }

        // pub fn free(self: *Self) void {
        //     var allocator = self.allocatorPtr.*;
        //     allocator.free(self.buffer.?);
        // }

        // pub fn get(self: *Self, idx: u32) *T {
        //     return &self.buffer.?[idx];
        // }

        // pub fn set(self: *Self, idx: u32, val: T) void {
        //     self.buffer.?[idx] = val;
        // }

    };
}

pub const String = struct {
    len: u32 = 0,
    viewStart: u32 = 0,
    viewEnd: u32 = 0,
    bytes: Uint8Array,
    isSlice: bool = false,

    pub fn new(capacity: u32) String {
        const bytes = Uint8Array.new(capacity);
        return String{
            .len = 0,
            .viewStart = 0,
            .viewEnd = 0,
            .bytes = bytes,
            .isSlice = false
        };
    }

    pub fn newFrom(data_: anytype) String {
        var data = data_;
        if (@TypeOf(data) == String) {
            const temp = data.toString();
            return temp;
        } else if (@typeInfo(@TypeOf(data)) == .Struct) {
            var temp = String.newFrom(".{\n");
            inline for (@typeInfo(@TypeOf(data)).Struct.fields) |field| {
                const value = @field(data, field.name);
                if (@typeInfo(@TypeOf(value)) == .Struct) {
                    
                } else {
                    temp.concat("    .");
                    temp.concat(field.name);
                    temp.concat(" = ");
                    const allocator = allocatorPtr.*;
                    const formatted = std.fmt.allocPrint(allocator, "{any}", .{ value }) catch unreachable;
                    defer allocator.free(formatted);
                    temp.concat(formatted);
                    temp.concat(",\n");
                }
            }
            temp.concat("}");
            return temp;
        } else {
            switch (@TypeOf(data)) {
                // char
                comptime_int, i8, u8, i16, u16, i32, u32, i64, u64, i128, u128, isize, usize => {
                    const temp = Int.toString(data, 10);
                    return temp;
                },
                // const string
                else => {
                    const len = @as(u32, @intCast(data.len));
                    var temp = String.new(len);
                    temp.len = len;
                    temp.viewEnd = len;
                    temp.bytes.len = len;

                    for (data, 0..) |val, idx| {
                        temp.bytes.buffer.?[idx] = val;
                    }

                    return temp;
                },
            }
        }
        
    }

    pub fn free(self: *String) void {
        self.bytes.free();
    }

    pub fn charAt(self: *String, idx: u32) u8 {
        return self.bytes.get(self.viewStart + idx);
    }

    pub fn charCodeAt(self: *String, idx: u32) u8 {
        return self.bytes.get(self.viewStart + idx);
    }

    pub fn setChar(self: *String, idx: u32, val: u8) void {
        self.bytes.set(self.viewStart + idx, val);
    }

    pub fn concat(self: *String, data: anytype) void {
        if (self.isSlice) {
            unreachable;
        }
        switch (@TypeOf(data)) {
            // char
            comptime_int, i8, u8, i16, u16, i32, u32, i64, u64, i128, u128, isize, usize => {
                self.bytes.append(data);
                self.len = self.bytes.len;
                self.viewEnd = self.len;
                return;
            },
            // String
            String => {
                var i: u32 = data.viewStart;
                while (i < data.viewEnd) : (i += 1) {
                    self.bytes.append(data.bytes.buffer.?[i]);
                    self.len = self.bytes.len;
                    self.viewEnd = self.len;
                }
                return;
            },
            // const string
            else => {
                for (data, 0..) |val, idx| {
                    _ = idx;
                    self.bytes.append(val);
                    self.len = self.bytes.len;
                    self.viewEnd = self.len;
                }
                return;
            },
        }
    }

    pub fn equals(self: *String, str: anytype) bool {
        var temp: String = undefined;
        var needsFreeing = false;
        var out = true;
        switch (@TypeOf(str)) {
            String => {
                temp = str;
            },
            else => {
                temp = String.newFrom(str);
                needsFreeing = true;
            }
        }

        if (temp.len != self.len) {
            out = false;
        } else {
            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                if (self.charAt(i) != temp.charAt(i)) {
                    out = false;
                    break;
                }
            }
        }

        defer if (needsFreeing) temp.free();
        
        return out;
    }

    pub fn toSlice(self: *String, start_: u32, end_: u32) String {
        const start = start_;
        var end = end_;

        if (end == 0) {
            end = self.len;
        }
        var bytes = Uint8Array.new(end - start);
        bytes.len = end - start;

        var i: u32 = 0;
        while (i < bytes.len) : (i += 1) {
            bytes.buffer.?[i] = self.bytes.buffer.?[start + i];
        }

        return String{
            .len = bytes.len,
            .viewStart = 0,
            .viewEnd = bytes.len,
            .bytes = bytes,
            .isSlice = false
        };
    }

    pub fn slice(self: *String, start_: u32, end_: u32) String {
        const start = start_;
        var end = end_;

        if (end == 0) {
            end = self.len;
        }

        return String{
            .len = end - start,
            .viewStart = self.viewStart + start,
            .viewEnd = self.viewStart + end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn trimStart(self: *String) String {
        var start = self.viewStart;
        const end = self.viewEnd;
        const buff = self.bytes.buffer.?;

        // trim start
        while (
            start < end and
            (buff[start] == 9 or 
            buff[start] == 10 or
            buff[start] == 11 or
            buff[start] == 12 or
            buff[start] == 13 or
            buff[start] == 32)
        ) {
            start += 1;
        }

        return String{
            .len = end - start,
            .viewStart = start,
            .viewEnd = end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn trimEnd(self: *String) String {
        const start = self.viewStart;
        var end = self.viewEnd;
        const buff = self.bytes.buffer.?;

        // trim end
        var endMinusOne: isize = end - 1;
        while (
            end > start and
            (buff[@as(usize, @bitCast(endMinusOne))] == 9 or 
            buff[@as(usize, @bitCast(endMinusOne))] == 10 or
            buff[@as(usize, @bitCast(endMinusOne))] == 11 or
            buff[@as(usize, @bitCast(endMinusOne))] == 12 or
            buff[@as(usize, @bitCast(endMinusOne))] == 13 or
            buff[@as(usize, @bitCast(endMinusOne))] == 32)
        ) {
            endMinusOne -= 1;
            end -= 1;
        }

        return String{
            .len = end - start,
            .viewStart = start,
            .viewEnd = end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn trim(self: *String) String {
        var start = self.viewStart;
        var end = self.viewEnd;
        const buff = self.bytes.buffer.?;

        // trim start
        while (
            start < end and
            (buff[start] == 9 or 
            buff[start] == 10 or
            buff[start] == 11 or
            buff[start] == 12 or
            buff[start] == 13 or
            buff[start] == 32)
        ) {
            start += 1;
        }
        
        // trim end
        var endMinusOne = end - 1;
        while (
            (buff[endMinusOne] == 9 or 
            buff[endMinusOne] == 10 or
            buff[endMinusOne] == 11 or
            buff[endMinusOne] == 12 or
            buff[endMinusOne] == 13 or
            buff[endMinusOne] == 32)
            and end > start
        ) {
            endMinusOne -= 1;
            end -= 1;
        }

        return String{
            .len = end - start,
            .viewStart = start,
            .viewEnd = end,
            .bytes = self.bytes,
            .isSlice = true
        };
    }

    pub fn split(self: *String, str: anytype) ObjectArray(String) {
        var delimiter: String = undefined;
        var needsFreeing = false;
        var out = ObjectArray(String).new(0);
        switch (@TypeOf(str)) {
            String => {
                delimiter = str;
            },
            else => {
                delimiter = String.newFrom(str);
                needsFreeing = true;
            }
        }

        var selfCopy = self.*;
        var idx = selfCopy.indexOf(delimiter);
        while (idx != -1) {
            const slc = selfCopy.slice(0, @as(u32, @bitCast(idx)));
            out.append(slc);
            selfCopy = selfCopy.slice(@as(u32, @bitCast(idx)) + delimiter.len, 0);
            idx = selfCopy.indexOf(delimiter);
        }

        if (selfCopy.len > 0) {
            const idk = selfCopy.slice(0, 0);
            out.append(idk);
        }

        defer if (needsFreeing) delimiter.free();
        
        return out;
    }

    pub fn repeat(self: *String, amt: u32) void {
        if (self.isSlice) {
            @compileError("cannot repeat a slice");
        }
        var selfClone = self.toString();
        defer selfClone.free();
        var i: u32 = 0;
        while (i < amt - 1) : (i += 1) {
            self.concat(selfClone);
        }
    }

    pub fn padStart(self: *String, width: u32, str: anytype) void {
        if (self.isSlice) {
            @compileError("cannot pad a slice");
        }
        const padAmount = width - self.len;
        if (padAmount > 0) {
            var temp = String.new(width);
            temp.concat(str);
            temp.repeat(padAmount / temp.len);
            temp.concat(self.*);

            self.free();
            self.bytes = temp.bytes;
            self.len = temp.len;
        }
    }

    pub fn padEnd(self: *String, width: u32, str: anytype) void {
        if (self.isSlice) {
            @compileError("cannot pad a slice");
        }
        const padAmount = width - self.len;
        if (padAmount > 0) {
            var temp = String.new(width);
            defer temp.free();
            temp.concat(str);
            temp.repeat(padAmount / temp.len);
            self.concat(temp);
        }
    }

    pub fn lowerCase(self: *String) void {
        var i: u32 = 0;
        while (i < self.len) : (i += 1) {
            const c = self.charAt(i);
            if (c >= 'A' and c <= 'Z') {
                self.setChar(i, c + 32);
            }
        }
    }

    pub fn upperCase(self: *String) void {
        var i: u32 = 0;
        while (i < self.len) : (i += 1) {
            const c = self.charAt(i);
            if (c >= 'a' and c <= 'z') {
                self.setChar(i, c - 32);
            }
        }
    }

    pub fn indexOf(self: *String, str: anytype) i32 {
        var temp: String = undefined;
        var isChar = false;
        var charVal: u8 = 0;
        var needsFreeing = false;
        switch (@TypeOf(str)) {
            comptime_int, u8 => {
                isChar = true;
                charVal = str;
            },
            String => {
                temp = str;
            },
            else => {
                temp = String.newFrom(str);
                if (temp.len == 1) {
                    isChar = true;
                    charVal = temp.charAt(0);
                    defer temp.free();
                } else {
                    needsFreeing = true;
                }
            }
        }
        
        if (isChar) {
            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                if (self.charAt(i) == charVal) {
                    return @as(i32, @bitCast(i));
                }
            }
        } else {
            var i: u32 = 0;
            while (i < self.len) : (i += 1) {
                var j: u32 = 0;
                while (j < temp.len) : (j += 1) {
                    if (self.charAt(i + j) == temp.charAt(j)) {
                        if (j == temp.len - 1) {
                            defer if (needsFreeing) temp.free();
                            return @as(i32, @bitCast(i));
                        }
                    } else {
                        break;
                    }
                }
            }

            defer if (needsFreeing) temp.free();
        }

        return -1;
    }

    pub fn contains(self: *String, str: anytype) bool {
        return self.indexOf(str) >= 0;
    }

    pub fn startsWith(self: *String, str: anytype) bool {
        var temp: String = undefined;
        var needsFreeing = false;
        var out = true;
        switch (@TypeOf(str)) {
            String => {
                temp = str;
            },
            else => {
                temp = String.newFrom(str);
                needsFreeing = true;
            }
        }

        if (temp.len > self.len) {
            out = false;
        } else {
            var i: u32 = 0;
            while (i < temp.len) : (i += 1) {
                if (self.charAt(i) != temp.charAt(i)) {
                    out = false;
                    break;
                }
            }
        }

        defer if (needsFreeing) temp.free();
        
        return out;
    }

    pub fn endsWith(self: *String, str: anytype) bool {
        var temp: String = undefined;
        var needsFreeing = false;
        var out = true;
        switch (@TypeOf(str)) {
            String => {
                temp = str;
            },
            else => {
                temp = String.newFrom(str);
                needsFreeing = true;
            }
        }

        if (temp.len > self.len) {
            out = false;
        } else {
            var i: u32 = 0;
            const offset = self.len - temp.len;
            while (i < temp.len) : (i += 1) {
                if (self.charAt(offset + i) != temp.charAt(i)) {
                    out = false;
                    break;
                }
            }
        }

        defer if (needsFreeing) temp.free();
        
        return out;
    }

    pub fn raw(self: *String) []u8 {
        return self.bytes.buffer.?[self.viewStart..self.viewEnd];
    }

    pub fn toString(self: *String) String {
        const buff = self.raw();
        var cloned = String.new(self.len);
        cloned.len = self.len;
        cloned.viewEnd = self.len;

        var i: u32 = 0;
        while (i < self.len) : (i += 1) {
            cloned.bytes.buffer.?[i] = buff[i];
        }

        return cloned;
    }
};

pub const Int = enum {
    var base10 = "0123456789";
    var base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var codeKey = "0123456789abcdefghijklmnopqrstuvwxyz";
    
    pub fn toString(num_: anytype, base: u32) String {
        switch (@typeInfo(@TypeOf(num_))) {
            .Int, .ComptimeInt => {
                const key = if (base == 10) Int.base10 else Int.codeKey;

                // calculate length
                const num = @as(u64, @intCast(Math.abs(num_)));
                var placeValues: u32 = 1;
                while (Math.pow(@as(u64, @intCast(base)), placeValues) < num + 1) {
                    placeValues += 1;
                }

                const negative = num_ < 0;
                var encoded = if (negative) String.new(placeValues + 1) else String.new(placeValues);
                encoded.bytes.len = encoded.bytes.capacity;
                encoded.viewEnd = encoded.bytes.capacity;
                encoded.len = encoded.bytes.capacity;
                
                var i = placeValues;
                var strIdx: u32 = 0;

                if (negative) {
                    encoded.setChar(0, '-');
                    strIdx = 1;
                }

                var f64num = @as(f64, @floatFromInt(num));
                while (i > 0) {
                    const factor: f64 = Math.pow(@as(f64, @floatFromInt(base)), @as(f64, @floatFromInt(i - 1)));
                    const digit = Math.floor(f64num / factor);
                    encoded.setChar(strIdx, key[@as(usize, @intFromFloat(digit))]);
                    strIdx += 1;
                    f64num -= digit * factor;
                    i -= 1;
                }

                return encoded;
            },
            else => @compileError("Int.toString only accepts integers")
        }
    }

    pub fn parse(data: anytype, base_: u32) i64 {
        var key = if (base_ == 10) String.newFrom(Int.base10) else String.newFrom(Int.codeKey);
        defer key.free();
        const base = @as(i64, @intCast(base_));

        var str: String = undefined;
        var createdString = false;
        switch (@TypeOf(data)) {
            // String
            String => {
                str = data;
            },
            // const string
            else => {
                str = String.newFrom(data);
                createdString = true;
            }
        }
    
        var num: i64 = 0;
        var i = @as(i32, @intCast(str.len - 1));
        var power: i64 = 0;
        while (i >= 0) : (i -= 1) {
            const ch = str.charAt(@as(u32, @bitCast(i)));
            var idx = key.indexOf(ch);
            if (idx == -1) {
                idx = key.indexOf(ch + 32);
            }
            // println(str.slice(@as(u32, @bitCast(i)), @as(u32, @bitCast(i)) + 1));
            // println(idx);
            num += @as(i64, @intCast(idx)) * Math.pow(base, power);
            power += 1;
        }
    
        defer if (createdString) str.free();

        return num;
    }
};

pub const Float = enum {
    var base10 = "0123456789";

    pub fn toString(num_: anytype, base: u32) String {
        if (Float.isNaN(num_)) {
            return String.newFrom("NaN");
        }

        switch (@typeInfo(@TypeOf(num_))) {
            .Float, .ComptimeFloat => {
                var num: f64 = @as(f64, @floatCast(num_));
                const negative = num < 0;
                num = Math.abs(num);
                const leading = @as(u32, @intFromFloat(num));
                const ten: f64 = 10;
                const six: f64 = 6;
                var f64Trailing = (num - @as(f64, @floatFromInt(leading))) * Math.pow(ten, six);
                var trailing = @as(u32, @intFromFloat(f64Trailing));
                f64Trailing = @as(f64, @floatFromInt(trailing));

                if (trailing > 0) {
                    while ((f64Trailing / 10) - Math.floor(f64Trailing / 10) == 0) {
                        f64Trailing /= 10.0;
                    }
                    trailing = @as(u32, @intFromFloat(f64Trailing));
                }

                var trailStr = Int.toString(trailing, base);
                defer trailStr.free();

                var temp = if (negative) String.newFrom("-") else String.new(0);
                var temp2 = Int.toString(leading, base);
                defer temp2.free();
                temp.concat(temp2);
                temp.concat('.');
                temp.concat(trailStr);
                return temp;
            },
            else => @compileError("Float.toString only accepts floats")
        }
    }

    pub fn toFixed(num: anytype, digits: u32) String {
        var out = Float.toString(num, 10);
        const dotIdx = out.indexOf(".");
        const digitCount = out.len - dotIdx;
        if (digitCount >= digits) {
            return out.slice(dotIdx, dotIdx + digits);
        } else {
            out.padEnd(digits, "0");
            return out;
        }
    }
    
    pub fn parse(data_: anytype, base: u32) f64 {
        var str: String = undefined;
        var createdString = false;
        switch (@TypeOf(data_)) {
            // String
            String => {
                str = data_;
            },
            // const string
            else => {
                str = String.newFrom(data_);
                createdString = true;
            }
        }
    
        const dotIdx = @as(u32, @bitCast(str.indexOf('.')));
        const front = str.slice(0, dotIdx);
        const back = str.slice(dotIdx + 1, 0);
        const frontNum = @as(f64, @floatFromInt(Int.parse(front, base)));
        const backNum = @as(f64, @floatFromInt(Int.parse(back, base)));
        const floatLen = @as(f64, @floatFromInt(back.len));
        const divider = Math.pow(@as(f64, 10.0), floatLen);

        defer if (createdString) str.free();

        return frontNum + (backNum / divider);
    }

    pub fn NaN(val: type) val {
        return std.math.nan(val);
    }

    pub fn isNaN(val: anytype) bool {
        return std.math.isNan(val);
    }
};
