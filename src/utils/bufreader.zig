const std = @import("std");

pub fn BasicBufferReader(comptime T: type) type {
    return BufferReader(T, T, struct {
        fn f(a: T, b: T) bool { return a == b; }
    }.f);
}

pub fn BufferReader(comptime T: type, comptime C: type, comptime eql: *const fn (T, C) bool) type {
    return struct {
        const Self = @This();

        source: []const T,
        cursor: u32 = 0,

        pub fn init(source: []const T) Self {
            return .{ .source = source };
        }

        pub fn slice(self: Self, start: u32) []const T {
            return self.source[start..self.cursor];
        }

        pub fn isEof(self: Self) bool {
            return self.cursor >= self.source.len;
        }

        pub fn read(self: *Self) ?T {
            if (self.isEof()) return null;

            const char = self.source[self.cursor];
            self.cursor += 1;

            return char;
        }

        pub fn peek(self: Self) ?T {
            if (self.isEof()) return null;
            return self.source[self.cursor];
        }

        pub fn peekNext(self: Self) ?T {
            if (self.cursor + 1 >= self.source.len) return null;
            return self.source[self.cursor + 1];
        }

        pub fn match(self: *Self, expected: C) bool {
            if (self.isEof()) return false;
            if (!eql(self.peek() orelse return false, expected)) return false;

            self.cursor += 1;
            return true;
        }

        pub fn next(self: *Self, target: T) void {
            while (self.peek()) |p| {
                if (p == '\\') self.cursor += 2;
                if (self.read() == target) return;
            }
        }
    };
}

pub const LineReader = struct {
    const Self = @This();

    lines: std.ArrayList([]const u8),
    nlines: usize,

    pub fn init(source: []const u8, gpa: std.mem.Allocator) !Self {
        var split = std.mem.splitScalar(u8, source, '\n');
        var lines = std.ArrayList([]const u8).empty;

        while (split.next()) |line| {
            try lines.append(gpa, line);
        }

        return .{ .lines = lines, .nlines = lines.items.len };
    }

    pub fn getLine(self: *const Self, line: u32) []const u8 {
        return self.lines.items[line - 1];
    }

    pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
        self.lines.deinit(gpa);
    }
};
