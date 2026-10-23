const std = @import("std");

const cwd = std.Io.Dir.cwd;

const repr = @import("./format/repr.zig");

const compile = @import("compiler.zig").compile;
const embed = @import("./utils/embed.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);

    if (args.len != 3) return usage();

    const file = cwd().openFile(init.io, args[1], .{}) catch |err| {
        if (err == error.FileNotFound) {
            return std.log.err("{s}: No such file", .{ args[1] });
        }

        return err;
    };
    defer file.close(init.io);

    const stat = try file.stat(init.io);
    const source = try gpa.alloc(u8, stat.size);

    _ = try file.readPositionalAll(init.io, source, 0);

    _ = try compile(source, gpa);

    const base = try embed.readSlitch(init.io, gpa);
    const out = try cwd().createFile(init.io, args[2], .{ .permissions = .executable_file });

    try out.writePositionalAll(init.io, base, 0);
    try out.sync(init.io);

    try embed.writeSlitch(init.io, out, source);
}

fn usage() void {
    std.log.err("Usage: alisc [file] [output]", .{});
}
