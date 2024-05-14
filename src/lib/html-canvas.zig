const std = @import("std");

const vexlib = @import("vexlib.zig");
const println = vexlib.println;
const String = vexlib.String;
const Math = vexlib.Math;
const Int = vexlib.Int;
const Uint8Array = vexlib.Uint8Array;
const Int32Array = vexlib.Int32Array;
const Uint32Array = vexlib.Uint32Array;

const sdl = @cImport({
    @cInclude("./sdllib.h");
});

var sdlRunning: bool = true;

// SDL constants
const SDL_WINDOWPOS_CENTERED = 805240832;
const SDL_WINDOW_SHOWN = 4;
const SDL_WINDOW_BORDERLESS = 16;
const SDL_QUIT = 256;
const SDL_KEYDOWN = 768;

// export fn handleSDLEvent(eventType: i32, eventData: i32) void {
//     const KEY_ESCAPE = 27;

//     switch (eventType) {
//         SDL_QUIT => {
//             sdlRunning = false;
//         },
//         SDL_KEYDOWN => {
//             if (eventData == KEY_ESCAPE) {
//                 sdlRunning = false;
//             }
//         },
//         else => {}
//     }
// }

const pngCodec: ?*usize = null;
const jpegCodec: ?*usize = null;
const fontCodec: ?*usize = null;
const fonts: ?*usize = null;

pub const ImageData = struct {
    colorSpace: [:0]const u8,
    data: Uint8Array,
    width: u32,
    height: u32,

    // pub fn free(self: ImageData, allocator: std.mem.Allocator) void {
    //     allocator.free(self.data);
    // }
};

pub const CanvasError = error {
    InvalidArgs,
    NotImplemented,
};

fn getLineLineIntersect(x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, x4: i32, y4: i32) ?[2]i32 {
    // Check if none of the lines are of length 0
    if ((x1 == x2 and y1 == y2) or (x3 == x4 and y3 == y4)) {
        return null;
    }
    
    const a = y4 - y3;
    const b = x2 - x1;
    const c = x4 - x3;
    const d = y2 - y1;
    const e = y1 - y3;
    const f = x1 - x3;
    const denominator = (a * b - c * d);
    
    // Lines are parallel
    if (denominator == 0) {
        return null;
    }
    
    const denom = @as(f32, @floatFromInt(denominator));
    const ua = @as(f32, @floatFromInt(c * e - a * f)) / denom;
    const ub = @as(f32, @floatFromInt(b * e - d * f)) / denom;
    
    // is the intersection along the segments
    if (ua < 0.0 or ua > 1.0 or ub < 0.0 or ub > 1.0) {
        return null;
    }
    
    // Return a object with the x and y coordinates of the intersection
    return [_]i32{
        x1 + @as(i32, @intFromFloat(ua * @as(f32, @floatFromInt(b)))),
        y1 + @as(i32, @intFromFloat(ua * @as(f32, @floatFromInt(d))))
    };
}

fn point_triangleColl(px: i32, py: i32, tx1: i32, ty1: i32, tx2: i32, ty2: i32, tx3: i32, ty3: i32) bool {
    // Credit: Larry Serflaton
    const tx1_3 = tx1 - tx3;
    const tx3_2 = tx3 - tx2;
    const ty2_3 = ty2 - ty3;
    const ty3_1 = ty3 - ty1;
    const px_x3 = px - tx3;
    const py_y3 = py - ty3;
    const denom = @as(f32, @floatFromInt(ty2_3 * tx1_3 + tx3_2 * (ty1 - ty3)));
    const a = @as(f32, @floatFromInt(ty2_3 * px_x3 + tx3_2 * py_y3)) / denom;
    const b = @as(f32, @floatFromInt(ty3_1 * px_x3 + tx1_3 * py_y3)) / denom;
    const c = 1 - a - b;
    return a > 0 and b > 0 and c > 0 and c < 1 and b < 1 and a < 1;
}

