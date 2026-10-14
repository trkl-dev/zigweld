const std = @import("std");
const core = @import("fib");
const Py = @import("python.zig");

fn add(self: [*c]Py.PyObject, args: [*c]Py.PyObject) callconv(.c) [*c]Py.PyObject {
    _ = self;
    var foo: i32 = undefined;
    var bar: i32 = undefined;
    if (!(Py.PyArg_ParseTuple(
        args,
        "ii",
        &foo,
        &bar,
    ) != 0)) return null;
    const response = core.add(
        foo,
        bar,
    );
    return Py.Py_BuildValue("i", @as(i32, response));
}
fn sub(self: [*c]Py.PyObject, args: [*c]Py.PyObject) callconv(.c) [*c]Py.PyObject {
    _ = self;
    var foo: i32 = undefined;
    var bar: i32 = undefined;
    if (!(Py.PyArg_ParseTuple(
        args,
        "ii",
        &foo,
        &bar,
    ) != 0)) return null;
    const response = core.sub(
        foo,
        bar,
    );
    return Py.Py_BuildValue("i", @as(i32, response));
}
fn no_return(self: [*c]Py.PyObject, args: [*c]Py.PyObject) callconv(.c) [*c]Py.PyObject {
    _ = self;
    var a: i32 = undefined;
    if (!(Py.PyArg_ParseTuple(args, "i", &a) != 0)) return null;
    const response = core.no_return(a);
    return Py.Py_BuildValue("d", @as(void, response));
}
var fibMethods = [_]Py.PyMethodDef{
    Py.PyMethodDef{
        .ml_name = "add",
        .ml_meth = add,
        .ml_flags = Py.METH_VARARGS,
        .ml_doc = "Function to add two integers together",
    },
    Py.PyMethodDef{
        .ml_name = "sub",
        .ml_meth = sub,
        .ml_flags = Py.METH_VARARGS,
        .ml_doc = "Function to subtract two integers",
    },
    Py.PyMethodDef{
        .ml_name = "no_return",
        .ml_meth = no_return,
        .ml_flags = Py.METH_VARARGS,
        .ml_doc = "l>",
    },
    Py.PyMethodDef{
        .ml_name = null,
        .ml_meth = null,
        .ml_flags = 0,
        .ml_doc = null,
    },
};
var fibModule = Py.PyModuleDef{
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
    .m_methods = &fibMethods,
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};
pub export fn PyInit_fib() [*]Py.PyObject {
    return Py.PyModule_Create(&fibModule);
}
