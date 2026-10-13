const std = @import("std");
const Py = @import("python.zig");

var methods = [_]Py.PyMethodDef{};

fn wrapper(func: anytype) Py.PyCFunction {
    switch (@typeInfo(func)) {
        .@"fn" => |f| {},
        else => unreachable,
    }
}
