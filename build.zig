const std = @import("std");
const LazyPath = std.Build.LazyPath;

// TODO: Figure out what to do with this.
pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Run tests");
    const test_examples_step = b.step("test-examples", "Run tests from example projects");
    const check_step = b.step("check", "LSP Check");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const python_abi_module = b.createModule(.{
        .root_source_file = b.path("src/python.zig"),
        .target = b.graph.host,
    });

    const test_src_module = b.createModule(.{
        .root_source_file = b.path("src/test_src.zig"),
        .target = b.graph.host,
    });

    const wrapped_mod = b.createModule(.{
        .root_source_file = b.path("src/wrapper.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "src", .module = test_src_module },
            .{ .name = "python", .module = python_abi_module },
        },
    });

    const options = b.addOptions();
    options.addOption([]const u8, "name", "check");
    wrapped_mod.addOptions("config", options);

    const wrapper_lib = b.addLibrary(.{
        .name = "check",
        .linkage = .dynamic,
        .root_module = wrapped_mod,
    });
    wrapper_lib.linker_allow_shlib_undefined = true;

    check_step.dependOn(&wrapper_lib.step);

    const @"test" = b.addTest(.{
        .root_module = test_src_module,
    });

    // const wrapper_test = b.addTest(.{
    //     .root_module = wrapped_mod,
    // });

    // wrapper_test.root_module.link_libc = true;
    // wrapper_test.root_module.linkSystemLibrary("python.h", .{});

    const run_unit_tests = b.addRunArtifact(@"test");
    // const run_unit_tests = b.addRunArtifact(wrapper_test);
    run_unit_tests.setName("run src module unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // test_step.dependOn(&run_wrapper_test.step);

    // There is possibly a better way to interface with the example build more directly, but it's
    // challenging to do so without creating circular dependencies.
    const run_example_test = b.addSystemCommand(&.{ "zig", "build", "test" });
    run_example_test.setCwd(b.path("examples/python_fib/"));

    run_example_test.step.dependOn(&run_unit_tests.step);

    test_examples_step.dependOn(&run_example_test.step);
}

pub const Wheels = struct {
    lib_file: *std.Build.Step.InstallFile,
    lib_step: *std.Build.Step,

    // stub_file: *std.Build.Step.InstallFile,

    wheel_file: *std.Build.Step.InstallFile,
    wheel_step: *std.Build.Step,

    // wrapped_lib_file: *std.Build.Step.InstallFile,
};

//TODO: Add condition for if shimming is required, or if code already includes python
pub fn buildWheels(b: *std.Build, module: *std.Build.Module, name: []const u8, version: []const u8) Wheels {
    const root_build = b.dependencyFromBuildZig(@This(), .{});

    const python_abi_module = b.createModule(.{
        .root_source_file = root_build.path("src/python.zig"),
        .target = b.graph.host,
    });

    const wrapped_mod = b.createModule(.{
        .root_source_file = root_build.path("src/wrapper.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "src", .module = module },
            .{ .name = "python", .module = python_abi_module },
        },
    });

    const options = b.addOptions();
    options.addOption([]const u8, "name", name);
    wrapped_mod.addOptions("config", options);

    const wrapped_lib = b.addLibrary(.{
        .name = name,
        .linkage = .dynamic,
        .root_module = wrapped_mod,
    });

    wrapped_lib.linker_allow_shlib_undefined = true;

    // const wrapper_lib_file = b.addInstallFileWithDir(
    //     wrapper_lib.getEmittedBin(),
    //     .{ .custom = "wheels" },
    //     b.fmt("{s}.so", .{"blah"}),
    // );

    // const adapter_exe = b.addExecutable(.{
    //     .name = "adapter_exe",
    //     .root_module = b.createModule(.{
    //         .root_source_file = root_build.path("src/gen.zig"),
    //         .target = b.graph.host,
    //         .imports = &.{
    //             .{ .name = "src", .module = module },
    //         },
    //     }),
    // });

    // const adapter_run = b.addRunArtifact(adapter_exe);
    // adapter_run.setName("generated adapter zig file");
    // adapter_run.addFileArg2(module.root_source_file.?, .{});
    // const adapter_output_file = adapter_run.addOutputFileArg2(b.fmt("{s}.zig", .{name}), .{});
    // const stub_output_file = adapter_run.addOutputFileArg2(b.fmt("{s}.pyi", .{name}), .{});
    // TODO: Make this optional. This is what allows stdout to print from gen.zig
    // adapter_run.stdio = .inherit;

    // TODO: Change this to outputfilearg?
    // const options = b.addOptions();
    // options.addOption([]const u8, "root_name", name);
    // adapter_exe.root_module.addOptions("config", options);
    //
    // const mod = b.createModule(.{
    //     .root_source_file = adapter_output_file,
    //     .target = b.graph.host,
    //     .imports = &.{
    //         .{ .name = name, .module = module },
    //         .{ .name = "python", .module = python_abi_module },
    //     },
    // });

    // const lib = b.addLibrary(.{
    //     .name = name,
    //     .linkage = .dynamic,
    //     .root_module = mod,
    // });
    //
    // lib.linker_allow_shlib_undefined = true;

    // TODO: Double check this is necessary
    // NOTE: Currently this seems to be the only way to get the library with a name without a `lib` prefix.
    // https://github.com/ziglang/zig/issues/2231
    // No corresponding codeberg issues, should probably contribute a PR
    const wf = b.addWriteFiles();
    const wrapped_lib_path_without_prefix = wf.addCopyFile(
        wrapped_lib.getEmittedBin(),
        b.fmt("{s}.so", .{name}),
    );

    // Install the compiled binary as a Python-importable module: zig-out/wheels/<name>.so
    // QUES: Should we leave this as the lib-prefixed lib name and let the user rename if need be?
    //  Might actually be better not to install this and just return the lib to the user to install
    const lib_file = b.addInstallFileWithDir(
        wrapped_lib.getEmittedBin(),
        .{ .custom = "wheels" },
        b.fmt("{s}.so", .{name}),
    );

    // const stub_file = b.addInstallFileWithDir(
    //     stub_output_file,
    //     .{ .custom = "wheels" },
    //     b.fmt("{s}.pyi", .{name}),
    // );

    const wheel_file = buildWheel(
        b,
        module,
        wrapped_lib,
        wrapped_lib_path_without_prefix,
        // stub_output_file,
        name,
        version,
    );

    return Wheels{
        .lib_file = lib_file,
        .lib_step = &lib_file.step,

        // .stub_file = stub_file, // QUES: Should we just return the lazy path so the user can control install?

        .wheel_file = wheel_file,
        .wheel_step = &wheel_file.step,

        // .wrapped_lib_file = wrapped_lib_file,
    };
}

