const std = @import("std");
const Io = std.Io;
const http = std.http;

io: Io,
req: *http.Server.Request,
paramMap: std.StringHashMap([]const u8),
queryMap: std.StringHashMap([]const u8),
allocator: std.mem.Allocator,
const Self = @This();
pub fn init(req: *http.Server.Request, allocator: std.mem.Allocator, io: Io) Self {
    return Self{ .req = req, .paramMap = std.StringHashMap([]const u8).init(allocator), .queryMap = std.StringHashMap([]const u8).init(allocator), .io = io, .allocator = allocator };
}
pub fn param(self: *Self, key: []const u8) ?[]const u8 {
    return self.paramMap.get(key);
}
pub fn query(self: *Self, key: []const u8) ?[]const u8 {
    return self.queryMap.get(key);
}
