# zigweld

> "See a need, fill a need!"
> -- Bigweld

A toolkit for packaging Zig code as Python extension modules.

## Capabilities

- **Adapter generation** — inspects your Zig source and generates the CPython C API boilerplate needed to expose your Zig functions to Python.
- **Type stubs** — emits `.pyi` stub files so editors and type checkers know your module's signatures.
- **Wheel packaging** — builds a `pip install`able `.whl` file (zip archive).


## Usage

Add zigweld as a dependency in your project's `build.zig.zon` (see [examples/python_fib](examples/python_fib) for a working example):

```zig
const zigweld = @import("zigweld");

pub fn build(b: *std.Build) void {
    // ...
    // Create your zig module
    const mod = b.createModule(.{ .root_source_file = b.path("src/root.zig"), ... });

    // Set up the build step
    const wheels_step = b.step("wheels", "Build Python wheels");
    const volt = zigweld.buildWheels(b, mod, "mypackage", "0.1.0");

    // To generate just the adapted binary
    wheels_step.dependOn(&volt.lib_file.step);   // zig-out/wheels/mypackage.so
    // To generate the type stubs
    wheels_step.dependOn(&volt.stub_file.step);  // zig-out/wheels/mypackage.pyi
    // To generate the full wheel. Note the previous dependencies are not required if all you want is the full wheel
    // with the stubs and binary included.
    wheels_step.dependOn(&volt.wheel_file.step); // zig-out/dist/mypackage-...whl
}
```

Then:

```sh
zig build wheels
pip install zig-out/dist/mypackage-*.whl
```

## Supported types

Currently supports `i32`, `i64`, `f32`, and `f64` arguments/returns (mapped to Python `int`/`float`).

### Limitations

This is a very simple project at the moment. All it supports is is numeric inputs and outputs from zig functions. 
Work is active on supporting different data structures and interfacing methods.

## Examples

See [examples/python_fib](examples/python_fib) for an example project which uses zigweld

## Requirements

- Zig `0.17.0` or newer 
- Python 3.11+ (for wheel building/install; runtime may work on older versions via abi3)

## Status

Early stage / experimental. API is subject to change.

## License

MIT — see [LICENSE](LICENSE).
