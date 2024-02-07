const std = @import("std");
const ipc = @import("ipc.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var br = std.io.bufferedReader(std.io.getStdIn().reader());
    const stdin = br.reader();
    const stdout = std.io.getStdOut().writer();

    var client = try ipc.Client.init(allocator, "1002530808470446141");

    try client.setActivity(.{ .details = "Discord Rich Presence", .state = "Written in ZIG!", .assets = .{
        .large_image = "https://raw.githubusercontent.com/github/explore/b28ef5e65d2d582ab36c30e3e2068721e71625e4/topics/zig/zig.png",
        .large_text = "Zig Programming Language",
    } });

    _ = stdout.writeAll("First Presense set\n") catch {};

    var buffer: [2]u8 = undefined;
    // Pause
    _ = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch {};

    try client.clearActivity();
    _ = stdout.writeAll("First Presense cleared\n") catch {};

    // Pause
    _ = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch {};

    var buttons = [1]ipc.Button{.{ .label = "Website", .url = "https://ziglang.org" }};

    try client.setActivity(.{ .details = "Discord Zich Presence", .state = "Try Zig out below!", .assets = .{
        .large_image = "https://raw.githubusercontent.com/github/explore/b28ef5e65d2d582ab36c30e3e2068721e71625e4/topics/zig/zig.png",
        .large_text = "Zig Programming Language",
    }, .buttons = &buttons });

    _ = stdout.writeAll("Second Presense set\n") catch {};

    _ = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch {};

    try client.close();
}
