const std = @import("std");

const BufferReader = @import("bufreader.zig").BasicBufferReader;

inline fn hash(input: []const u8) u64 {
    return std.hash.Wyhash.hash(0, input);
}

pub const TokenType = enum {
    // one character tokens
    Dot, Semicolon, Doubledot, LeftBrace, RightBrace,

    // literals
    Identifier, String, Number,

    // keywords
    Tmpl, 
    Cmd, Desc, Run, Exec, 
    Requires, Bin, File, Env, 
    Args, OptArgs, 
    Alias, 

    Eof,

    pub fn fromString(str: []const u8) TokenType {
        return switch (hash(str)) {
            inline hash("tmpl") => .Tmpl,
            inline hash("cmd") => .Cmd,
            inline hash("desc") => .Desc,
            inline hash("run") => .Run,
            inline hash("exec") => .Exec,
            inline hash("requires") => .Requires,
            inline hash("file") => .File,
            inline hash("bin") => .Bin,
            inline hash("env") => .Env,
            inline hash("args") => .Args,
            inline hash("optargs") => .OptArgs,
            inline hash("alias") => .Alias,
            else => .Identifier,
        };
    }
};

pub const Token = struct {
    t_type: TokenType,
    lexeme: []const u8 = &.{},
    line: u32,

    pub fn init(t_type: TokenType, line: u32) Token {
        return .{ .t_type = t_type, .line = line };
    }

    pub fn initLex(t_type: TokenType, lexeme: []const u8, line: u32) Token {
        return .{ .t_type = t_type, .lexeme = lexeme, .line = line };
    }

};

const Self = @This();

source: BufferReader(u8),
tokens: std.ArrayList(Token) = .empty,

start: u32 = 0,
line: u32 = 1,

pub fn init(source: []const u8) Self {
    return .{ .source = .init(source) };
}

pub fn scan(self: *Self, gpa: std.mem.Allocator) ![]const Token {
    while (!self.source.isEof()) {
        self.start = self.source.cursor;

        if (try self.scanToken()) |token| {
            try self.tokens.append(gpa, token);
        }
    }

    try self.tokens.append(gpa, .init(.Eof, self.line));

    return self.tokens.items;
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_' or c == '$';
}

pub fn scanToken(self: *Self) !?Token {
    const c = self.source.read() orelse return null;

    switch (c) {
        ':' => return .init(.Doubledot,  self.line),
        ';' => return .init(.Semicolon,  self.line),
        '.' => return .init(.Dot,        self.line),
        '{' => return .init(.LeftBrace,  self.line),
        '}' => return .init(.RightBrace, self.line),

        '/' => {
            if (self.source.match('/')) {
                self.source.next('\n');
                self.line += 1;
                return null;
            }

            return error.UnexpectedToken;
        },

        '"' => {
            self.source.next('"');
            return .initLex(.String, self.source.slice(self.start), self.line);
        },

        ' ', '\r', '\t' => return null,

        '\n' => {
            self.line += 1;
            return null;
        },

        else => {}
    }

    if (isDigit(c)) {
        while (isDigit(self.source.peek() orelse 0)) _ = self.source.read();
        return .initLex(.Number, self.source.slice(self.start), self.line);
    }

    if (isAlpha(c)) {
        while (
            isAlpha(self.source.peek() orelse 0) or 
            isDigit(self.source.peek() orelse 0)
        ) _ = self.source.read();

        const ident = self.source.slice(self.start);
        return .initLex(.fromString(ident), ident, self.line);
    }

    return error.UnexpectedToken;
}
