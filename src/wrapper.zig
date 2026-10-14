const std = @import("std");
const Py = @import("python.zig");

// This is the users source code we are converting
const src = @import("src");

const PythonFormat = struct {
    parse: []const u8,
    build: []const u8,
    python: []const u8,
};

// https://docs.python.org/3/c-api/arg.html
fn getPythonFormat(comptime T: type) PythonFormat {
    return switch (T) {
        i16 => .{ .parse = "i", .build = "i", .python = "int" },
        i32 => .{ .parse = "l", .build = "l", .python = "int" },
        i64 => .{ .parse = "L", .build = "L", .python = "int" },

        u16 => .{ .parse = "I", .build = "I", .python = "int" },
        u32 => .{ .parse = "k", .build = "k", .python = "int" },
        u64 => .{ .parse = "K", .build = "K", .python = "int" },

        f32 => .{ .parse = "f", .build = "f", .python = "int" },
        f64 => .{ .parse = "d", .build = "d", .python = "int" },

        else => unreachable,
    };
}

fn makeWrapped(comptime func: anytype) type {
    const func_type = @TypeOf(func);
    const func_type_info: std.lang.Type = @typeInfo(func_type);

    std.debug.assert(func_type_info == .@"fn");
    const func_info = func_type_info.@"fn";

    // For now, not handling/supporting anytype/generics
    std.debug.assert(!func_info.is_generic);

    // Need to go through the inputs, and arrange them like python, with the format units.
    // def foo(a: int, b: str, c: int | None = None, d: str | None = None)
    // => is|is (I think)
    // Might not want to allow optionals without defaults for now. Seems more complex.
    //

    // func_info.return_type;

    // NOTE: This size is incorrect. Pipes, and asterisks will increase this size.
    // var parse_format: [func_info.param_types.len]u8 = undefined;

    const parse_format = comptime blk: {
        var fmt: [func_info.param_types.len]u8 = undefined;
        for (func_info.param_types, 0..) |param_type, i| {
            const python_format = getPythonFormat(param_type.?);
            std.debug.assert(python_format.parse.len == 1);
            fmt[i] = python_format.parse[0];
        }
        break :blk fmt;
    };

    return struct {
        pub const p_format = parse_format;
        pub const f_info = func_info;
        pub fn wrapped(self: [*c]Py.PyObject, args: [*c]Py.PyObject) callconv(.c) [*c]Py.PyObject {
            _ = self;

            // Build a tuple sized for the arg types for us to unpack into
            const func_args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;

            // Build a tuple for holding types?
            var ptr_tuple: [f_info.param_types.len]type = undefined;
            inline for (f_info.param_types, 0..) |param_type, i| {
                ptr_tuple[i] = *param_type.?;
            }

            var func_args_ptrs: @Tuple(&ptr_tuple) = undefined;
            inline for (0..f_info.param_types.len) |i| {
                func_args_ptrs[i] = &func_args[i];
            }

            const unpack_response = @call(
                .auto,
                Py.PyArg_ParseTuple,
                .{ args, @as([*c]const u8, p_format) } ++ func_args_ptrs,
            );
            if (unpack_response == 0) {
                return null;
            }

            const response = @call(.auto, func, func_args);
            return Py.Py_BuildValue("i", @as(u32, response));

            // var foo: u32 = undefined;
            // var bar: u32 = undefined;
            // if (!(Py.PyArg_ParseTuple(args, final_format, &foo, &bar) != 0)) return null;
            // const response = @call(.auto, func, .{ foo, bar });
            // return Py.Py_BuildValue("i", @as(u32, response));
        }
    };
}

const src_type_info: std.lang.Type = @typeInfo(src);

var methods = blk: {
    // Count up the number of public functions for us to turn into methods so we can
    // create a method array of the right size
    var num_methods = 0;
    for (src_type_info.@"struct".decl_names) |decl_name| {
        const field = @field(src, decl_name);
        const field_type: type = @TypeOf(field);
        const field_type_info: std.lang.Type = @typeInfo(field_type);
        switch (field_type_info) {
            .@"fn" => |func| {
                if (func.is_generic) {}
                num_methods += 1;
            },
            else => {
                continue;
            },
        }
    }

    // Populate the
    var methods_temp: [num_methods + 1]Py.PyMethodDef = undefined;
    var func_number = 0;
    for (src_type_info.@"struct".decl_names) |decl_name| {
        const field = @field(src, decl_name);
        const field_type = @TypeOf(field);
        const field_type_info: std.lang.Type = @typeInfo(field_type);
        switch (field_type_info) {
            .@"fn" => {
                methods_temp[func_number] = Py.PyMethodDef{
                    .ml_name = decl_name,
                    .ml_flags = Py.METH_VARARGS, // TODO: Make this variable
                    .ml_doc = decl_name, // TODO: Make this the actual docstring
                    .ml_meth = makeWrapped(field).wrapped,
                };
                func_number += 1;
            },
            else => {
                continue;
            },
        }
    }

    // Sentinel value to indicate end of array
    methods_temp[num_methods] = Py.PyMethodDef{
        .ml_name = null,
        .ml_meth = null,
        .ml_flags = 0,
        .ml_doc = null,
    };

    break :blk methods_temp;
};

var module = Py.PyModuleDef{
    .m_base = Py.PyModuleDef_Base{
        .ob_base = Py.PyObject{
            // .ob_refcnt = 1,
            .ob_type = null,
        },
        .m_init = null,
        .m_index = 0,
        .m_copy = null,
    },
    .m_name = "fib",
    .m_doc = null,
    .m_size = -1,
    .m_methods = &methods,
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};

comptime {
    @export(&internal, .{ .name = "PyInit_blah", .linkage = .strong });
}
pub fn internal() callconv(.c) [*]Py.PyObject {
    return Py.PyModule_Create(&module);
}
