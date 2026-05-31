const std = @import("std");
const express_zig = @import("express_zig");
const Request = express_zig.Request;
const Response = express_zig.Response;
pub fn index(
    req: *Request,
    res: *Response,
) void {
    _ = req;
    res.set_header("Content-Type", "application/json");
    res.set_cookie("token", "HelloWorld", .{});
    std.debug.print("demo {s}\n", .{res.headers.getLast().value});

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
    const id: []const u8 = req.param("a") orelse "unknwon";

    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "app a {s}", .{id}) catch "app error";

    res.send(msg);
}
pub fn get_app_route2(
    req: *Request,
    res: *Response,
) void {
    const hello: []const u8 = req.param("b") orelse "unknwon";
    const a: []const u8 = req.query("a") orelse "unknown";
    const daa: []const u8 = req.query("data") orelse "unknown";
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "appstff b {s} {s} {s}", .{ hello, a, daa }) catch "app error";

    res.send(msg);
}
pub fn get_app_route3(
    req: *Request,
    res: *Response,
) void {
    _ = req;
    res.send("app/x/stff");
}
pub fn stff_app_route(
    req: *Request,
    res: *Response,
) void {
    _ = req;

    res.send("appstff");
}
pub fn user_profile(req: *Request, res: *Response) void {
    const id = req.param("id") orelse return res.send("missing id");

    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{{\"user\": \"{s}\", \"status\": \"ok\"}}", .{id}) catch "error";

    res.set_header("Content-Type", "application/json");
    res.send(msg);
}
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var app = express_zig.express_zig(arena, io);
    try app.config("0.0.0.0", 8080);
    try app.get("/", index);
    try app.get("/user/:id", user_profile);

    try app.get("/app", app_route);
    try app.get("/app/stff", stff_app_route);
    try app.get("/app/:a/stff", get_app_route);
    try app.get("/app/stff/:b", get_app_route2);
    try app.get("/app/x/stff", get_app_route3);

    try app.run();
}
