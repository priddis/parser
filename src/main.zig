const std = @import("std");
const StringTable = @import("StringTable.zig");
const Tokenizer = @import("Tokenizer.zig");
const Parser = @import("Parser.zig");

var debug_allocator: std.heap.DebugAllocator(.{ .enable_memory_limit = true }) = .init;
pub fn main() !void {
    var gpa, _ = gpa: {
        break :gpa switch (@import("builtin").mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer std.debug.print("memory requested {d}", .{debug_allocator.total_requested_bytes});

    const project: []const u8 = "/var/home/mp/jdk/";
    var it = try std.fs.cwd().openDir(project, .{
        .iterate = true,
        .access_sub_paths = true,
        .no_follow = true,
    });
    defer it.close();
    var string_table = StringTable.init(gpa);

    //const tokens = try Tokenizer.tokenize(" a int long class\x00", &string_table, gpa);
    //for (tokens.items) |t| {
    //    std.debug.print("\n{s}", .{@tagName(t.type)});
    //}
    var walker = try it.walk(gpa);
    var buf = try gpa.alloc(u8, mb(10));
    defer gpa.free(buf);

    while (walker.next() catch @panic("Error walking")) |entry| {
        if (entry.kind == .file and
            entry.basename.len > 5 and
            std.mem.eql(u8, ".java", entry.basename[entry.basename.len - 5 ..]))
        {
            const source_file = try entry.dir.openFile(entry.basename, .{});
            defer source_file.close();

            const bytes_read = source_file.read(buf) catch std.debug.panic("Error reading {s}\n", .{entry.basename});
            buf[bytes_read] = 0;
            try Parser.parse(buf, &string_table, gpa);
            //for (tokens.items) |t| {
            //    std.debug.print("{s} ", .{@tagName(t.type)});
            //}
            //try split_tokenize(buf, &string_table);
        }
    }
}
pub fn mb(comptime bytes: usize) usize {
    return bytes * 1024 * 1024;
}

fn split_tokenize(buf: []const u8, string_table: *StringTable) !void {
    var spliterator = std.mem.splitScalar(u8, buf, ' ');
    while (spliterator.next()) |string| {
        _ = try string_table.put(string);
    }
}

test {
    std.testing.refAllDecls(@This());
}
