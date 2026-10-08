const std = @import("std");
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;
const BufferReader = @import("bufreader.zig").BufferReader;

const repr = @import("repr.zig");

const Self = @This();

const ParseError = error {
    UnexpectedEOF,
    UnexpectedToken,
    InvalidSyntax,
    UndefinedSymbol
};

fn tokenEql(t: Token, c: TokenType) bool { return t.t_type == c; }

tokens: BufferReader(Token, TokenType, tokenEql),
program: repr.Program = .{},
current: u32 = 0,

pub fn init(tokens: []const Token) Self {
    return .{ .tokens = .init(tokens) };
}

pub fn parse(self: *Self, gpa: std.mem.Allocator) !repr.Program {
    while (self.tokens.read()) |token| {
        switch (token.t_type) {
            .Tmpl => {
                const t = try self.template();
                try self.program.templates.put(gpa, t.name, t);
            },
            .Cmd => {},
            .Alias => {
                self.program.commands.lockPointers(); // disable writes to cmd after the first alias
                const a = try self.alias();
                try self.program.aliases.put(gpa, a.source, a);
            },
            // else => return error.UnexpectedToken,
            else => {}
        }
    }

    return self.program;
}

fn template(self: *Self) ParseError!repr.Template {
    const id = self.tokens.read() orelse return error.UnexpectedEOF;
    const body = self.tokens.read() orelse return error.UnexpectedEOF;

    if (id.t_type == .Identifier and body.t_type == .String) {
        return .{ .name = id.lexeme, .body = body.lexeme[1..body.lexeme.len - 1] };
    }

    return error.InvalidSyntax;
}

// fn command(self: *Self) ParseError!repr.Command {
//
// }

fn alias(self: *Self) ParseError!repr.Alias {
    const source = self.tokens.read() orelse return error.UnexpectedEOF;
    const dest = try self.identifier();

    if (source.t_type == .Identifier) return .{ .source = source.lexeme, .dest = dest };

    return error.InvalidSyntax;
}

fn identifier(self: *Self) ParseError!*const repr.Command {
    const commands = self.program.commands;

    const ident = self.tokens.read() orelse return error.UnexpectedEOF;
    var cmd = commands.getPtr(ident.lexeme) orelse return error.UndefinedSymbol;

    while (self.tokens.match(.Dot)) {
        const id = self.tokens.read() orelse return error.UnexpectedEOF;
        if (id.t_type != .Identifier) return error.InvalidSyntax;

        cmd = cmd.children.getPtr(id.lexeme) orelse return error.UndefinedSymbol;
    }

    return cmd;
}
