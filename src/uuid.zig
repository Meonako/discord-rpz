const std = @import("std");
const rand = std.crypto.random;

pub fn uuidV4() ![36]u8 {
    var uuid: [16]u8 = undefined;
    rand.bytes(&uuid);

    uuid[6] = (uuid[6] & 0x0F) | 0x40;
    uuid[8] = (uuid[8] & 0x3F) | 0x80;

    var str: [36]u8 = undefined;
    _ = try std.fmt.bufPrint(&str, "{x:0<2}{x:0<2}{x:0<2}{x:0<2}-{x:0<2}{x:0<2}-{x:0<2}{x:0<2}-{x:0<2}{x:0<2}-{x:0<2}{x:0<2}{x:0<2}{x:0<2}{x:0<2}{x:0<2}", .{
        uuid[0],
        uuid[1],
        uuid[2],
        uuid[3],
        uuid[4],
        uuid[5],
        uuid[6],
        uuid[7],
        uuid[8],
        uuid[9],
        uuid[10],
        uuid[11],
        uuid[12],
        uuid[13],
        uuid[14],
        uuid[15],
    });

    return str;
}
