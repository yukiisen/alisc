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

    const slitch = b.addExecutable(.{
        .name = "slitch",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/slitch.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(base);
    b.installArtifact(alisc);
    b.installArtifact(slitch);

    const postbuild = b.addRunArtifact(slitch);
    postbuild.step.dependOn(b.getInstallStep());

    postbuild.addArtifactArg(alisc);
    postbuild.addArtifactArg(base);

    const install_step = b.step("slitch", "slitch base into the compiler.");
    install_step.dependOn(&postbuild.step);

    const run_cmd = b.addRunArtifact(base);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
