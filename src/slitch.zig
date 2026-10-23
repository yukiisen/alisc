const std = @import("std");
const embed = @import("utils/embed.zig");

const cwd = std.Io.Dir.cwd;

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len < 3) return error.NotEnoughArgumentsSpecified;

    const alisc = try cwd().openFile(init.io, args[1], .{ .mode = .write_only });
    defer alisc.close(init.io);

    const base = try cwd().openFile(init.io, args[2], .{ .mode = .read_only });
    defer base.close(init.io);
    
    const base_size = (try base.stat(init.io)).size;
    const payload = try gpa.alloc(u8, base_size);

    _ = try base.readPositionalAll(init.io, payload, 0);

    try embed.writeSlitch(init.io, alisc, payload);

    std.debug.print("Slitched Stuff\n", .{});
}
