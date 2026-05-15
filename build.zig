const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const library = b.addLibrary(.{
        .name = "express_zig",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const express_zig_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("express_zig", express_zig_mod);
    exe.root_module.linkLibrary(library);
    b.installArtifact(library);
    b.installArtifact(exe);
}
