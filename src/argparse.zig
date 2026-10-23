const std = @import("std");

const repr = @import("./format/repr.zig");

const Command = repr.Command;

pub const Ctx = struct {
    cmd: *Command,
    args: []const []const u8,
};

pub fn parseArgs(_: std.mem.Allocator, args: []const []const u8, program: *const repr.Program) !Ctx {
    var command: ?*Command = null;
    var root = &program.commands;

    var i: u32 = 0;
    while (i < args.len) : (i += 1) {
        if (root.getPtr(args[i])) |cmd| {
            command = cmd;
            root = &cmd.children;
        } 
        else break;
    }

    const argv = args[i..];

    if (command) |cmd| {
        if (cmd.cmd == null) return error.NotExecutable;

        if (cmd.argc) |argc| {
            if (argv.len < argc) return error.Misusage;
        }

        if (cmd.optargs) |argc| {
            if (argv.len > argc + (cmd.argc orelse 0)) return error.Misusage;
        }

        return .{ .cmd = cmd, .args = argv };
    }

    return error.CommandNotFound;
}
