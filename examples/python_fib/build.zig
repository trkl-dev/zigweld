const std = @import("std");
const zon = @import("build.zig.zon");
const voltforge = @import("voltforge");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ############ VOLTFORGE USAGE ############## //
    const wheels_step = b.step("wheels", "Build Python wheels");
    const volt = voltforge.buildWheels(b, mod, @tagName(zon.name), zon.version);
    wheels_step.dependOn(&volt.lib_file.step); // Want the lib
    wheels_step.dependOn(&volt.stub_file.step); // Want the stubs
    wheels_step.dependOn(&volt.wheel_file.step); // Want the wheel
    // ############ VOLTFORGE USAGE ############## //

    const test_step = b.step("test", "Run test suite");
    const tests = b.addTest(.{
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(tests);
    run_tests.setName("run root zig tests");
    test_step.dependOn(&run_tests.step);

    const pip_install = b.addSystemCommand(&.{
        "python",
        "-m",
        "pip",
        "install",
        "--no-index",
        "--force-reinstall",
    });
    pip_install.setName("pip install module");
    pip_install.addFileArg2(volt.wheel_file.source, .{});
    pip_install.addFileInput(volt.wheel_file.source);
    pip_install.stdio = .{ .check = .empty };
    pip_install.stdio.check.append(b.allocator, .{ .expect_stdout_match = "Successfully installed" }) catch @panic("OOM");

    pip_install.step.dependOn(&volt.wheel_file.step);

    const py_test = b.addSystemCommand(&.{"python"});
    py_test.setName("run python unit tests");
    py_test.addFileArg2(b.path("main.py"), .{});
    py_test.addFileInput(volt.wheel_file.source);
    py_test.stdio = .{ .check = .empty };
    py_test.stdio.check.append(b.allocator, .{ .expect_stderr_match = "OK" }) catch @panic("OOM");

    py_test.step.dependOn(&pip_install.step);
    py_test.step.dependOn(&run_tests.step);

    test_step.dependOn(&py_test.step);
}
