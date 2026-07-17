//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const http = std.http;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Io = std.Io;
const net = std.Io.net;
pub const Request = @import("request.zig");
pub const Response = @import("response.zig");
pub const Param = struct {};
const Method = enum { GET, POST, PUT, DELETE };
const tree = struct {
    handler: std.EnumMap(Method, ?*const fn (*Request, *Response) void),
    child: std.StringHashMap(*tree),
    special_tree: ?*tree,
    special_name: ?[]const u8,
    pub fn init(allocator: std.mem.Allocator) tree {
        const map = std.EnumMap(Method, ?*const fn (*Request, *Response) void){};

        return tree{ .handler = map, .child = std.StringHashMap(*tree).init(allocator), .special_tree = null, .special_name = null };
    }
};
pub const App = struct {
    io: Io,
    port: u16 = 8000,
    allocator: Allocator,
    ip: ?[]u8 = null,
    server: ?std.Io.net.Server = null,
    root: tree,
    pub fn find(self: *App, path: []const u8, req: *Request) ?*tree {
        if (path.len == 0 or std.mem.eql(u8, path, "/")) {
            return &self.root;
        }

        var trimmed = std.mem.trim(u8, path, "/");
        const locQuery = std.mem.find(u8, trimmed, "?");
        var op_query: ?[]const u8 = null;
        if (locQuery) |x| {
            op_query = if (trimmed[x + 1 ..].len > 0) trimmed[x + 1 ..] else null;
            trimmed = trimmed[0..x];
            if (op_query) |query| {
                const trimmed_query = std.mem.trim(u8, query, "/");
                var query_segment = std.mem.splitScalar(u8, trimmed_query, '&');
                while (query_segment.next()) |each_query| {
                    const locEqual = std.mem.find(u8, each_query, "=");
                    if (locEqual) |x_query| {
                        req.queryMap.put(each_query[0..x_query], each_query[x_query + 1 ..]) catch {
                            std.debug.print("Fail to put query", .{});
                        };
                    } else {
                        // No data is found "/?hello&hi=1"
                        req.queryMap.put(each_query, "") catch {
                            std.debug.print("Fail to put query", .{});
                        };
                    }
                }
            }
        }
        var it = std.mem.splitScalar(u8, trimmed, '/');

        var node: ?*tree = &self.root;

        while (it.next()) |segment| {
            if (segment.len == 0) continue;

            const n = node orelse return null;

            if (n.child.get(segment)) |next| {
                node = next;
                continue;
            }

            if (n.special_tree) |p| {
                if (p.special_name) |param_name| {
                    req.paramMap.put(param_name, segment) catch {
                        std.debug.print("Fail to find params", .{});
                    };
                }
                node = p;
                continue;
            }

            return null;
        }

        return node;
    }
    pub fn init(allocator: Allocator, io: Io) App {
        return .{ .allocator = allocator, .io = io, .root = .init(allocator) };
    }
    fn registerRoute(
        self: *App,
        method: Method,
        path: []const u8,
        handler: fn (*Request, *Response) void,
    ) !void {
        if (path.len == 0 or std.mem.eql(u8, path, "/")) {
            self.root.handler.put(method, handler);
            return;
        }

        const trimmed = std.mem.trim(u8, path, "/");

        var path_it = std.mem.splitScalar(u8, trimmed, '/');

        var node: *tree = &self.root;

        while (path_it.next()) |segment| {
            if (segment.len == 0) continue;

            if (node.child.get(segment)) |child| {
                node = child;
            } else {
                const new_node = try self.allocator.create(tree);
                new_node.* = tree.init(self.allocator);
                if (segment[0] == ':') {
                    node.special_tree = new_node;
                    node.special_tree.?.special_name = segment[1..];
                    node = node.special_tree.?;
                } else {
                    try node.child.put(segment, new_node);
                    node = new_node;
                }
            }
        }

        node.handler.put(method, handler);
    }
    pub fn put(self: *App, path: []const u8, handler: fn (*Request, *Response) void) !void {
        return self.registerRoute(Method.PUT, path, handler);
    }

    pub fn post(self: *App, path: []const u8, handler: fn (*Request, *Response) void) !void {
        return self.registerRoute(Method.POST, path, handler);
    }

    pub fn delete(self: *App, path: []const u8, handler: fn (*Request, *Response) void) !void {
        return self.registerRoute(Method.DELETE, path, handler);
    }
    pub fn get(self: *App, path: []const u8, handler: fn (*Request, *Response) void) !void {
        return self.registerRoute(Method.GET, path, handler);
    }
    pub fn config(self: *App, ip: []const u8, port: u16) !void {
        self.port = port;
        var counter: u32 = 0;
        self.ip = try self.allocator.alloc(u8, ip.len);
        if (self.ip) |x| {
            while (counter < ip.len) : (counter = counter + 1) {
                x[counter] = ip[counter];
            }
        }
    }
    pub fn deinit(self: *App) void {
        self.allocator.free(self.ip.?);
    }
    pub fn run(self: *App) !void {
        const ip = self.ip orelse return error.NoIpConfigured;
        std.debug.print("Running on {s}:{d}\n", .{ ip, self.port });

        const address = try net.IpAddress.parse(ip, self.port);
        self.server = try address.listen(self.io, .{});
        defer self.server.?.deinit(self.io);
        while (true) {
            const conn = try self.server.?.accept(self.io);
            defer conn.close(self.io);
            {
                var reader_buf: [4096]u8 = undefined;
                var writer_buf: [4096]u8 = undefined;
                var reader = conn.reader(self.io, &reader_buf);
                var writer = conn.writer(self.io, &writer_buf);
                var server_http = std.http.Server.init(&reader.interface, &writer.interface);
                var req = try server_http.receiveHead();
                const method = req.head.method;
                const target = req.head.target;
                var response = Response.init(&req, self.allocator, self.io);
                var request = Request.init(&req, self.allocator, self.io);
                defer request.queryMap.deinit();
                defer request.paramMap.deinit();

                const node = find(self, target, &request);
                const n = node orelse {
                    try req.respond("", .{ .status = .not_found });
                    continue;
                };
                switch (method) {
                    .GET => {
                        const h = n.handler.get(.GET) orelse {
                            try req.respond("", .{ .status = .not_found });
                            continue;
                        };

                        h.?(&request, &response);
                    },
                    else => {},
                }
            }
        }
    }
};

pub fn express_zig(allocator: Allocator, io: Io) App {
    return App.init(allocator, io);
}