const CSS_COLORS = [_][]const u8{
    "black","#000000",
    "silver","#C0C0C0",
    "gray","#808080",
    "white","#FFFFFF",
    "maroon","#800000",
    "red","#FF0000",
    "purple","#800080",
    "fuchsia","#FF00FF",
    "green","#008000",
    "lime","#00FF00",
    "olive","#808000",
    "yellow","#FFFF00",
    "navy","#000080",
    "blue","#0000FF",
    "teal","#008080",
    "aqua","#00FFFF",
    "aliceblue","#f0f8ff",
    "antiquewhite","#faebd7",
    "aqua","#00ffff",
    "aquamarine","#7fffd4",
    "azure","#f0ffff",
    "beige","#f5f5dc",
    "bisque","#ffe4c4",
    "black","#000000",
    "blanchedalmond","#ffebcd",
    "blue","#0000ff",
    "blueviolet","#8a2be2",
    "brown","#a52a2a",
    "burlywood","#deb887",
    "cadetblue","#5f9ea0",
    "chartreuse","#7fff00",
    "chocolate","#d2691e",
    "coral","#ff7f50",
    "cornflowerblue","#6495ed",
    "cornsilk","#fff8dc",
    "crimson","#dc143c",
    "cyan","#00ffff",
    "darkblue","#00008b",
    "darkcyan","#008b8b",
    "darkgoldenrod","#b8860b",
    "darkgray","#a9a9a9",
    "darkgreen","#006400",
    "darkgrey","#a9a9a9",
    "darkkhaki","#bdb76b",
    "darkmagenta","#8b008b",
    "darkolivegreen","#556b2f",
    "darkorange","#ff8c00",
    "darkorchid","#9932cc",
    "darkred","#8b0000",
    "darksalmon","#e9967a",
    "darkseagreen","#8fbc8f",
    "darkslateblue","#483d8b",
    "darkslategray","#2f4f4f",
    "darkslategrey","#2f4f4f",
    "darkturquoise","#00ced1",
    "darkviolet","#9400d3",
    "deeppink","#ff1493",
    "deepskyblue","#00bfff",
    "dimgray","#696969",
    "dimgrey","#696969",
    "dodgerblue","#1e90ff",
    "firebrick","#b22222",
    "floralwhite","#fffaf0",
    "forestgreen","#228b22",
    "fuchsia","#ff00ff",
    "gainsboro","#dcdcdc",
    "ghostwhite","#f8f8ff",
    "gold","#ffd700",
    "goldenrod","#daa520",
    "gray","#808080",
    "green","#008000",
    "greenyellow","#adff2f",
    "grey","#808080",
    "honeydew","#f0fff0",
    "hotpink","#ff69b4",
    "indianred","#cd5c5c",
    "indigo","#4b0082",
    "ivory","#fffff0",
    "khaki","#f0e68c",
    "lavender","#e6e6fa",
    "lavenderblush","#fff0f5",
    "lawngreen","#7cfc00",
    "lemonchiffon","#fffacd",
    "lightblue","#add8e6",
    "lightcoral","#f08080",
    "lightcyan","#e0ffff",
    "lightgoldenrodyellow","#fafad2",
    "lightgray","#d3d3d3",
    "lightgreen","#90ee90",
    "lightgrey","#d3d3d3",
    "lightpink","#ffb6c1",
    "lightsalmon","#ffa07a",
    "lightseagreen","#20b2aa",
    "lightskyblue","#87cefa",
    "lightslategray","#778899",
    "lightslategrey","#778899",
    "lightsteelblue","#b0c4de",
    "lightyellow","#ffffe0",
    "lime","#00ff00",
    "limegreen","#32cd32",
    "linen","#faf0e6",
    "magenta","#ff00ff",
    "maroon","#800000",
    "mediumaquamarine","#66cdaa",
    "mediumblue","#0000cd",
    "mediumorchid","#ba55d3",
    "mediumpurple","#9370db",
    "mediumseagreen","#3cb371",
    "mediumslateblue","#7b68ee",
    "mediumspringgreen","#00fa9a",
    "mediumturquoise","#48d1cc",
    "mediumvioletred","#c71585",
    "midnightblue","#191970",
    "mintcream","#f5fffa",
    "mistyrose","#ffe4e1",
    "moccasin","#ffe4b5",
    "navajowhite","#ffdead",
    "navy","#000080",
    "oldlace","#fdf5e6",
    "olive","#808000",
    "olivedrab","#6b8e23",
    "orange","#ffa500",
    "orangered","#ff4500",
    "orchid","#da70d6",
    "palegoldenrod","#eee8aa",
    "palegreen","#98fb98",
    "paleturquoise","#afeeee",
    "palevioletred","#db7093",
    "papayawhip","#ffefd5",
    "peachpuff","#ffdab9",
    "peru","#cd853f",
    "pink","#ffc0cb",
    "plum","#dda0dd",
    "powderblue","#b0e0e6",
    "purple","#800080",
    "red","#ff0000",
    "rosybrown","#bc8f8f",
    "royalblue","#4169e1",
    "saddlebrown","#8b4513",
    "salmon","#fa8072",
    "sandybrown","#f4a460",
    "seagreen","#2e8b57",
    "seashell","#fff5ee",
    "sienna","#a0522d",
    "silver","#c0c0c0",
    "skyblue","#87ceeb",
    "slateblue","#6a5acd",
    "slategray","#708090",
    "slategrey","#708090",
    "snow","#fffafa",
    "springgreen","#00ff7f",
    "steelblue","#4682b4",
    "tan","#d2b48c",
    "teal","#008080",
    "thistle","#d8bfd8",
    "tomato","#ff6347",
    "turquoise","#40e0d0",
    "violet","#ee82ee",
    "wheat","#f5deb3",
    "white","#ffffff",
    "whitesmoke","#f5f5f5",
    "yellow","#ffff00",
    "yellowgreen","#9acd32"
};

fn hexToRGBA(hex: String) [4]u8 {
    var str = hex;
    var i: u32 = 1;
    var bytes = [_]u8{0, 0, 0, 255};
    while (i < str.len) : (i += 2) {
        const s = str.slice(i, i + 2);
        bytes[(i - 1) / 2] = @as(u8, @truncate(@as(u64, @bitCast(Int.parse(s, 16)))));
    }
    return bytes;
}

pub fn rgb(r: u8, g: u8, b: u8) [4]u8 {
    return [_]u8{r, g, b, 255};
}
pub fn rgba(r: u8, g: u8, b: u8, a: u8) [4]u8 {
    return [_]u8{r, g, b, a};
}
pub fn color(str_: []const u8) [4]u8 {
    var rgbaVal = [_]u8{0, 0, 0, 255};
    var str = String.newFrom(str_);
    defer str.free();
    str.lowerCase();

    if (str.charAt(0) == '#') {
        return hexToRGBA(str);
    } else if (str.startsWith("rgb")) {
        var i: u32 = 0;
        var slc = str.slice(@as(u32, @bitCast(str.indexOf("("))) + 1, str.len - 1);
        var vals = slc.split(","); 
        defer vals.free();
        while (i < vals.len) : (i += 1) {
            var valSlc = vals.get(i);
            const byte = Int.parse(valSlc.trimStart(), 10);
            rgbaVal[i] = @as(u8, @truncate(@as(u64, @bitCast(byte))));
        }
        if (vals.len != 3) {
            rgbaVal[3] *= 255;
        }
        var temp = vals.toString();
        defer temp.free();
    } else {
        var i: u32 = 0;
        while (i < CSS_COLORS.len) : (i += 2) {
            if (str.equals(CSS_COLORS[i])) {
                var strNext = String.newFrom(CSS_COLORS[i + 1]);
                defer strNext.free();
                return hexToRGBA(strNext);
            }
        }
    }

    return rgbaVal;
}

