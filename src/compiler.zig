const std = @import("std");

const Scanner = @import("scanner.zig");
const Parser = @import("parser.zig");

const buf = @import("bufreader.zig");
const repr = @import("repr.zig");

pub fn compile(source: []const u8, gpa: std.mem.Allocator) !repr.Program {
    const reader = try buf.LineReader.init(source, gpa);

    var scanner = Scanner.init(source);
    const tokens = scanner.scan(gpa) catch |e| {
        if (e == error.UnexpectedToken) {
            std.log.err("Unexpected Token at {d}:{d}", .{ scanner.line, scanner.start - scanner.line_start });
            if (scanner.line > 2) std.log.err("  {s}", .{ reader.getLine(scanner.line - 2) });
            if (scanner.line > 1) std.log.err("  {s}", .{ reader.getLine(scanner.line - 1) });
            std.log.err("> {s}", .{ reader.getLine(scanner.line) });

            std.process.exit(1);
        }

        return e;
    };

    var parser = Parser.init(tokens);
    const program = parser.parse(gpa) catch |e| {
        if (e == error.OutOfMemory) return e;

        const token = parser.tokens.source[parser.tokens.cursor - 1];

        std.log.err("{any} at {d}:{d}", .{ e, token.line, token.column });
        if (token.line > 2) std.log.err("  {s}", .{ reader.getLine(token.line - 2) });
        if (token.line > 1) std.log.err("  {s}", .{ reader.getLine(token.line - 1) });
        std.log.err("> {s}", .{ reader.getLine(token.line) });

        std.process.exit(1);
    };

    return program;
}
