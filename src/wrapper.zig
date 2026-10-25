const std = @import("std");
const Py = @import("python");

// This is the users source code we are converting
const src = @import("src");

// Options passed in from build.zig
const config = @import("config");

const module_import_name = config.name;

const FormatCType = struct {
    format: []const u8,
    type: type,
};

const PythonFormat = struct {
    parse: FormatCType,
    build: FormatCType,
    python: []const u8,
};

// https://docs.python.org/3/c-api/arg.html
fn getPythonParseFormat(comptime T: type) PythonFormat {
    const format: PythonFormat = switch (@typeInfo(T)) {
        .optional => @compileError("optional types are not supported"),
        .pointer => |ptr| {
            if (ptr.sentinel() == null) {
                @compileError("only sentinel terminated is currently supported");
            }
            return switch (ptr.child) {
                u8 => .{
                    .parse = .{ .format = "h", .type = c_short },
                    .build = .{ .format = "h", .type = c_short },
                    .python = "int",
                },
                else => @compileError("pointer to " ++ @typeName(ptr.child) ++ " not supported"),
            };
        },
        // NOTE: parse and build formats are not always the same, although often they are. Hence the distinct entries.
        else => switch (T) {
            i16 => .{
                .parse = .{ .format = "h", .type = c_short },
                .build = .{ .format = "h", .type = c_short },
                .python = "int",
            },
            i32 => .{
                .parse = .{ .format = "i", .type = c_int },
                .build = .{ .format = "i", .type = c_int },
                .python = "int",
            },
            i64 => .{
                .parse = .{ .format = "L", .type = c_longlong },
                .build = .{ .format = "L", .type = c_longlong },
                .python = "int",
            },
            u16 => .{
                .parse = .{ .format = "H", .type = c_ushort },
                .build = .{ .format = "H", .type = c_ushort },
                .python = "int",
            },
            u32 => .{
                .parse = .{ .format = "I", .type = c_uint },
                .build = .{ .format = "I", .type = c_uint },
                .python = "int",
            },
            u64 => .{
                .parse = .{ .format = "K", .type = c_ulonglong },
                .build = .{ .format = "K", .type = c_ulonglong },
                .python = "int",
            },
            // Zig floats are perfectly compatible with C floats, so we don't need a c-type for checking
            f32 => .{
                .parse = .{ .format = "f", .type = f32 },
                .build = .{ .format = "f", .type = f32 },
                .python = "float",
            },
            f64 => .{
                .parse = .{ .format = "d", .type = f64 },
                .build = .{ .format = "d", .type = f64 },
                .python = "float",
            },
            else => @compileError(@typeName(T) ++ " not supported"),
        },
    };
    comptime {
        std.debug.assert(@sizeOf(T) == @sizeOf(format.parse.type));
        std.debug.assert(@sizeOf(T) == @sizeOf(format.build.type));
    }
    return format;
}

fn makeWrapped(comptime func: anytype) type {
    const func_type = @TypeOf(func);
    const func_type_info: std.lang.Type = @typeInfo(func_type);

    std.debug.assert(func_type_info == .@"fn");
    const func_info = func_type_info.@"fn";

    if (func_info.is_generic) {
        @compileError("generic functions are not supported");
    }
    if (func_info.return_type != null) {
        if (@typeInfo(func_info.return_type.?) == .optional) {
            @compileError("optional return types are not supported");
        }
    }

    // Need to go through the inputs, and arrange them like python, with the format units.
    // def foo(a: int, b: str, c: int | None = None, d: str | None = None)
    // => is|is (I think)
    // Might not want to allow optionals without defaults for now. Seems more complex.
    //

    // func_info.return_type;

    // NOTE: This size is incorrect. Pipes, and asterisks will increase this size.
    // var parse_format: [func_info.param_types.len]u8 = undefined;

    const parse_format = comptime blk: {
        var fmt: [func_info.param_types.len:0]u8 = undefined;
        for (func_info.param_types, 0..) |param_type, i| {
            // @compileLog(param_type.?);
            const python_format = getPythonParseFormat(param_type.?);
            std.debug.assert(python_format.parse.format.len == 1);
            fmt[i] = python_format.parse.format[0];
        }
        fmt[func_info.param_types.len] = 0;
        break :blk fmt;
    };

    return struct {
        pub const p_format = parse_format;
        const f_info = func_info;
        pub fn wrapped(self: [*c]Py.PyObject, args: [*c]Py.PyObject) callconv(.c) [*c]Py.PyObject {
            _ = self;

            // Build a tuple for the function args to be unpacked into
            // var func_args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;

            const info = @typeInfo(@TypeOf(func));
            if (info != .@"fn")
                @compileError("ArgsTuple expects a function type");

            const function_info = info.@"fn";
            if (function_info.attrs.varargs)
                @compileError("Cannot create ArgsTuple for variadic function");

            comptime var argument_field_list: [function_info.param_types.len]type = undefined;
            inline for (function_info.param_types, 0..) |arg_type, i| {
                const T = arg_type orelse @compileError("cannot create ArgsTuple for function with an 'anytype' parameter");
                argument_field_list[i] = T;
            }

            var func_args: @Tuple(&argument_field_list) = undefined;

            // Build a tuple for holding types?
            comptime var ptr_tuple: [f_info.param_types.len]type = undefined;
            inline for (f_info.param_types, 0..) |param_type, i| {
                ptr_tuple[i] = *param_type.?; // TODO: Handle anytype/generic better
            }
            // @compileLog(ptr_tuple);

            // NOTE: I dont think we can know this at comptime?
            var func_args_ptrs: @Tuple(&ptr_tuple) = undefined;

            // @compileLog(func_args_ptrs);
            inline for (0..f_info.param_types.len) |i| {
                func_args_ptrs[i] = &func_args[i];
            }

            std.debug.print("func_args_ptrs: {}\n", .{func_args_ptrs});

            // Unpack the args provided from the python-side, into zig values
            std.debug.print("{s} {}, {}\n", .{
                p_format,                                                  func_args,

                .{ args, @as([*c]const u8, &p_format) } ++ func_args_ptrs,
            });

            const unpack_response = @call(
                .auto,
                Py.PyArg_ParseTuple,
                .{ args, @as([*c]const u8, &p_format) } ++ func_args_ptrs,
            );
            if (unpack_response == 0) {
                return null;
            }

            std.debug.print("unpacked: {}\n", .{func_args});

            // Pass zig values into function
            const response = @call(.auto, func, func_args);
            if (f_info.return_type == null) {
                @compileError("generic functions are not supported");
            }

            const response_format = getPythonParseFormat(f_info.return_type.?);

            return Py.Py_BuildValue(@as([*c]const u8, &response_format.build.format[0]), response);
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
            .@"fn" => {
                num_methods += 1;
            },
            else => {
                continue;
            },
        }
    }

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
    @export(&internal, .{ .name = "PyInit_" ++ module_import_name, .linkage = .strong });
}
pub fn internal() callconv(.c) [*]Py.PyObject {
    return Py.PyModule_Create(&module);
}
