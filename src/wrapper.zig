const std = @import("std");
const Py = @import("python");
const utils = @import("utils.zig");

// This is the users source code we are converting
const src = @import("src");

// Options passed in from build.zig
const config = @import("config");

const module_import_name = config.name;

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

    const parse_format, const parse_args = comptime blk: {
        // Surely there is a better way to build the length
        var format_length = 0;
        var args_length = 0;
        for (func_info.param_types) |param_type| {
            const python_format = utils.getPythonParseFormat(param_type.?);
            format_length += python_format.parse.format.len;
            args_length += python_format.args.len;
        }

        var fmt: [format_length:0]u8 = undefined;
        var args: [args_length]type = undefined;
        var arg_idx = 0;
        for (func_info.param_types, 0..) |param_type, i| {
            const python_format = utils.getPythonParseFormat(param_type.?);
            for (python_format.parse.format, 0..) |char, ii| {
                fmt[i + ii] = char;
            }

            for (python_format.args) |t| {
                // @compileLog(i, ii, t);
                args[arg_idx] = t;
                arg_idx += 1;
            }
        }
        // @compileLog(args);
        break :blk .{ fmt, args };
    };

    return struct {
        pub const p_format = parse_format; // TODO: Remove
        pub const f_info = func_info;
        pub const p_args = parse_args; // TODO: Remove

        pub fn wrapped(self: [*c]Py.PyObject, args: [*c]Py.PyObject) callconv(.c) [*c]Py.PyObject {
            _ = self;

            const py_params_type, const params_format, _ = utils.ExpandTypes(func);
            const py_params: py_params_type = undefined;

            comptime var params_ptr_array: [py_params.len]type = undefined;
            inline for (py_params, 0..) |arg_type, i| {
                params_ptr_array[i] = *arg_type; // NOTE: I think this is a bit redundant
            }

            var params_ptr_tuple: @Tuple(&params_ptr_array) = undefined;
            inline for (0..p_args.len) |i| {
                params_ptr_tuple[i] = &params_ptr_array[i];
            }

            const parse_params_response = @call(
                .auto,
                Py.PyArg_ParseTuple,
                .{ args, @as([*c]const u8, &params_format) } ++ params_ptr_tuple,
            );
            if (parse_params_response == 0) {
                return null;
            }

            const zig_params_type = std.meta.ArgsTuple(func);
            const zig_params: zig_params_type = undefined;

            // Convert py_params -> zig_params

            var param_idx = 0;
            for (zig_params) |_| {
                if (py_params_type[param_idx] == zig_params_type[param_idx]) {
                    zig_params[param_idx] = py_params[param_idx];
                    param_idx += 1;
                    continue;
                }

                if (py_params_type
            }

            const response = @call(.auto, func, zig_params);
            if (f_info.return_type == null) {
                @compileError("generic functions are not supported");
            }

            const return_type, _, const build_format = utils.ExpandTypes(@Tuple(&.{f_info.return_type.?})); // NOTE: I think this will be hairy, for complex types
            const return_value: return_type = undefined;

            return Py.Py_BuildValue(@as([*c]const u8, &build_format), parse_params_response);

            // // Build a tuple for the function args to be unpacked into
            // var func_args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
            //
            // // Build a tuple for holding types?
            // comptime var ptr_tuple: [f_info.param_types.len]type = undefined;
            // inline for (f_info.param_types, 0..) |param_type, i| {
            //     ptr_tuple[i] = *param_type.?;
            // }
            //
            // var func_args_ptrs: @Tuple(&ptr_tuple) = undefined;
            // inline for (0..f_info.param_types.len) |i| {
            //     func_args_ptrs[i] = &func_args[i];
            // }
            //
            // comptime var incoming_idx = 0;
            // comptime var func_params_idx = 0;
            // inline while (incoming_idx < incoming_param_args.len) {
            //     if (@TypeOf(incoming_param_args[incoming_idx]) == @TypeOf(func_args[func_params_idx])) {
            //         func_args_ptrs[func_params_idx].* = incoming_param_args[incoming_idx];
            //         incoming_idx += 1;
            //         func_params_idx += 1;
            //     } else {
            //         if (@TypeOf(incoming_param_args[incoming_idx]) == u8 and @TypeOf(incoming_param_args[incoming_idx + 1]) == isize) {
            //             const ptr: *u8 = &incoming_param_args[incoming_idx];
            //             const many_ptr: [*]u8 = @ptrCast(ptr); // QUES: Is this correct?
            //             const length = incoming_param_args[incoming_idx + 1];
            //             if (length < 0) {
            //                 @panic("invalid length");
            //             }
            //
            //             const slice: []u8 = many_ptr[0..@intCast(length)];
            //             func_args_ptrs[func_params_idx].* = slice;
            //             incoming_idx += 2;
            //             func_params_idx += 1;
            //         } else unreachable;
            //     }
            // }
            // // @compileLog(func_args);
            //
            // const response = @call(.auto, func, func_args);
            // if (f_info.return_type == null) {
            //     @compileError("generic functions are not supported");
            // }
            // std.debug.print("response: {any}\n", .{parse_params_response});
            //
            // // @compileLog("response");
            // // @compileLog(response);
            //
            // const response_format = utils.getPythonParseFormat(f_info.return_type.?);
            //
            // const response_type = @typeInfo(f_info.return_type.?);
            // switch (response_type) {
            //     .pointer => |ptr| {
            //         std.debug.print("response: {s}\n", .{parse_params_response});
            //         if (ptr.size != .slice) unreachable;
            //         if (ptr.child != u8) unreachable;
            //         const p: [*]const u8 = @ptrCast(&parse_params_response[0]);
            //         const length: isize = @intCast(parse_params_response.len);
            //         return Py.Py_BuildValue(@as([*c]const u8, &response_format.build.format[0]), p, length);
            //     },
            //     else => {},
            // }
            // return Py.Py_BuildValue(@as([*c]const u8, &response_format.build.format[0]), parse_params_response);
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

const TypeMap = struct {
    zig_side: type,
    py_side: []const type,
};
