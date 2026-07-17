const std = @import("std");
const Io = std.Io;
const http = std.http;

io: Io,
req: *http.Server.Request,
status_code: http.Status,
headers: std.ArrayList(http.Header),
allocator: std.mem.Allocator,
const Self = @This();
const CookieOption = struct {
    domain: []const u8 = "",
    expires: []const u8 = "",
    path: []const u8 = "",
    max_age: []const u8 = "",
    secure: bool = false,
    http_only: bool = false,
    // Handle with @tagName
    same_site: enum { Strict, Lax, None } = .None,
    partitioned: bool = false,
};
pub fn send(self: *Self, data: []const u8) void {
    self.req.respond(data, .{ .keep_alive = false, .extra_headers = self.headers.items }) catch return;
    for (self.headers.items) |h| {
        self.allocator.free(h.value);
    }
    defer self.headers.deinit(self.allocator);
}
pub fn status(self: *Self, status_code: http.Status) void {
    self.status_code = status_code;
}
pub fn set_header(self: *Self, name: []const u8, value: []const u8) void {
    const owned = self.allocator.dupe(u8, value) catch return;

    const header: http.Header = .{ .name = name, .value = owned };

    self.headers.append(self.allocator, header) catch {
        std.debug.print("Cannot set header {s} = {s}", .{ name, owned });
    };
}
pub fn set_cookie(self: *Self, name: []const u8, value: []const u8, option: CookieOption) void {
    var val: []u8 = std.mem.concat(self.allocator, u8, &[_][]const u8{ name, "=", value, ";" }) catch {
        std.debug.print("Cannot Build Cookie", .{});
        return;
    };
    if (std.mem.trim(u8, option.domain, " ").len > 0) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "Domain=", std.mem.trim(u8, option.domain, " "), ";" }) catch {
            std.debug.print("Cannot Build Cookie, domain", .{});
            return;
        };
    }
    if (std.mem.trim(u8, option.path, " ").len > 0) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "Path=", std.mem.trim(u8, option.path, " "), ";" }) catch {
            std.debug.print("Cannot Build Cookie, path", .{});
            return;
        };
    }
    if (std.mem.trim(u8, option.expires, " ").len > 0) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "Expires=", std.mem.trim(u8, option.expires, " "), ";" }) catch {
            std.debug.print("Cannot Build Cookie, expires", .{});
            return;
        };
    }
    if (std.mem.trim(u8, option.max_age, " ").len > 0) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "Max-Age=", std.mem.trim(u8, option.max_age, " "), ";" }) catch {
            std.debug.print("Cannot Build Cookie, max-age", .{});
            return;
        };
    }
    if (option.partitioned) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "Partitioned", ";" }) catch {
            std.debug.print("Cannot Build Cookie, partitioned", .{});
            return;
        };
    }
    if (option.secure) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "Secure", ";" }) catch {
            std.debug.print("Cannot Build Cookie, secure", .{});
            return;
        };
    }
    if (option.http_only) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "HttpOnly", ";" }) catch {
            std.debug.print("Cannot Build Cookie, http-only", .{});
            return;
        };
    }

    if (std.mem.trim(u8, @tagName(option.same_site), " ").len > 0) {
        val = std.mem.concat(self.allocator, u8, &[_][]const u8{ val, "SameSite=", std.mem.trim(u8, @tagName(option.same_site), " "), ";" }) catch {
            std.debug.print("Cannot Build Cookie, same-site", .{});
            return;
        };
    }
    self.set_header("Set-Cookie", val);
    // We able to do this since the val will be dupe in set_header function.
    // Look set_header.
    defer self.allocator.free(val);
}
pub fn init(req: *http.Server.Request, allocator: std.mem.Allocator, io: Io) Self {
    return Self{ .req = req, .status_code = .ok, .io = io, .allocator = allocator, .headers = undefined };
}