fn blendClrs(
    r1_: u8, g1_: u8, b1_: u8, a1_: u8,
    r2_: u8, g2_: u8, b2_: u8, a2_: u8
) [4]u8{
    const r1 = @as(f32, @floatFromInt(r1_));
    const g1 = @as(f32, @floatFromInt(g1_));
    const b1 = @as(f32, @floatFromInt(b1_));
    const a1 = @as(f32, @floatFromInt(a1_));
    const r2 = @as(f32, @floatFromInt(r2_));
    const g2 = @as(f32, @floatFromInt(g2_));
    const b2 = @as(f32, @floatFromInt(b2_));
    const a2 = @as(f32, @floatFromInt(a2_));

    _=r1;
    _=g1;
    _=b1;
    _=a1;
    // _=r2;
    // _=g2;
    // _=b2;
    // _=a2;
    
    return [_]u8{
        @intFromFloat(r2),
        @intFromFloat(g2),
        @intFromFloat(b2),
        @intFromFloat(a2 / 2.0)
        // @intFromFloat((r1 + r2) / 2.0),
        // @intFromFloat((g1 + g2) / 2.0),
        // @intFromFloat((b1 + b2) / 2.0),
        // @intFromFloat((a1 + a2) / 2.0),
    };
    // return [_]u8{
    //     @as(u8, @intFromFloat((r1 * (255 - a2) + r2 * a2) / 255.0)),
    //     @as(u8, @intFromFloat((g1 * (255 - a2) + g2 * a2) / 255.0)),
    //     @as(u8, @intFromFloat((b1 * (255 - a2) + b2 * a2) / 255.0)),
    //     255 - @as(u8, @intFromFloat(((255 - a1) * (255 - a1) / 255)))
    // };
}

inline fn getBufferIdx(x: i32, y: i32, width: i32) u32 {
    return @as(u32, @intCast(x + y * width)) << 2;
}

inline fn renderPixel(
    dataBuffer: []u8, idx: u32,
    r: u8, g: u8, b: u8, a: u8
) void {
    var buff = dataBuffer;
    if (a == 255) {
        buff[idx] = r;
        buff[idx+1] = g;
        buff[idx+2] = b;
        // buff[idx+3] = a;
    } else {
        const nA = @as(u32, @intCast(a));
        const oR = @as(u32, @intCast(buff[idx])) * (255 - nA);
        const oG = @as(u32, @intCast(buff[idx+1])) * (255 - nA);
        const oB = @as(u32, @intCast(buff[idx+2])) * (255 - nA);
        
        const nR = @as(u32, @intCast(r)) * nA;
        const nG = @as(u32, @intCast(g)) * nA;
        const nB = @as(u32, @intCast(b)) * nA;

        buff[idx] = @as(u8, @truncate((oR + nR)));
        buff[idx+1] = @as(u8, @truncate((oG + nG)));
        buff[idx+2] = @as(u8, @truncate((oB + nB)));
        // buff[idx+3] = buff[idx+3] + a;
    }
}


