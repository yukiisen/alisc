const std = @import("std");

const cwd = std.Io.Dir.cwd;

const repr = @import("./format/repr.zig");

const compile = @import("compiler.zig").compile;
const embed = @import("./utils/embed.zig");

const parseArgs = @import("argparse.zig").parseArgs;
const Ctx = @import("argparse.zig").Ctx;

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    var source: []const u8 = &.{};

    if (@import("builtin").mode == .Debug) {
        const file = try cwd().openFile(init.io, "build.alisc", .{});
        defer file.close(init.io);

        const stat = try file.stat(init.io);
        const src = try gpa.alloc(u8, stat.size);

        _ = try file.readPositionalAll(init.io, source, 0);

        source = src;
    } else {
        source = try embed.readSlitch(init.io, gpa);
    }

    const program = try compile(source, gpa);
    const args = try init.minimal.args.toSlice(gpa);

    var stdbuf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &stdbuf);

    if (args.len < 2) return try usage(&program.meta, &program.commands, &stdout.interface);

    if (std.mem.eql(u8, args[1], "-v") or std.mem.eql(u8, args[1], "--version")) return std.debug.print("{s} v{s}\n", .{ program.meta.name, program.meta.version });
    if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help")) return try usage(&program.meta, &program.commands, &stdout.interface);

    const ctx = parseArgs(gpa, args[1..], &program) catch return try usage(&program.meta, &program.commands, &stdout.interface);
    try eval(gpa, init.io, &program.templates, ctx);
}

const HashMap = std.StringHashMapUnmanaged;

fn usage(
    meta: *const repr.Metadata,
    commands: *const HashMap(repr.Command),
    writer: *std.Io.Writer,
) !void {
    try writer.print("Usage:\n  {s} [command]\n\n", .{meta.name});

    try writer.writeAll("Available Commands:\n");

    // Column width: longest name + 2, minimum 12 (cobra's default-ish look).
    var max_name: usize = 0;
    var it = commands.iterator();
    while (it.next()) |entry| {
        const n = entry.key_ptr.*;
        if (n.len > max_name) max_name = n.len;
    }
    const col: usize = @max(max_name + 2, 12);

    it = commands.iterator();
    while (it.next()) |entry| {
        const name = entry.key_ptr.*;
        const cmd = entry.value_ptr.*;

        try writer.print("  {s}", .{name});
        if (cmd.description) |d| {
            const pad = if (name.len + 2 < col) col - (name.len + 2) else 1;
            for (0..pad) |_| try writer.writeByte(' ');
            try writer.writeAll(d);
        }
        try writer.writeByte('\n');
    }
    try writer.writeByte('\n');

    try writer.writeAll("Flags:\n");
    try writer.print("  -h, --help      help for {s}\n", .{meta.name});
    try writer.print("  -v, --version   display version\n\n", .{});

    try writer.print("Use \"{s} [command] --help\" for more information about a command.\n", .{meta.name});

    try writer.flush();
}

fn eval(gpa: std.mem.Allocator, io: std.Io, templates: *const HashMap(repr.Template), ctx: Ctx) !void {
    switch (ctx.cmd.cmd.?) {
        .exec => |v| {
            const argv = try std.mem.concat(gpa, []const u8, &.{ v.argv.items, ctx.args });
            var proc = try std.process.spawn(io, .{ 
                .argv = argv ,
                .stdin = .inherit,
                .stdout = .inherit,
                .stderr = .inherit,
            });

            _ = try proc.wait(io);
        },
        .run => |v| {
            const args = try std.mem.join(gpa, " ", ctx.args);
            var shell = try std.mem.join(gpa, " ", &.{ v.shell, args });
            
            if (v.template) |tmpl| {
                const template = templates.getPtr(tmpl).?;
                shell = try std.mem.replaceOwned(u8, gpa, template.body, "{}", shell);
            }

            var proc = try std.process.spawn(io, .{ 
                .argv = &.{ "/bin/sh", "-c", shell },
                .stdin = .inherit,
                .stdout = .inherit,
                .stderr = .inherit,
            });

            _ = try proc.wait(io);
        }
    }
}
