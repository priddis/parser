const std = @import("std");
const mem = std.mem;

string_bytes: std.ArrayListUnmanaged(u8),
/// Key is string_bytes index.
string_table: std.HashMapUnmanaged(u32, void, IndexContext, std.hash_map.default_max_load_percentage),
gpa: std.mem.Allocator,

const IndexContext = struct {
    string_bytes: *std.ArrayListUnmanaged(u8),

    pub fn eql(self: IndexContext, a: u32, b: u32) bool {
        _ = self;
        return a == b;
    }

    pub fn hash(self: IndexContext, x: u32) u64 {
        const cast: [*:0]const u8 = @ptrCast(self.string_bytes.items.ptr);
        const x_slice = mem.span(cast + x);
        return std.hash_map.hashString(x_slice);
    }
};

const SliceAdapter = struct {
    string_bytes: *std.ArrayListUnmanaged(u8),

    pub fn eql(self: SliceAdapter, a_slice: []const u8, b: u32) bool {
        const cast: [*:0]const u8 = @ptrCast(self.string_bytes.items.ptr);
        const b_slice = mem.span(cast + b);
        return mem.eql(u8, a_slice, b_slice);
    }

    pub fn hash(self: SliceAdapter, adapted_key: []const u8) u64 {
        _ = self;
        return std.hash_map.hashString(adapted_key);
    }
};
pub const StringHandle = struct {
    x: usize,

    pub fn equals(self: *const StringHandle, other: ?StringHandle) bool {
        return if (other) |o| self.x == o.x else false;
    }
};

pub fn init(gpa: std.mem.Allocator) @This() {
    return .{ .string_bytes = .{}, .string_table = .{}, .gpa = gpa };
}

pub fn toSlice(self: @This(), str: StringHandle) []const u8 {
    _ = self;
    _ = str;
    return &.{};
}

pub fn put(self: *@This(), string: []const u8) !StringHandle {
    if (self.get(string)) |handle| return handle;

    const index_context: IndexContext = .{ .string_bytes = &self.string_bytes };
    const index: u32 = @intCast(self.string_bytes.items.len);
    try self.string_bytes.appendSlice(self.gpa, string);
    try self.string_bytes.append(self.gpa, 0);
    try self.string_table.putContext(self.gpa, index, {}, index_context);
    return .{ .x = index };
}

pub fn get(self: *@This(), string: []const u8) ?StringHandle {
    // now we want to check if a string exists based on a string literal
    const slice_context: SliceAdapter = .{ .string_bytes = &self.string_bytes };
    const found_entry = self.string_table.getEntryAdapted(@as([]const u8, string), slice_context) orelse return null;
    return .{ .x = found_entry.key_ptr.* };
}
