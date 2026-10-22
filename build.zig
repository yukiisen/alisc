const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const base = b.addExecutable(.{
        .name = "base",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/base.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    const alisc = b.addExecutable(.{
        .name = "alisc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/alisc.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(base);
    b.installArtifact(alisc);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(alisc);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
