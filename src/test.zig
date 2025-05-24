const std = @import("std");
pub fn extract(gpa: std.mem.Allocator, T: type, items: []T, comptime field_name: []const u8) ![]@FieldType(T, field_name) {
    const result = try gpa.alloc(@FieldType(T, field_name), items.len);
    for (0..items.len) |i| {
        result[i] = @field(items[i], field_name);
    }
    return result;
}
