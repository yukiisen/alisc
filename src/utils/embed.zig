const std = @import("std");

const MAGIC: u32 = 0x4C495350;
const VERSION: u32 = 1;
const TRAILER_SIZE: usize = @sizeOf(Trailer) - @sizeOf(u64); // Trailer Size - playload_offset

pub const Trailer = struct {
    magic: u32,
    version: u32,
    playload_len: u64,
    playload_offset: u64,
};

fn readTrailer(bin: std.Io.File, io: std.Io) !Trailer {
    const stat = try bin.stat(io);
    if (stat.size < TRAILER_SIZE) return error.FileTooSmall;

    var buf: [TRAILER_SIZE]u8 = undefined;
    const n = try bin.readPositionalAll(io, &buf, stat.size - TRAILER_SIZE);
    if (n != TRAILER_SIZE) return error.CorruptHeader;
 
    const magic = std.mem.readInt(u32, buf[0..4], .little);
    if (magic != MAGIC) return error.TrailerNotFound;

    const version = std.mem.readInt(u32, buf[4..8], .little);
    if (version != VERSION) return error.UnsupportedVersion;

    const payload_len = std.mem.readInt(u64, buf[8..16], .little);
    if (payload_len + TRAILER_SIZE > stat.size) return error.CorruptTrailer;

    return .{
        .magic = magic,
        .version = version,
        .playload_len = payload_len,
        .playload_offset = stat.size - TRAILER_SIZE - payload_len,
    };
}

pub fn readSlitch(io: std.Io, gpa: std.mem.Allocator) ![]const u8 {
    const file = try std.process.openExecutable(io, .{});
    defer file.close(io);

    const trailer = try readTrailer(file, io);
    const buf = try gpa.alloc(u8, trailer.playload_len);
    errdefer gpa.free(buf);

    _ = try file.readPositionalAll(io, buf, trailer.playload_offset);
    return buf;
}

pub fn writeSlitch(io: std.Io, file: std.Io.File, payload: []const u8) !void {
    const stat = try file.stat(io);
    try file.writePositionalAll(io, payload, stat.size);

    var trailer: [TRAILER_SIZE]u8 = undefined;
    std.mem.writeInt(u32, trailer[0..4], MAGIC, .little);
    std.mem.writeInt(u32, trailer[4..8], VERSION, .little);
    std.mem.writeInt(u64, trailer[8..16], payload.len, .little);

    try file.writePositionalAll(io, trailer[0..], stat.size + payload.len);
}
