pub const png = @cImport({
    @cDefine("PNG_SETJMP_NOT_SUPPORTED", {});
    @cInclude("png.h");
});
