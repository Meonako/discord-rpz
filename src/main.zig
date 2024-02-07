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

    var response = try client.setActivity(.{ .details = "Discord Rich Presence", .state = "Written in ZIG!", .assets = .{
        .large_image = "https://raw.githubusercontent.com/github/explore/b28ef5e65d2d582ab36c30e3e2068721e71625e4/topics/zig/zig.png",
        .large_text = "Zig Programming Language",
    } });
    allocator.free(response);

    _ = stdout.writeAll("First Presense set\n") catch {};

    var buffer: [2]u8 = undefined;
    // Pause
    _ = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch {};

    const temp = try client.clearActivity();
    allocator.free(temp);
    _ = stdout.writeAll("First Presense cleared\n") catch {};

    // Pause
    _ = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch {};

    var buttons = [1]ipc.Button{.{ .label = "Website", .url = "https://ziglang.org" }};

    response = try client.setActivity(.{ .details = "Discord Zich Presence", .state = "Try Zig out below!", .assets = .{
        .large_image = "https://raw.githubusercontent.com/github/explore/b28ef5e65d2d582ab36c30e3e2068721e71625e4/topics/zig/zig.png",
        .large_text = "Zig Programming Language",
    }, .buttons = &buttons });
    allocator.free(response);

    _ = stdout.writeAll("Second Presense set\n") catch {};

    _ = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch {};

    try client.close();
}
