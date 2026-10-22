const std = @import("std");

const cwd = std.Io.Dir.cwd;

const repr = @import("./format/repr.zig");

const compile = @import("compiler.zig").compile;
const embed = @import("./utils/embed.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);

    if (args.len != 3) return usage();

    const file = try cwd().openFile(init.io, "build.alisc", .{});
    defer file.close(init.io);

    const stat = try file.stat(init.io);
    const source = try gpa.alloc(u8, stat.size);

    _ = try file.readPositionalAll(init.io, source, 0);

    _ = try compile(source, gpa);
}

fn usage() void {
    std.log.err("Usage: alisc [file] [output]", .{});
}
