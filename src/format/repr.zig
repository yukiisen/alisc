const std = @import("std");

const HashMap = std.StringHashMapUnmanaged;

pub const Program = struct {
    gpa: std.mem.Allocator,
    templates: HashMap(Template) = .empty,
    aliases: HashMap(Alias) = .empty,
    commands: HashMap(Command) = .empty,
};

pub const Template = struct {
    name: []const u8,
    body: []const u8,
};

pub const Alias = struct {
    source: []const u8,
    dest: *const Command,
};

pub const Command = struct {
    name: []const u8,
    argc: u16 = 0,
    optargs: u16 = 0,
    cmd: ?Spawner = null,
    description: ?[]const u8 = null,
    requirements: std.ArrayList(Requirement) = .empty,

    children: HashMap(Command) = .empty,
};

pub const Spawner = union(enum) {
    exec: struct {
        argv: std.ArrayList([]const u8),
    },
    run: struct {
        template: ?[]const u8 = null,
        shell: []const u8,
    },
};

pub const RequirementType = enum { File, Env, Bin };

pub const Requirement = struct {
    ttype: RequirementType,
    target: []const u8,
};
