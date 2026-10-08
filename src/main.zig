const std = @import("std");

const cwd = std.Io.Dir.cwd;

const Scanner = @import("scanner.zig");
const Parser = @import("parser.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    const file = try cwd().openFile(init.io, "build.alisc", .{});
    defer file.close(init.io);

    const stat = try file.stat(init.io);
    const source = try gpa.alloc(u8, stat.size);

    _ = try file.readPositionalAll(init.io, source, 0);

    var scanner = Scanner.init(source);
    const tokens = scanner.scan(gpa) catch |err| {
        std.debug.print("Error: Line {d}, UnexpectedToken at char {d}\n", .{ scanner.line, scanner.source.cursor });
        return err;
    };

    for (tokens) |token| {
        std.debug.print("{any}: {s} at Line {d}\n", .{ token.t_type, token.lexeme, token.line });
    }

    std.debug.print("\nGenerated {d} tokens\n", .{ tokens.len });

    var parser = Parser.init(tokens);
    const program = try parser.parse(gpa);

    std.debug.print("Templates:\n", .{});
    var t = program.templates.valueIterator(); 
    while (t.next()) |tmpl| std.debug.print("Template {s} with command {s}\n", .{ tmpl.name, tmpl.body });

    std.debug.print("Aliases:\n", .{});
    var a = program.aliases.valueIterator(); 
    while (a.next()) |tmpl| std.debug.print("{any}\n", .{ tmpl });

    std.debug.print("Commands:\n", .{});
    var c = program.commands.valueIterator(); 
    while (c.next()) |tmpl| std.debug.print("{any}\n", .{ tmpl });
}