fn renderLine(
    x1_: i32, y1_: i32, x2_: i32, y2_: i32, lineWidth: u32, lineCap: u8,
    imageData: ImageData, clr: [4]u8, antialiasing: bool
) void {
    var pix = imageData.data;
    const WIDTH = @as(i32, @intCast(imageData.width));

    const clrR: u8 = clr[0];
    const clrG: u8 = clr[1];
    const clrB: u8 = clr[2];
    const clrA: u8 = clr[3];

    if (lineWidth == 1) {
        if (antialiasing) {
            const fpart = struct {
                fn fpart(x: f32) f32 {
                    return x - Math.floor(x);
                }
            }.fpart;

            const rfpart = struct {
                fn rfpart(x: f32) f32 {
                    return 1 - fpart(x);
                }
            }.rfpart;

            var x1 = @as(f32, @floatFromInt(x1_));
            var y1 = @as(f32, @floatFromInt(y1_));
            var x2 = @as(f32, @floatFromInt(x2_));
            var y2 = @as(f32, @floatFromInt(y2_));
            
            // plot(x1, y1, 255, 0);
            // plot(x2, y2, 255, 0);

            const steep = Math.abs(y2 - y1) > Math.abs(x2 - x1);
            
            if (steep) {
                var temp = x1;
                x1 = y1;
                y1 = temp;
                temp = x2;
                x2 = y2;
                y2 = temp;
            }
            if (x1 > x2) {
                var temp = x1;
                x1 = x2;
                x2 = temp;
                temp = y1;
                y1 = y2;
                y2 = temp;
            }
            
            const dx = x2 - x1;
            const dy = y2 - y1;    
            const gradient: f32 = if (dx == 0.0) 1.0 else dy / dx;

            // handle first endpoint
            var xend = x1;
            var yend = y1 + gradient * (xend - x1);
            var xgap = rfpart(x1 + 0.5);
            const xpxl1 = xend; // this will be used in the main loop

            // first y-intersection for the main loop
            var intery = yend + gradient;

            // handle second endpoint
            xend = x2;
            yend = y2 + gradient * (xend - x2);
            xgap = fpart(x2 + 0.5);
            const xpxl2 = xend; // this will be used in the main loop

            if (steep) {
                var x = xpxl1;
                while (x <= xpxl2) : (x += 1) {
                    var idx = getBufferIdx(@as(i32, @intFromFloat(Math.floor(intery))), @as(i32, @intFromFloat(x)), WIDTH);
                    if (idx >= 0 and idx < pix.len - 3) {
                        const c = blendClrs(
                            pix.get(idx), pix.get(idx+1), pix.get(idx+2), pix.get(idx+3),
                            clrR, clrG, clrB, @as(u8, @intFromFloat(@as(f32, @floatFromInt(clrA)) * rfpart(intery))),
                        );
                        renderPixel(
                            pix.buffer.?, idx,
                            c[0], c[1], c[2], c[3]
                        );
                    }
                    

                    idx = getBufferIdx(@as(i32, @intFromFloat(Math.floor(intery))) - 1, @as(i32, @intFromFloat(x)), WIDTH);
                    if (idx >= 0 and idx < pix.len - 3) {
                        const c = blendClrs(
                            pix.get(idx), pix.get(idx+1), pix.get(idx+2), pix.get(idx+3),
                            clrR, clrG, clrB, @as(u8, @intFromFloat(@as(f32, @floatFromInt(clrA)) * fpart(intery))),
                        );
                        renderPixel(
                            pix.buffer.?, idx,
                            c[0], c[1], c[2], c[3]
                        );
                    }

                    intery = intery + gradient;
                }
            } else {
                var x = xpxl1;
                while (x <= xpxl2) : (x += 1) {
                    var idx = getBufferIdx(@as(i32, @intFromFloat(x)), @as(i32, @intFromFloat(Math.floor(intery))), WIDTH);
                    if (idx >= 0 and idx < pix.len - 3) {
                        const c = blendClrs(
                            pix.get(idx), pix.get(idx+1), pix.get(idx+2), pix.get(idx+3),
                            clrR, clrG, clrB, @as(u8, @intFromFloat(@as(f32, @floatFromInt(clrA)) * rfpart(intery))),
                        );
                        renderPixel(
                            pix.buffer.?, idx,
                            c[0], c[1], c[2], c[3]
                        );
                    }

                    idx = getBufferIdx(@as(i32, @intFromFloat(x)), @as(i32, @intFromFloat(Math.floor(intery))) - 1, WIDTH);
                    if (idx >= 0 and idx < pix.len - 3) {
                        const c = blendClrs(
                            pix.get(idx), pix.get(idx+1), pix.get(idx+2), pix.get(idx+3),
                            clrR, clrG, clrB, @as(u8, @intFromFloat(@as(f32, @floatFromInt(clrA)) * fpart(intery))),
                        );
                        renderPixel(
                            pix.buffer.?, idx,
                            c[0], c[1], c[2], c[3]
                        );
                    }

                    intery = intery + gradient;
                }
            }
        } else {
            // KCF's Bresenham Line Algorithm
            const dx = Math.abs(x2_ - x1_);
            const dy = Math.abs(y2_ - y1_);
            const sx: i32 = if (x1_ < x2_) 1 else -1;
            const sy: i32 = if (y1_ < y2_) 1 else -1;

            if (dy == 0) {
                var x = x1_;
                while (x != x2_ + sx) : (x += sx) {
                    const idx = @as(u32, @intCast((x + y1_ * WIDTH) << 2));
                    renderPixel(
                        pix.buffer.?, idx,
                        clrR, clrG, clrB, clrA
                    );
                }
            } else if (dx == 0) {
                var y = y1_;
                while (y != y2_ + sy) : (y += sy) {
                    const idx = @as(u32, @intCast((x1_ + y * WIDTH) << 2));
                    renderPixel(
                        pix.buffer.?, idx,
                        clrR, clrG, clrB, clrA
                    );
                }
            } else {
                var err = dx - dy;

                var xx = x1_;
                var yy = y1_;
                
                while (true) {
                    if (xx >= 0 and xx < WIDTH) {
                        const idx = @as(u32, @intCast((xx + yy * WIDTH) << 2));
                        renderPixel(
                            pix.buffer.?, idx,
                            clrR, clrG, clrB, clrA
                        );
                    }

                    if (xx == x2_ and yy == y2_) {
                        break;
                    }

                    const e2 = 2 * err;
                    if (e2 > -dy) {
                        err -= dy;
                        xx += sx;
                    }
                    if (e2 < dx) {
                        err += dx;
                        yy += sy;
                    }
                }
            }
        }
    } else {
        const dx = x1_ - x2_;
        const dy = y1_ - y2_;
        const len = @as(i32, @bitCast(Math.sqrt(@as(u32, @bitCast(dx * dx + dy * dy)))));
        const halfSW = @as(i32, @bitCast(lineWidth / 2));
        const xo = @divTrunc(y1_ - y2_, len * halfSW);
        const yo = @divTrunc(x1_ - x2_, len * halfSW);

        // const xo = @as(f32, @floatFromInt(y1_ - y2_)) / @as(f32, @floatFromInt(len * halfSW));
        // const yo = @as(f32, @floatFromInt(x1_ - x2_)) / @as(f32, @floatFromInt(len * halfSW));

        // _=dx;
        // _=dy;
        // _=len;
        // _=halfSW;
        // _=xo;
        // _=yo;
        
        // check if lineCap is butt or round
        if (lineCap == 'b' or lineCap == 'r') {
            println("RENDERER");
            // println(x1_ + xo);
            // println(y1_ - yo);
            // println(x2_ + xo);
            // println(y2_ - yo);
            // println(x2_ - xo);
            // println(y2_ + yo);
            // renderTriangle(
            //     x1_ + xo, y1_ - yo, x2_ + xo, y2_ - yo, x2_ - xo, y2_ + yo,
            //     imageData, clr
            // );
            // renderTriangle(
            //     x1_ + xo, y1_ - yo, x2_ - xo, y2_ + yo, x1_ - xo, y1_ + yo,
            //     imageData, clr
            // );
            renderTriangle(
                x1_ + xo, y1_ - yo,
                x2_ + xo, y2_ - yo,
                x1_ - xo, y1_ + yo,
                imageData, clr
            );
            // renderPolygon(
            //     [
            //         x1 + xo, y1 - yo,
            //         x2 + xo, y2 - yo,
            //         x2 - xo, y2 + yo,
            //         x1 - xo, y1 + yo
            //     ],
            //     imgData,
            //     clr
            // );
            renderQuad(
                x1_ + xo, y1_ - yo,
                x2_ + xo, y2_ - yo,
                x2_ - xo, y2_ + yo,
                x1_ - xo, y1_ + yo,
                imageData, clr
            );
            
            // if (lineCap === "round") {
                const diam = @as(i32, @bitCast(lineWidth));
                renderEllipse(x1_, y1_, diam, diam, imageData, clr);
                renderEllipse(x2_, y2_, diam, diam, imageData, clr);
            // }
        } else if (lineCap == 's') { // lineCap is square
            // let dir = Math.atan2(y2 - y1, x2 - x1),
            //     xShift = cos(dir) * halfSW,
            //     yShift = sin(dir) * halfSW;
            
            // renderPolygon(
            //     [
            //         x1 + xo - xShift, y1 - yo - yShift,
            //         x2 + xo + xShift, y2 - yo + yShift,
            //         x2 - xo + xShift, y2 + yo + yShift,
            //         x1 - xo - xShift, y1 + yo - yShift
            //     ],
            //     imgData,
            //     clr
            // );
        }
    }

    
}


