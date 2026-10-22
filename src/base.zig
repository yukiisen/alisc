const std = @import("std");

const cwd = std.Io.Dir.cwd;

const repr = @import("./format/repr.zig");

const compile = @import("compiler.zig").compile;
const embed = @import("./utils/embed.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    const file = try cwd().openFile(init.io, "build.alisc", .{});
    defer file.close(init.io);

    const stat = try file.stat(init.io);
    const source = try gpa.alloc(u8, stat.size);

    _ = try file.readPositionalAll(init.io, source, 0);

    const program = try compile(source, gpa);

    std.debug.print("Templates:\n", .{});
    var t = program.templates.valueIterator(); 
    while (t.next()) |tmpl| std.debug.print("   Template {s} with command {s}\n", .{ tmpl.name, tmpl.body });

    std.debug.print("Aliases:\n", .{});
    var a = program.aliases.valueIterator(); 
    while (a.next()) |ali| std.debug.print("    Alias from {s} to {s}\n", .{ ali.source, ali.dest.name });

    std.debug.print("Commands:\n", .{});
    var c = program.commands.valueIterator(); 
    while (c.next()) |cmd| printCmd(cmd, 1);
}

fn print(level: u32, comptime fmt: []const u8, args: anytype) void {
    for (0..level) |_| std.debug.print("   ", .{});
    std.debug.print(fmt ++ "\n", args);
}

fn printCmd(cmd: *const repr.Command, pad: u32) void {
    print(pad, "Command {s}", .{ cmd.name });
    print(pad + 1, "Desc {?s}", .{ cmd.description });
    print(pad + 1, "Spawn {any}", .{ cmd.cmd });

    var it = cmd.children.valueIterator();
    while (it.next()) |c| {
        printCmd(c, pad + 1);
    }
}
