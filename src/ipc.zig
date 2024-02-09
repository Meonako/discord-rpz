const std = @import("std");
const uuid = @import("uuid.zig");

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

pub const Timestamp = struct {
    start: ?i64 = null,
    end: ?i64 = null,
};

pub const Party = struct {
    id: ?[]const u8 = null,
    size: ?[2]i32 = null,
};

pub const Assets = struct {
    large_image: ?[]const u8 = null,
    large_text: ?[]const u8 = null,
    small_image: ?[]const u8 = null,
    small_text: ?[]const u8 = null,
};

pub const Secrets = struct {
    join: ?[]const u8 = null,
    spectate: ?[]const u8 = null,
    match: ?[]const u8 = null,
};

pub const Button = struct {
    label: []const u8,
    url: []const u8,
};

pub const Activity = struct { details: ?[]const u8 = null, state: ?[]const u8 = null, timestamps: ?Timestamp = null, party: ?Party = null, assets: ?Assets = null, secrets: ?Secrets = null, buttons: ?[]Button = null };

pub const Client = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8,
    connected: bool = false,
    socket: ?std.fs.File = null,

    const Self = @This();

    fn write(self: *Self, data: []const u8, opcode: u8) !void {
        // std.debug.print("Sending: {s}\n", .{data});
        const socket = self.socket orelse return error.Uninitialized;
        const header = buildHeader(opcode, @intCast(data.len));

        _ = try socket.write(&header);
        _ = try socket.write(data);
    }

    fn read(self: *Self) !struct { op: u32, data: []const u8 } {
        const socket = self.socket orelse return error.Uninitialized;
        var buffer: [8]u8 = undefined;
        _ = try socket.read(&buffer);

        const result = decodeHeader(buffer);

        const data = try self.allocator.alloc(u8, result.data_len);
        _ = try socket.read(data);

        // std.debug.print(
        //     \\------------------------------------
        //     \\{s}
        //     \\------------------------------------
        //     \\
        // , .{data});

        return .{ .op = result.opcode, .data = data };
    }

    pub fn close(self: *Self) !void {
        try self.write("{}", 2);

        // if `write` did not fail, socket is not null
        self.socket.?.close();
        self.socket = null;
    }

    fn connect_ipc(self: *Self) !void {
        for (ipc_list) |ipc| {
            const handle = std.fs.openFileAbsolute(ipc, .{ .mode = .read_write }) catch continue;
            self.socket = handle;
            // std.debug.print("Connected to: {s}\n", .{ipc});
            return;
        }

        return error.IPCNotFound;
    }

    fn sendHandshake(self: *Self) !void {
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"v":1,"client_id":"{s}"}}
        , .{self.client_id});
        // std.debug.print("Piped: {s}\n", .{body});
        defer self.allocator.free(body);

        _ = try self.write(body, 0);
        const temp = try self.read();
        self.allocator.free(temp.data);
    }

    fn reconnect(self: *Self) !void {
        try self.close();
        try self.connect_ipc();
        try self.sendHandshake();
    }

    pub fn init(allocator: std.mem.Allocator, client_id: []const u8) !Self {
        var client = Self{ .allocator = allocator, .client_id = client_id };
        try client.connect_ipc();
        try client.sendHandshake();
        return client;
    }

    /// Return Discord response in `JSON` format.
    /// > **Caller owns the returned memory and needs to free with init allocator**
    pub fn setActivity(self: *Self, activity: Activity) ![]const u8 {
        const act = try std.json.stringifyAlloc(self.allocator, activity, .{ .emit_null_optional_fields = false });
        defer self.allocator.free(act);

        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"cmd":"SET_ACTIVITY","args":{{"pid":{d},"activity":{s}}},"nonce":"{s}"}}
        , .{
            GetCurrentProcessId(),
            act,
            try uuid.uuidV4(),
        });
        defer self.allocator.free(body);

        try self.write(body, 1);

        const temp = try self.read();
        return temp.data;
    }

    /// Return Discord response in `JSON` format.
    /// > **Caller owns the returned memory and needs to free with init allocator**
    pub fn clearActivity(self: *Self) ![]const u8 {
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"cmd":"SET_ACTIVITY","args":{{"pid":{d}}},"nonce":"{s}"}}
        , .{ GetCurrentProcessId(), try uuid.uuidV4() });
        defer self.allocator.free(body);

        try self.write(body, 1);
        const temp = try self.read();
        return temp.data;
    }
};

fn buildHeader(opcode: u32, data_len: u32) [8]u8 {
    var op_buf: [4]u8 = undefined;
    var data_len_buf: [4]u8 = undefined;

    std.mem.writeInt(u32, &op_buf, opcode, .little);
    std.mem.writeInt(u32, &data_len_buf, data_len, .little);

    return op_buf ++ data_len_buf;
}

fn decodeHeader(data: [8]u8) struct { opcode: u32, data_len: u32 } {
    const op_buf = data[0..4];
    const data_len_buf = data[4..8];

    const opcode = std.mem.readInt(u32, op_buf, .little);
    const data_len = std.mem.readInt(u32, data_len_buf, .little);

    return .{ .opcode = opcode, .data_len = data_len };
}