fn renderTriangle(
    x1_: i32, y1_: i32, x2_: i32, y2_: i32, x3_: i32, y3_: i32, 
    imageData: ImageData, clr: [4]u8
) void {
    const pix = imageData.data;
    const WIDTH = @as(i32, @intCast(imageData.width));
    const HEIGHT = @as(i32, @intCast(imageData.height));

    const clrR: u8 = clr[0];
    const clrG: u8 = clr[1];
    const clrB: u8 = clr[2];
    const clrA: u8 = clr[3];

    const minx = @max(0, @min(x1_, x2_, x3_));
    const maxx = @min(WIDTH, @max(x1_, x2_, x3_));
    const miny = @max(0, @min(y1_, y2_, y3_));
    const maxy = @min(HEIGHT, @max(y1_, y2_, y3_));

    var xx = minx;
    while (xx < maxx) : (xx += 1) {
        var yy = miny;
        while (yy < maxy) : (yy += 1) {
            const w1 = @as(f32, @floatFromInt(x1_ * (y3_ - y1_) + (yy - y1_) * (x3_ - x1_) - xx * (y3_ - y1_))) / @as(f32, @floatFromInt((y2_ - y1_) * (x3_ - x1_) - (x2_ - x1_) * (y3_ - y1_)));
            const w2 = @as(f32, @floatFromInt(x1_ * (y2_ - y1_) + (yy - y1_) * (x2_ - x1_) - xx * (y2_ - y1_))) / @as(f32, @floatFromInt((y3_ - y1_) * (x2_ - x1_) - (x3_ - x1_) * (y2_ - y1_)));

            if (w1 >= 0 and w2 >= 0 and w1 + w2 <= 1) {
                const idx = @as(u32, @intCast(xx + yy * WIDTH)) << 2;
                renderPixel(
                    pix.buffer.?, idx,
                    clrR, clrG, clrB, clrA
                );
            }
        }
    }
}

fn renderStrokeTriangle(
    x1_: i32, y1_: i32, x2_: i32, y2_: i32, x3_: i32, y3_: i32, lineWidth: u32,
    imageData: ImageData, clr: [4]u8, antialiasing: bool
) void {
    renderLine(
        x1_, y1_, x2_, y2_, lineWidth, 'b',
        imageData, clr, antialiasing
    );

    renderLine(
        x2_, y2_, x3_, y3_, lineWidth, 'b',
        imageData, clr, antialiasing
    );

    renderLine(
        x3_, y3_, x1_, y1_, lineWidth, 'b',
        imageData, clr, antialiasing
    );
}


fn renderRectangle(
    x_: i32, y_: i32, w_: i32, h_: i32,
    imageData: ImageData, clr: [4]u8
) void {
    const pix = imageData.data;
    const WIDTH = @as(i32, @intCast(imageData.width));
    const HEIGHT = @as(i32, @intCast(imageData.height));

    const clrR: u8 = clr[0];
    const clrG: u8 = clr[1];
    const clrB: u8 = clr[2];
    const clrA: u8 = clr[3];

    const xStart: i32 = @max(x_, 0);
    const yStart: i32 = @max(y_, 0);
    const xStop: i32 = @min(x_ + w_, WIDTH);
    const yStop: i32 = @min(y_ + h_, HEIGHT);

    var yy: i32 = yStart;
    while (yy < yStop) : (yy += 1) {
        var xx: i32 = xStart;
        var idx = @as(u32, @intCast(xx + yy * WIDTH)) << 2;
        while (xx < xStop) : (xx += 1) {
            renderPixel(
                pix.buffer.?, idx,
                clrR, clrG, clrB, clrA
            );
            idx += 4;
        }
    }
}

fn renderStrokeRectangle(
    x_: i32, y_: i32, w_: i32, h_: i32, lineWidth: u32,
    imageData: ImageData, clr: [4]u8, antialiasing: bool
) void {
    renderLine(
        x_-10, y_, x_ + w_, y_, lineWidth, 'b',
        imageData, clr, antialiasing
    );

    renderLine(
        x_ + w_, y_, x_ + w_, y_ + h_, lineWidth, 'b',
        imageData, clr, antialiasing
    );

    renderLine(
        x_, y_ + h_, x_ + w_, y_ + h_, lineWidth, 'b',
        imageData, clr, antialiasing
    );

    renderLine(
        x_, y_, x_, y_ + h_, lineWidth, 'b',
        imageData, clr, antialiasing
    );
}


