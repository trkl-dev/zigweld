const std = @import("std");

// Take in a set of expanded types, and 
pub fn CompressTypes(comptime T: type) {

}

/// Take in some number of types, and return a tuple type that represents the 'python friendly' version
/// Similar to std.meta.ArgsTuple
pub fn ExpandTypes(comptime T: type) struct { type, []const u8, []const u8 } {
    const t_info = @typeInfo(T);
    const tuple_type: type = switch (t_info) {
        .@"fn" => blk: {
            break :blk std.meta.ArgsTuple(T);
        },
        .@"struct" => |S| blk: {
            if (!S.is_tuple) @compileError("only functions and tuples supported");
            break :blk @Tuple(S.field_types);
        },
        else => @compileError("only functions and tuples supported"),
    };

    const tuple_type_info = @typeInfo(tuple_type);
    switch (tuple_type_info) {
        .@"struct" => |S| {
            if (!S.is_tuple) @compileError("only functions and tuples supported");

            var num_fields = 0;
            for (S.field_types) |ft| {
                const format = getPythonParseFormat(ft);
                num_fields += format.args.len;
            }

            comptime var field_list: [num_fields]type = undefined;
            var field_idx = 0;

            comptime var parse_format: []const u8 = "";
            comptime var build_format: []const u8 = "";

            for (S.field_types) |ft| {
                const format = getPythonParseFormat(ft);
                for (format.args) |arg| {
                    field_list[field_idx] = arg;
                    field_idx += 1;
                }

                parse_format = parse_format ++ format.parse.format;
                build_format = build_format ++ format.build.format;
            }

            return .{ @Tuple(&field_list), parse_format, build_format };
        },
        else => @compileError("unexpected type"),
    }
}

test ExpandTypes {
    // Tuple types
    const py_types_t1, const parse_fmt_t1, const build_fmt_t1 = ExpandTypes(@Tuple(&.{i16}));

    try std.testing.expectEqual(@Tuple(&.{i16}), py_types_t1);
    try std.testing.expectEqualStrings("h", parse_fmt_t1);
    try std.testing.expectEqualStrings("h", build_fmt_t1);

    const py_types_t2, const parse_fmt_t2, const build_fmt_t2 = ExpandTypes(@Tuple(&.{ i32, u16 }));

    try std.testing.expectEqual(@Tuple(&.{ i32, u16 }), py_types_t2);
    try std.testing.expectEqualStrings("iH", parse_fmt_t2);
    try std.testing.expectEqualStrings("iH", build_fmt_t2);

    const py_types_t3, const parse_fmt_t3, const build_fmt_t3 = ExpandTypes(@Tuple(&.{ i32, []u8, u16 }));

    try std.testing.expectEqual(@Tuple(&.{ i32, *u8, isize, u16 }), py_types_t3);
    try std.testing.expectEqualStrings("is#H", parse_fmt_t3);
    try std.testing.expectEqualStrings("is#H", build_fmt_t3);

    // Function types
    const py_types_f1, const parse_fmt_f1, const build_fmt_f1 = ExpandTypes(fn (i32, u16) void);

    try std.testing.expectEqual(@Tuple(&.{ i32, u16 }), py_types_f1);
    try std.testing.expectEqualStrings("iH", parse_fmt_f1);
    try std.testing.expectEqualStrings("iH", build_fmt_f1);

    const py_types_f2, const parse_fmt_f2, const build_fmt_f2 = ExpandTypes(fn (i32, u16, []u8, []u8) void);

    try std.testing.expectEqual(@Tuple(&.{ i32, u16, *u8, isize, *u8, isize }), py_types_f2);
    try std.testing.expectEqualStrings("iHs#s#", parse_fmt_f2);
    try std.testing.expectEqualStrings("iHs#s#", build_fmt_f2);
}

// https://docs.python.org/3/c-api/arg.html
pub fn getPythonParseFormat(comptime T: type) PythonFormat {
    const format: PythonFormat = switch (@typeInfo(T)) {
        .optional => @compileError("optional types are not supported"),
        .pointer => |ptr| {
            if (ptr.sentinel() != null) {
                @compileError("sentinel terminated slices are not currently supported");
            }
            return switch (ptr.child) {
                u8 => .{
                    .args = &.{ *u8, isize },
                    .parse = .{ .format = "s#", .type = c_short },
                    .build = .{ .format = "s#", .type = c_short },
                    .python = "str",
                },
                else => @compileError("pointer to " ++ @typeName(ptr.child) ++ " not supported"),
            };
        },
        // NOTE: parse and build formats are not always the same, although often they are. Hence the distinct entries.
        else => switch (T) {
            i16 => .{
                .args = &.{i16},
                .parse = .{ .format = "h", .type = c_short },
                .build = .{ .format = "h", .type = c_short },
                .python = "int",
            },
            i32 => .{
                .args = &.{i32},
                .parse = .{ .format = "i", .type = c_int },
                .build = .{ .format = "i", .type = c_int },
                .python = "int",
            },
            i64 => .{
                .args = &.{i64},
                .parse = .{ .format = "L", .type = c_longlong },
                .build = .{ .format = "L", .type = c_longlong },
                .python = "int",
            },
            u16 => .{
                .args = &.{u16},
                .parse = .{ .format = "H", .type = c_ushort },
                .build = .{ .format = "H", .type = c_ushort },
                .python = "int",
            },
            u32 => .{
                .args = &.{u32},
                .parse = .{ .format = "I", .type = c_uint },
                .build = .{ .format = "I", .type = c_uint },
                .python = "int",
            },
            u64 => .{
                .args = &.{u64},
                .parse = .{ .format = "K", .type = c_ulonglong },
                .build = .{ .format = "K", .type = c_ulonglong },
                .python = "int",
            },
            // Zig floats are perfectly compatible with C floats, so we don't need a c-type for checking
            f32 => .{
                .args = &.{f32},
                .parse = .{ .format = "f", .type = f32 },
                .build = .{ .format = "f", .type = f32 },
                .python = "float",
            },
            f64 => .{
                .args = &.{f64},
                .parse = .{ .format = "d", .type = f64 },
                .build = .{ .format = "d", .type = f64 },
                .python = "float",
            },
            else => @compileError(@typeName(T) ++ " not supported"),
        },
    };
    comptime {
        assert(@sizeOf(T) == @sizeOf(format.parse.type));
        assert(@sizeOf(T) == @sizeOf(format.build.type));
    }
    return format;
}

const FormatCType = struct {
    format: []const u8,
    type: type,
};

const PythonFormat = struct {
    args: []const type,
    parse: FormatCType,
    build: FormatCType,
    python: []const u8,
};

pub fn assert(comptime ok: bool) void {
    if (!ok) {
        @compileError("assertion failed");
    }
}
