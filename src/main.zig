const std = @import("std");
const StringTable = @import("StringTable.zig");
const Tokenizer = @import("Tokenizer.zig");

var debug_allocator: std.heap.DebugAllocator(.{ .enable_memory_limit = true }) = .init;
pub fn main() !void {
    const gpa, _ = gpa: {
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

    const tokens = try Tokenizer.tokenize(" a int long class\x00", &string_table, gpa);
    for (tokens.items) |t| {
        std.debug.print("\n{s}", .{@tagName(t.type)});
    }
    //var walker = try it.walk(gpa);
    //while (walker.next() catch @panic("Error walking")) |entry| {
    //    if (entry.kind == .file and
    //        entry.basename.len > 5 and
    //        std.mem.eql(u8, ".java", entry.basename[entry.basename.len - 5 ..]))
    //    {
    //        const source_file = entry.dir.openFile(entry.basename, .{}) catch |err| switch (err) {
    //            error.FileTooBig => continue,
    //            error.AccessDenied => continue,
    //            error.SymLinkLoop => continue,
    //            error.NoSpaceLeft => unreachable, //Indexing takes no disk space
    //            error.IsDir => unreachable,
    //            error.Unexpected => unreachable,
    //            else => unreachable,
    //        };
    //        defer source_file.close();
    //        const buf = source_file.readToEndAlloc(gpa, 100000000) catch @panic("Panic!");
    //        const tokens = try Tokenizer.tokenize(buf, &string_table, gpa);
    //        for (tokens.items) |t| {
    //            std.debug.print("{s} ", .{@tagName(t.type)});
    //        }
    //        //try split_tokenize(buf, &string_table);
    //        defer gpa.free(buf);
    //    }
    //}
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