fn renderQuad(
    x1_: i32, y1_: i32, x2_: i32, y2_: i32, x3_: i32, y3_: i32, x4_: i32, y4_: i32,
    imageData: ImageData, clr: [4]u8
) void {
    const det = @as(f32, @floatFromInt((x3_ - x1_) * (y4_ - y2_) - (x4_ - x2_) * (y3_ - y2_)));
    var touching: bool = undefined;
    if (det == 0) {
        touching = false;
    } else {
        const lambda = @as(f32, @floatFromInt((y4_ - y2_) * (x4_ - x1_) + (x2_ - x4_) * (y4_ - y2_))) / det;
        const gamma = @as(f32, @floatFromInt((y2_ - y3_) * (x4_ - x1_) + (x3_ - x1_) * (y4_ - y2_))) / det;
        touching = (0.0 < lambda and lambda < 1.0) and (0.0 < gamma and gamma < 1.0);
    }

    var typeId: u32 = undefined;
    var cavePt: u32 = undefined;
    if (touching) {
        typeId = 1;
    } else {
        typeId = 2;

        if (point_triangleColl(x1_, y1_, x2_, y2_, x3_, y3_, x4_, y4_)) {
            cavePt = 0;
        } else if (point_triangleColl(x2_, y2_, x3_, y3_, x4_, y4_, x1_, y1_)) {
            cavePt = 1;
        } else if (point_triangleColl(x3_, y3_, x4_, y4_, x1_, y1_, x2_, y2_)) {
            cavePt = 2;
        } else if (point_triangleColl(x4_, y4_, x1_, y1_, x2_, y2_, x3_, y3_)) {
            cavePt = 3;
        } else {
            typeId = 3;
        }
    }

    var tri1: [6]i32 = undefined;
    var tri2: [6]i32 = undefined;
    switch (typeId) {
        1 => {
            tri1 = [_]i32{x1_, y1_, x2_, y2_, x3_, y3_};
            tri2 = [_]i32{x1_, y1_, x3_, y3_, x4_, y4_};
        },
        2 => {
            var oppositePt = cavePt + 2;
            if (oppositePt > 3) {
                oppositePt %= 4;
            }

            var pts = Uint32Array.new(4);
            defer pts.free();
            pts.append(0);
            pts.append(1);
            pts.append(2);
            pts.append(3);
            pts.remove(@as(u32, @bitCast(pts.indexOf(cavePt))), 1);
            pts.remove(@as(u32, @bitCast(pts.indexOf(oppositePt))), 1);

            const vals = [4][2]i32{
                [2]i32{x1_, y1_},
                [2]i32{x2_, y2_},
                [2]i32{x3_, y3_},
                [2]i32{x4_, y4_}
            };

            tri1 = [_]i32{vals[pts.get(0)][0], vals[pts.get(0)][1], vals[cavePt][0], vals[cavePt][1], vals[oppositePt][0], vals[oppositePt][1]};
            tri2 = [_]i32{vals[pts.get(1)][0], vals[pts.get(1)][1], vals[cavePt][0], vals[cavePt][1], vals[oppositePt][0], vals[oppositePt][1]};
        },
        3 => {
            var intersectOrNull = getLineLineIntersect(x1_, y1_, x2_, y2_, x3_, y3_, x4_, y4_);
            if (intersectOrNull) |intersect| {
                tri1 = [_]i32{intersect[0], intersect[1], x2_, y2_, x3_, y3_};
                tri2 = [_]i32{intersect[0], intersect[1], x1_, y1_, x4_, y4_};
            } else {
                intersectOrNull = getLineLineIntersect(x1_, y1_, x4_, y4_, x2_, y2_, x3_, y3_);
                if (intersectOrNull) |intersect| {
                    tri1 = [_]i32{intersect[0], intersect[1], x1_, y1_, x2_, y2_};
                    tri2 = [_]i32{intersect[0], intersect[1], x3_, y3_, x4_, y4_};
                }
            }
        },
        else => unreachable
    }

    renderTriangle(tri1[0], tri1[1], tri1[2], tri1[3], tri1[4], tri1[5], imageData, clr);
    renderTriangle(tri2[0], tri2[1], tri2[2], tri2[3], tri2[4], tri2[5], imageData, clr);

    // if (stroke && stroke[3] > 0 && strokeWeight) {
    //     renderLine(x1, y1, x2, y2, imgData, stroke, strokeWeight, "round");
    //     renderLine(x2, y2, x3, y3, imgData, stroke, strokeWeight, "round");
    //     renderLine(x3, y3, x4, y4, imgData, stroke, strokeWeight, "round");
    //     renderLine(x4, y4, x1, y1, imgData, stroke, strokeWeight, "round");
    // }
}


fn renderEllipse(
    x_: i32, y_: i32, w_: i32, h_: i32,
    imageData: ImageData, clr: [4]u8
) void {
    var n = w_;
    const w2 = w_ * w_;
    const h2 = h_ * h_;

    const pix = imageData.data;
    const WIDTH = @as(i32, @intCast(imageData.width));
    // const HEIGHT = @as(i32, @intCast(imageData.height));

    const clrR: u8 = clr[0];
    const clrG: u8 = clr[1];
    const clrB: u8 = clr[2];
    const clrA: u8 = clr[3];

    var xStop = Math.min(x_ + w_, WIDTH);
    {
        var i = Math.max(x_ - w_, 0);
        while (i < xStop) : (i += 1) {
            if (i >= 0 and i < WIDTH) {
                const idx = @as(u32, @intCast(i + y_ * WIDTH)) << 2;
                renderPixel(
                    pix.buffer.?, idx,
                    clrR, clrG, clrB, clrA
                );
            }
        }
    }

    var j: i32 = 1;
    while (j < h_) : (j += 1) {
        const ra = y_ + j;
        const rb = y_ - j;

        while (w2 * (h2 - j * j) < h2 * n * n and n != 0) {
            n -= 1;
        }

        xStop = Math.min(x_ + n, WIDTH);
        var i = Math.max(x_ - n, 0);
        while (i < xStop) : (i += 1) {
            if (i >= 0 and i < WIDTH) {
                var idx = @as(u32, @intCast(i + ra * WIDTH)) << 2;
                renderPixel(
                    pix.buffer.?, idx,
                    clrR, clrG, clrB, clrA
                );
    
                idx = @as(u32, @intCast(i + rb * WIDTH)) << 2;
                renderPixel(
                    pix.buffer.?, idx,
                    clrR, clrG, clrB, clrA
                );
            }
        }
    }
}

const PathCommand = enum(u8) {
    arc,
    arcTo,
    beginPath,
    bezierCurveTo,
    closePath,
    ellipse,
    fill,
    lineTo,
    moveTo,
    quadraticCurveTo,
    rect,
    roundRect,
    stroke,
};

pub const Path2D = struct {
    commands: Uint8Array,
    args: Int32Array,

    pub fn new() Path2D {
        const arr8 = Uint8Array.new(1000);
        const arr32 = Int32Array.new(1000);
        return Path2D {
            .commands = arr8,
            .args = arr32,
        };
    }
};

