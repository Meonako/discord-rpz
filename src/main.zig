const std = @import("std");
const ipc = @import("ipc.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try ipc.Client.init(allocator, "1002530808470446141");

    try client.setActivity(.{ .details = "Discord Rich Presence", .state = "Written in ZIG!", .assets = .{
        .large_image = "https://raw.githubusercontent.com/github/explore/b28ef5e65d2d582ab36c30e3e2068721e71625e4/topics/zig/zig.png",
        .large_text = "Zig Programming Language",
    } });

    std.time.sleep(std.time.ns_per_s * 1000);
}
