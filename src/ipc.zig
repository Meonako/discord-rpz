const std = @import("std");
const uuid = @import("uuid.zig");

const u32_size = @sizeOf(u32);
const u32x2 = u32_size * 2;

extern fn GetCurrentProcessId() std.os.windows.DWORD;

const ipc_list = blk: {
    var list: [10]*const [22:0]u8 = undefined;
    for (0..10) |i| {
        list[i] = std.fmt.comptimePrint(
            \\\\?\pipe\discord-ipc-{d}
        , .{i});
    }
    break :blk list;
};

pub const Activity = struct { state: ?[]const u8 = null, details: ?[]const u8 = null, timestamps: ?struct {
    start: ?i64 = null,
    end: ?i64 = null,
} = null, party: ?struct {
    id: ?[]const u8 = null,
    size: ?[2]i32 = null,
} = null, assets: ?struct {
    large_image: ?[]const u8 = null,
    large_text: ?[]const u8 = null,
    small_image: ?[]const u8 = null,
    small_text: ?[]const u8 = null,
} = null, secrets: ?struct {
    join: ?[]const u8 = null,
    spectate: ?[]const u8 = null,
    match: ?[]const u8 = null,
} = null, buttons: ?[]struct {
    label: []const u8,
    url: []const u8,
} = null };

pub const Client = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8,
    connected: bool = false,
    socket: std.fs.File = undefined,

    const Self = @This();

    fn write(self: *Self, data: []u8, opcode: u8) !void {
        const header = pack(opcode, @intCast(data.len));

        _ = try self.socket.write(&header);
        _ = try self.socket.write(data);
    }

    fn read(self: *Self) !struct { op: u32, data: std.json.Parsed(std.json.Value) } {
        var buffer: [8]u8 = undefined;
        _ = try self.socket.read(&buffer);

        const result = unpack(buffer);

        const data = try self.allocator.alloc(u8, result.data_len);
        defer self.allocator.free(data);
        _ = try self.socket.read(data);

        std.debug.print("{s}\n", .{data});

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, data, .{});

        return .{ .op = result.opcode, .data = parsed };
    }

    fn connect_ipc(self: *Self) !void {
        for (ipc_list) |l| {
            const handle = std.fs.openFileAbsolute(l, .{ .mode = .read_write }) catch continue;
            self.socket = handle;
            std.debug.print("Connected to: {s}\n", .{l});
            return;
        }

        return error.IPCNotFound;
    }

    fn send_handshake(self: *Self) !void {
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\    "v": 1,
            \\    "client_id": "{s}"
            \\}}
        , .{self.client_id});
        std.debug.print("Login: {s}\n", .{body});
        defer self.allocator.free(body);

        _ = try self.write(body, 0);
        const temp = try self.read();
        std.debug.print("OP: {d}\n", .{temp.op});
        temp.data.deinit();
    }

    pub fn init(allocator: std.mem.Allocator, client_id: []const u8) !Self {
        var client = Self{ .allocator = allocator, .client_id = client_id };
        try client.connect_ipc();
        try client.send_handshake();
        return client;
    }

    pub fn setActivity(self: *Self, activity: Activity) !void {
        const act = try std.json.stringifyAlloc(self.allocator, activity, .{ .emit_null_optional_fields = false });
        defer self.allocator.free(act);

        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"cmd":"SET_ACTIVITY","args": {{"pid":{d},"activity":{s}}},"nonce":"{s}"}}
        , .{
            GetCurrentProcessId(),
            act,
            try uuid.uuidV4(),
        });
        defer self.allocator.free(body);

        std.debug.print("Sending: {s}\n", .{body});

        try self.write(body, 1);

        const temp = try self.read();
        temp.data.deinit();
    }
};

fn pack(opcode: u32, data_len: u32) [8]u8 {
    var op_buf: [4]u8 = undefined;
    var data_len_buf: [4]u8 = undefined;

    std.mem.writeInt(u32, &op_buf, opcode, .little);
    std.mem.writeInt(u32, &data_len_buf, data_len, .little);

    return op_buf ++ data_len_buf;
}

fn unpack(data: [8]u8) struct { opcode: u32, data_len: u32 } {
    const op_buf = data[0..4];
    const data_len_buf = data[4..8];

    const opcode = std.mem.readInt(u32, op_buf, .little);
    const data_len = std.mem.readInt(u32, data_len_buf, .little);

    return .{ .opcode = opcode, .data_len = data_len };
}