pub const RenderingContext2D = struct {
    imageData: ImageData,
    fillStyle: [4]u8,
    strokeStyle: [4]u8,
    lineWidth: u32,
    matrices: []usize,
    pen: [2]i32,
    path: Path2D,
    canvas: *Canvas,
    direction: [:0]const u8,
    filter: [:0]const u8,
    font: [:0]const u8,
    fontKerning: [:0]const u8,
    globalAlpha: f32,
    globalCompositeOperation: [:0]const u8,
    imageSmoothingEnabled: bool,
    imageSmoothingQuality: [:0]const u8,
    lineCap: [:0]const u8,
    lineDashOffset: u32,
    lineJoin: [:0]const u8,
    miterLimit: u32,
    shadowBlur: f32,
    shadowColor: [:0]const u8,
    shadowOffsetX: u32,
    shadowOffsetY: u32,
    textAlign: [:0]const u8,
    textBaseline: [:0]const u8,

    pub fn new(canvas_: Canvas, contextAttributes: anytype) RenderingContext2D {
        _=contextAttributes;
        var canvas = canvas_;    
    
        var pixels = Uint8Array.new(canvas.width * canvas.height * 4);
        pixels.fill(0, -1);
        const imgData = ImageData {
            .colorSpace = "srgb",
            .data = pixels,
            .width = canvas.width,
            .height = canvas.height
        };

        const canvasPtr: *Canvas = &canvas;
        const path = Path2D.new();

        return RenderingContext2D {
            .imageData = imgData,
            .fillStyle = [_]u8{0, 0, 0, 255},
            .strokeStyle = [_]u8{0, 0, 0, 255},
            .lineWidth = 1,
            .matrices = &[_]usize{},
            .pen = [_]i32{0, 0},
            .path = path,
            .canvas = canvasPtr,
            .direction = "ltr",
            .filter = "none",
            .font = "10px sans-serif",
            .fontKerning = "auto",
            .globalAlpha = 1,
            .globalCompositeOperation = "source-over",
            .imageSmoothingEnabled = true,
            .imageSmoothingQuality = "low",
            .lineCap = "butt", // hehe
            .lineDashOffset = 0,
            .lineJoin = "miter",
            .miterLimit = 10,
            .shadowBlur = 0,
            .shadowColor = "rgba(0,0,0,0)",
            .shadowOffsetX = 0,
            .shadowOffsetY = 0,
            .textAlign = "start",
            .textBaseline = "alphabetic",
        };
    }

    pub fn free(self: *RenderingContext2D) void {
        self.imageData.data.free();
        self.path.commands.free();
        self.path.args.free();
    }

    pub fn beginPath(self: *RenderingContext2D) void {
        self.path.commands.len = 0;
        self.path.args.len = 0;
    }

    pub fn moveTo(self: *RenderingContext2D, x: i32, y: i32) void {
        self.pen[0] = x;
        self.pen[1] = y;

        self.path.commands.append(@intFromEnum(PathCommand.moveTo));
        self.path.args.append(x);
        self.path.args.append(y);
    }

    pub fn lineTo(self: *RenderingContext2D, x: i32, y: i32) void {
        self.path.commands.append(@intFromEnum(PathCommand.lineTo));
        self.path.args.append(x);
        self.path.args.append(y);
    }

    pub fn quadraticCurveTo(self: *RenderingContext2D, cp1x: i32, cp1y: i32, x: i32, y: i32) void {
        self.path.commands.append(@intFromEnum(PathCommand.quadraticCurveTo));
        self.path.args.append(cp1x);
        self.path.args.append(cp1y);
        self.path.args.append(x);
        self.path.args.append(y);
    }

    pub fn bezierCurveTo(self: *RenderingContext2D, cp1x: i32, cp1y: i32, cp2x: i32, cp2y: i32, x: i32, y: i32) void {
        self.path.commands.append(@intFromEnum(PathCommand.bezierCurveTo));
        self.path.args.append(cp1x);
        self.path.args.append(cp1y);
        self.path.args.append(cp2x);
        self.path.args.append(cp2y);
        self.path.args.append(x);
        self.path.args.append(y);
    }

    pub fn arc(self: *RenderingContext2D, x: i32, y: i32, radius: i32, startAngle_: f32, endAngle_: f32, counterclockwise: bool) void {
        var startAngle = startAngle_;
        var endAngle = endAngle_;
        const f32PI = @as(f32, @floatCast(Math.PI));

        self.path.commands.append(@intFromEnum(PathCommand.arc));

        if (startAngle > endAngle) {
            endAngle += f32PI * 2.0;
        }

        // var step = f32PI / 16.0;
        if (counterclockwise) {
            const temp = endAngle;
            endAngle = startAngle + f32PI * 2.0;
            startAngle = temp;
        }

        self.path.args.append(x);
        self.path.args.append(y);
        self.path.args.append(radius);
        self.path.args.append(@bitCast(startAngle));
        self.path.args.append(@bitCast(endAngle));
    }

    pub fn closePath(self: *RenderingContext2D) void {
        const x = self.path.args.get(0);
        const y = self.path.args.get(1);
        self.path.commands.append(@intFromEnum(PathCommand.lineTo));
        self.path.args.append(self.pen[0]);
        self.path.args.append(self.pen[1]);
        self.path.args.append(x);
        self.path.args.append(y);
        self.pen[0] = x;
        self.pen[1] = y;
    }

    pub fn fill(self: *RenderingContext2D) void {
        var commands = self.path.commands;
        var args = self.path.args;
        
        var cmdIdx: u32 = 0;
        var argIdx: u32 = 0;
        var idk: i32 = 0;
        var currX: i32 = 0;
        var currY: i32 = 0;
        var curr2X: i32 = 0;
        var curr2Y: i32 = 0;
        while (cmdIdx < commands.len) : (cmdIdx += 1) {
            switch (commands.get(cmdIdx)) {
                @intFromEnum(PathCommand.moveTo) => {
                    currX = args.get(argIdx);
                    currY = args.get(argIdx+1);
                    argIdx += 2;
                },
                @intFromEnum(PathCommand.lineTo) => {
                    const x = args.get(argIdx);
                    const y = args.get(argIdx+1);

                    if (idk == 0) {
                        currX = x;
                        currY = y;
                        idk += 1;
                    } else if (idk == 1) {
                        curr2X = x;
                        curr2Y = y;
                        idk += 1;
                    } else {
                        renderTriangle(
                            currX, currY, curr2X, curr2Y, x, y, 
                            self.imageData, self.fillStyle
                        );
                        currX = x;
                        currY = y;
                        idk = 1;
                    }
                    
                    argIdx += 2;
                },
                @intFromEnum(PathCommand.arc) => {
                    // var x = args.get(argIdx); 
                    // var y = args.get(argIdx+1);
                    // var radius = args.get(argIdx+2);
                    // var startAngle = args.get(argIdx+3);
                    // var endAngle = args.get(argIdx+4);

                    // const f32Radius = @as(f32, @floatFromInt(radius));
                    
                    // self.moveTo(
                    //     @as(i32, @intFromFloat(x + Math.cos(startAngle) * f32Radius)),
                    //     @as(i32, @intFromFloat(y + Math.sin(startAngle) * f32Radius))
                    // );
                    // while (startAngle <= endAngle) : (startAngle += step) {
                    //     self.lineTo(
                    //         @as(i32, @intFromFloat(x + Math.cos(startAngle) * f32Radius)),
                    //         @as(i32, @intFromFloat(y + Math.sin(startAngle) * f32Radius))
                    //     );
                    // }
                    // self.lineTo(
                    //     @as(i32, @intFromFloat(x + Math.cos(endAngle) * f32Radius)),
                    //     @as(i32, @intFromFloat(y + Math.sin(endAngle) * f32Radius))
                    // );

                    // argIdx += 5;
                },
                else => unreachable
            }
        }
    }

    pub fn stroke(self: *RenderingContext2D) void {
        var commands = self.path.commands;
        var args = self.path.args;
        
        var cmdIdx: u32 = 0;
        var argIdx: u32 = 0;
        var currX: i32 = 0;
        var currY: i32 = 0;
        while (cmdIdx < commands.len) : (cmdIdx += 1) {
            switch (commands.get(cmdIdx)) {
                @intFromEnum(PathCommand.moveTo) => {
                    currX = args.get(argIdx);
                    currY = args.get(argIdx+1);
                    argIdx += 2;
                },
                @intFromEnum(PathCommand.lineTo) => {
                    const x = args.get(argIdx);
                    const y = args.get(argIdx+1);
                    renderLine(
                        currX, currY, x, y, self.lineWidth, self.lineCap[0],
                        self.imageData, self.strokeStyle, self.imageSmoothingEnabled
                    );
                    currX = x;
                    currY = y;
                    argIdx += 2;
                },
                else => unreachable
            }
        }
    }

    pub fn clearRect(self: *RenderingContext2D, x_: i32, y_: i32, width: i32, height: i32) void {
        var imgData = self.imageData;
        var x: u32 = x_;
        while (x < x_ + width) : (x += 1) {
            var y: u32 = y_;
            while (y < y_ + height) : (y += 1) {
                const idx = (x + y * imgData.width) << 2;
                imgData.data.set(idx, 0);
                imgData.data.set(idx+1, 0);
                imgData.data.set(idx+2, 0);
                imgData.data.set(idx+3, 0);
            }
        }
    }

    pub fn fillRect(self: *RenderingContext2D, x: i32, y: i32, w: i32, h: i32) void {
        renderRectangle(
            x, y, w, h,
            self.imageData, self.fillStyle
        );
    }
    
    pub fn strokeRect(self: *RenderingContext2D, x: i32, y: i32, w: i32, h: i32) void {
        renderStrokeRectangle(
            x, y, w, h, self.lineWidth,
            self.imageData, self.strokeStyle, self.imageSmoothingEnabled
        );
    }
};

