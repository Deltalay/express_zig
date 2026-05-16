const std = @import("std");
const express_zig = @import("express_zig");
const Request = express_zig.Request;
const Response = express_zig.Response;
pub fn index(
    req: *Request,
    res: *Response,
) void {
    _ = req;

    res.send("hello");
}
pub fn app_route(
    req: *Request,
    res: *Response,
) void {
    _ = req;

    res.send("app");
}
pub fn get_app_route(
    req: *Request,
    res: *Response,
) void {
    const id: []const u8 = req.params.get("id") orelse "unknwon";
    const hello: []const u8 = req.params.get("hello") orelse "unknwon";

    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "app {s} {s}", .{ id, hello }) catch "app error";

    res.send(msg);
}
pub fn stff_app_route(
    req: *Request,
    res: *Response,
) void {
    _ = req;

    res.send("appstff");
}
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var app = express_zig.express_zig(arena, io);
    try app.config("0.0.0.0", 8080);
    try app.get("/", index);
    try app.post("/app", app_route);
    try app.get("/app/stff", stff_app_route);
    try app.get("/app/stff/sa", stff_app_route);

    try app.get("/app/:id/:hello", get_app_route);

    try app.run();
}
