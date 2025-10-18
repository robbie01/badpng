//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const png = @cImport({
    @cDefine("PNG_SETJMP_NOT_SUPPORTED", {});
    @cInclude("png.h");
});