const Wheel = struct {
    file: *std.Build.Step.InstallFile,
    dir: *std.Build.LazyPath,
};

fn buildWheel(
    b: *std.Build,
    module: *std.Build.Module,
    lib: *std.Build.Step.Compile,
    lib_file: std.Build.LazyPath,
    // stub_file: std.Build.LazyPath,
    name: []const u8,
    version: []const u8,
) *std.Build.Step.InstallFile {
    const root_build = b.dependencyFromBuildZig(@This(), .{});

    const build_wheel_exe = b.addExecutable(.{
        .name = "build_wheel_exe",
        .root_module = b.createModule(.{
            .root_source_file = root_build.path("src/dist.zig"),
            .target = b.graph.host,
            .imports = &.{
                .{ .name = "src", .module = module },
            },
        }),
    });

    // The version python.zig is generated from. I think this can be changed if using the
    // stable ABI, but need to look into it properly
    const abi = "abi3";
    const python_tag = "cp311";

    const host = b.graph.host.result;
    const platform: []const u8 = switch (host.os.tag) {
        .linux => switch (host.cpu.arch) {
            .x86_64 => "linux_x86_64",
            .aarch64 => "linux_aarch64",
            else => std.debug.panic("zigweld: no wheel platform tag for {s} {s}", .{
                @tagName(host.os.tag), @tagName(host.cpu.arch),
            }),
        },
        .macos => switch (host.cpu.arch) {
            .aarch64 => "macosx_27_0_arm64",
            // .x86_64 => "x86_64",
            else => std.debug.panic("zigweld: no wheel platform tag for {s} {s}", .{
                @tagName(host.os.tag), @tagName(host.cpu.arch),
            }),
        },
        else => std.debug.panic("zigweld: no wheel platform tag for {s}", .{
            @tagName(host.os.tag),
        }),
    };
    const tag = b.fmt("{s}-{s}-{s}", .{ python_tag, abi, platform });

    const options = b.addOptions();
    options.addOption([]const u8, "name", name);
    options.addOption([]const u8, "version", version);
    options.addOption([]const u8, "tag", tag);
    build_wheel_exe.root_module.addOptions("config", options);

    const build_wheel_run = b.addRunArtifact(build_wheel_exe);
    build_wheel_run.addFileArg(lib.getEmittedBin());
    const wheel_output_dir = build_wheel_run.addOutputDirectoryArg2(
        b.fmt("{s}-{s}.dist-info", .{ name, version }),
        .{},
    );

    const wheel_name = b.fmt("{s}-{s}-{s}.whl", .{ name, version, tag });
    // TODO: We might want to be checking if python is available, and if we are in a virtual env maybe?
    // Using python to zip for now, since we know we will have it. Will bring in house at some point
    const zip_cmd = b.addSystemCommand(&.{ "python", "-m", "zipfile", "-c" });
    zip_cmd.setName("zip final wheel contents");
    // QUES: Why does placing the outputFileArg _after_ addArgs result in nothing being generated?
    const zipped_wheel_output_file = zip_cmd.addOutputFileArg2(wheel_name, .{});
    zip_cmd.addFileArg2(lib_file, .{});
    // zip_cmd.addFileArg2(stub_file, .{});
    zip_cmd.addDirectoryArg2(wheel_output_dir, .{});

    const zipped_wheel_file = b.addInstallFileWithDir(
        zipped_wheel_output_file,
        .{ .custom = "dist" },
        wheel_name,
    );
    return zipped_wheel_file;
}
