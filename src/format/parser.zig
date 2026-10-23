const std = @import("std");
const Token = @import("scanner.zig").Token;
const TokenType = @import("scanner.zig").TokenType;
const BufferReader = @import("../utils/bufreader.zig").BufferReader;

const repr = @import("repr.zig");

const Self = @This();

const ParseError = error {
    UnexpectedEOF,
    UnexpectedToken,
    InvalidSyntax,
    UndefinedSymbol,
    OutOfMemory,
};

fn tokenEql(t: Token, c: TokenType) bool { return t.t_type == c; }

tokens: BufferReader(Token, TokenType, tokenEql),
program: repr.Program = undefined,
current: u32 = 0,

pub fn init(tokens: []const Token) Self {
    return .{ .tokens = .init(tokens) };
}

pub fn parse(self: *Self, gpa: std.mem.Allocator) ParseError!repr.Program {
    self.program = .{ .gpa = gpa };

    while (!self.tokens.match(.Eof)) {
        const token = self.tokens.read() orelse return error.UnexpectedEOF;
        switch (token.t_type) {
            .Tmpl => {
                const t = try self.template();
                try self.program.templates.put(gpa, t.name, t);
            },
            .Cmd => {
                if (self.program.templates.pointer_stability.state == .unlocked) self.program.templates.lockPointers(); // disable writes to templates after first cmd
                const c = try self.command();
                try self.program.commands.put(gpa, c.name, c);
            },
            .Alias => {
                if (self.program.commands.pointer_stability.state == .unlocked) self.program.commands.lockPointers(); // disable writes to cmd after the first alias
                const a = try self.alias();
                try self.program.aliases.put(gpa, a.source, a);
            },
            .Name => { self.program.meta.name = (try self.next(.String)).lexeme; },
            .Version => { self.program.meta.version= (try self.next(.String)).lexeme; },
            .Author => { self.program.meta.author = (try self.next(.String)).lexeme; },
            else => return error.UnexpectedToken,
        }
    }

    return self.program;
}

fn template(self: *Self) ParseError!repr.Template {
    const id = try self.next(.Identifier);
    const body = try self.next(.String);

    return .{ .name = id.lexeme, .body = body.lexeme };
}

fn command(self: *Self) ParseError!repr.Command {
    const name = try self.next(.Identifier);
    var cmd: repr.Command = .{ .name = name.lexeme };

    const p = self.tokens.read() orelse return error.UnexpectedEOF;

    switch (p.t_type) {
        .LeftBrace => try self.longCmd(&cmd),
        .Colon => try self.shortCmd(&cmd),
        else => return error.InvalidSyntax,
    }

    return cmd;
}

fn shortCmd(self: *Self, cmd: *repr.Command) ParseError!void {
    const spawn_t = self.tokens.read() orelse return error.UnexpectedEOF;

    cmd.cmd = switch (spawn_t.t_type) {
        .Run => try self.shell(),
        .Exec => try self.spawn(),
        else => return error.InvalidSyntax,
    };
}

fn longCmd(self: *Self, cmd: *repr.Command) ParseError!void {
    while (!self.tokens.match(.RightBrace)) {
        const prefix = self.tokens.read() orelse return error.UnexpectedEOF;

        switch (prefix.t_type) {
            .Desc => cmd.description = try self.description(),
            .Run => cmd.cmd = try self.shell(),
            .Exec => cmd.cmd = try self.spawn(),
            .Args => cmd.argc = try self.argc(),
            .OptArgs => cmd.optargs = try self.argc(),
            .Requires => try cmd.requirements.append(self.program.gpa, try self.requirement()),
            .Cmd => {
                const c = try self.command();
                try cmd.children.put(self.program.gpa, c.name, c);
            },
            else => return error.InvalidSyntax,
        }
    }
}

fn description(self: *Self) ParseError![]const u8 {
    return (try self.next(.String)).lexeme;
}

fn shell(self: *Self) ParseError!repr.Spawner {
    const tmpl = self.tokens.read() orelse return error.UnexpectedEOF;

    return switch (tmpl.t_type) {
        .Identifier => .{ 
            .run = .{
                .template = tmpl.lexeme, 
                .shell = (try self.next(.String)).lexeme
            } 
        },
        .String => .{
            .run = .{
                .shell = tmpl.lexeme
            } 
        },
        else => error.InvalidSyntax,
    };
}

fn spawn(self: *Self) ParseError!repr.Spawner {
    var argv = std.ArrayList([]const u8).empty;
    argv.append(self.program.gpa, (try self.next(.String)).lexeme) catch return error.OutOfMemory; // append binary name
    
    while (self.tokens.match(.Comma)) {
        argv.append(self.program.gpa, (try self.next(.String)).lexeme) catch return error.OutOfMemory;
    }

    return .{ .exec = .{ .argv = argv } };
}

fn argc(self: *Self) ParseError!u16 {
    const num = (try self.next(.Number)).lexeme;
    return std.fmt.parseInt(u16, num, 10) catch error.InvalidSyntax;
}

fn requirement(self: *Self) ParseError!repr.Requirement {
    const t = self.tokens.read() orelse return error.UnexpectedEOF;

    const req_t: repr.RequirementType = switch (t.t_type) {
        .File => .File,
        .Bin => .Bin,
        .Env => .Env,
        else => return error.InvalidSyntax,
    };

    const req = try self.next(.String);

    return .{ .ttype = req_t, .target = req.lexeme };
}

fn alias(self: *Self) ParseError!repr.Alias {
    const source = try self.next(.Identifier);
    const dest = try self.cmdRef();

    return .{ .source = source.lexeme, .dest = dest };
}

inline fn next(self: *Self, t: TokenType) ParseError!Token {
    const id = self.tokens.read() orelse return error.UnexpectedEOF;
    return if (id.t_type == t) id else error.InvalidSyntax;
}

fn cmdRef(self: *Self) ParseError!*const repr.Command {
    const commands = self.program.commands;

    const ident = try self.next(.Identifier);
    var cmd = commands.getPtr(ident.lexeme) orelse return error.UndefinedSymbol;

    while (self.tokens.match(.Dot)) {
        const id = try self.next(.Identifier);
        cmd = cmd.children.getPtr(id.lexeme) orelse return error.UndefinedSymbol;
    }

    return cmd;
}