pub const Canvas = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    context: ?RenderingContext2D,

    pub fn new(allocator_: std.mem.Allocator, width: u32, height: u32) Canvas {
        const allocator = allocator_;
        return Canvas {
            .allocator = allocator,
            .width = width,
            .height = height,
            .context = null
        };
    }

    pub fn free(self: *Canvas) void {
        var ctx = self.context.?;
        ctx.free();
    }

    pub fn getContext(self: *Canvas, contextType: [:0]const u8, contextAttributes: anytype) CanvasError!?RenderingContext2D {
        if (std.mem.eql(u8, contextType, "2d")) {
            if (self.context == null) {
                self.context = RenderingContext2D.new(self.*, contextAttributes);
            }
            return self.context;
        } else if (std.mem.eql(u8, contextType, "webgl") or std.mem.eql(u8, contextType, "webgl")) {
            return CanvasError.NotImplemented;
        } else if (std.mem.eql(u8, contextType, "webgl2")) {
            return CanvasError.NotImplemented;
        } else if (std.mem.eql(u8, contextType, "webgpu")) {
            return CanvasError.NotImplemented;
        } else {
            return CanvasError.InvalidArgs;
        }
    }

    pub fn toBlob(self: *Canvas, format: [:0]const u8, quality: f64) CanvasError {
        _=self;
        _=format;
        _=quality;
        // const imgData = this.#context.__getImageData__();
            
        // type = type.toLowerCase();

        // let rawData;
        // switch (type) {
        //     case "image/jpg": case "image/jpeg":  case "image/jfif":
        //         rawData = VCanvas.globals.JPEG.encode(imgData, quality * 100);
        //         break;
        //     case "image/png": default:
        //         rawData = VCanvas.globals.PNG.encode(imgData);
        //         break;
        // }

        // let binStr = "";
        // for (let i = 0; i < rawData.length; i++) {
        //     binStr += String.fromCharCode(rawData[i]);
        // }

        // return new VCanvasBlob(binStr);

        return CanvasError.NotImplemented;
    }
    
    pub fn toDataURL(self: *Canvas, format: [:0]const u8, quality: f64) CanvasError {
        _=self;
        _=format;
        _=quality;
        // const imgData = this.#context.__getImageData__();
        
        // type = type.toLowerCase();

        // let rawData;
        // switch (type) {
        //     case "image/jpg": case "image/jpeg":  case "image/jfif":
        //         rawData = VCanvas.globals.JPEG.encode(imgData, quality * 100);
        //         break;
        //     case "image/png": default:
        //         rawData = VCanvas.globals.PNG.encode(imgData);
        //         break;
        // }

        // let binStr = "";
        // for (let i = 0; i < rawData.length; i++) {
        //     binStr += String.fromCharCode(rawData[i]);
        // }

        // return "data:" + type + ";base64," + Base64.btoa(binStr);
        
        return CanvasError.NotImplemented;
    }

    pub fn captureStream(self: *Canvas) CanvasError {
        _=self;
        return CanvasError.NotImplemented;
    }

    pub fn transferControlToOffScreen(self: *Canvas) CanvasError {
        _=self;
        return CanvasError.NotImplemented;
    }
};

