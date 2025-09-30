const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const meta = std.meta;
const process = std.process;

const VERSION = "0.1.0";

const Command = enum {
    version,
    run,
    restart,
    kill,
    ipc,
    help,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args = try process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    const command_str = args.next() orelse {
        try printUsage();
        process.exit(1);
    };

    const command = meta.stringToEnum(Command, command_str) orelse .help;

    switch (command) {
        .version => try runVersion(),
        .run => try runShell(allocator, &args),
        .restart => try restartShell(allocator),
        .kill => try killShell(allocator),
        .ipc => try runIpc(allocator, &args),
        .help => try printUsage(),
    }
}

fn printUsage() !void {
    var buf: [4096]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\Dykwabi {s}
        \\Amaan Qureshi <contact@amaanq.com>
        \\
        \\Dykwabi provides an overview of your installed
        \\components and allows you to manage your setup.
        \\
        \\Usage: dykwabi [COMMAND]
        \\
        \\Commands:
        \\  version     Show version information
        \\  run         Launch quickshell with Dykwabi configuration
        \\              Options: -d, --daemon  Run in daemon mode
        \\  restart     Restart quickshell with Dykwabi configuration
        \\  kill        Kill running Dykwabi shell processes
        \\  ipc         Send IPC commands to running Dykwabi shell
        \\  help        Print this message
        \\
        \\Options:
        \\  -h, --help     Print help
        \\  -v, --version  Print version
        \\
    , .{VERSION});
    try stdout.flush();
}

fn runVersion() !void {
    var buf: [1024]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    try stdout.print("Dykwabi v{s}\n", .{VERSION});
    try stdout.flush();
}

fn runShell(allocator: mem.Allocator, args: *process.ArgIterator) !void {
    var daemon_mode = false;

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-d") or mem.eql(u8, arg, "--daemon")) {
            daemon_mode = true;
            break;
        }
    }

    if (daemon_mode) {
        try runShellDaemon(allocator);
    } else {
        try runShellInteractive();
    }
}

fn newProcess(allocator: mem.Allocator, cmd: []const []const u8, behavior: process.Child.StdIo) process.Child {
    var child = process.Child.init(cmd, allocator);
    child.stdin_behavior = behavior;
    child.stdout_behavior = behavior;
    child.stderr_behavior = behavior;
    return child;
}

fn runShellInteractive() !void {
    var child = newProcess(std.heap.page_allocator, &[_][]const u8{ "qs", "-c", "dykwabi" }, .Inherit);

    const term = try child.spawnAndWait();
    if (term != .Exited or term.Exited != 0) {
        std.log.err("Error starting quickshell", .{});
        process.exit(1);
    }
}

fn runShellDaemon(allocator: mem.Allocator) !void {
    var child = newProcess(allocator, &[_][]const u8{ "qs", "-c", "dykwabi" }, .Ignore);

    try child.spawn();
    var buf: [1024]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    try stdout.print("Dykwabi shell started as daemon (PID: {d})\n", .{child.id});
    try stdout.flush();
}

fn restartShell(allocator: mem.Allocator) !void {
    try killShell(allocator);
    try runShellDaemon(allocator);
}

fn killShell(allocator: mem.Allocator) !void {
    const patterns = [_][]const u8{
        "qs.*dykwabi",
        "qs.*BuckMaterialShell",
        "quickshell.*dykwabi",
        "quickshell.*BuckMaterialShell",
    };

    var found_any = false;
    var buf: [4096]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch @panic("flushing stdout failed");

    for (patterns) |pattern| {
        var child = process.Child.init(&[_][]const u8{ "pgrep", "-f", pattern }, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        try child.spawn();
        const output = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(output);

        _ = try child.wait();

        if (output.len > 0) {
            found_any = true;
            var iter = mem.splitScalar(u8, output, '\n');
            while (iter.next()) |pid_str| {
                if (pid_str.len == 0) continue;
                const pid = std.fmt.parseInt(i32, mem.trim(u8, pid_str, &std.ascii.whitespace), 10) catch continue;

                const pid_arg = try std.fmt.allocPrint(allocator, "{d}", .{pid});
                defer allocator.free(pid_arg);
                var kill_child = process.Child.init(&[_][]const u8{ "kill", pid_arg }, allocator);
                _ = kill_child.spawnAndWait() catch |err| {
                    try stdout.print("Error killing process {d}: {}\n", .{ pid, err });
                    try stdout.flush();
                    continue;
                };

                try stdout.print("Killed Dykwabi shell process with PID {d}\n", .{pid});
            }
        }
    }

    if (!found_any) {
        try stdout.writeAll("No running Dykwabi shell instances found.\n");
    }
}

fn runIpc(allocator: mem.Allocator, args: *process.ArgIterator) !void {
    const count = args.inner.count + 4;
    var ipc_args = try std.ArrayList([]const u8).initCapacity(allocator, count);
    defer ipc_args.deinit(allocator);

    ipc_args.appendAssumeCapacity("qs");
    ipc_args.appendAssumeCapacity("-c");
    ipc_args.appendAssumeCapacity("dykwabi");
    ipc_args.appendAssumeCapacity("ipc");

    var has_args = false;
    var first_arg: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (!has_args) {
            first_arg = arg;
        }
        has_args = true;
        ipc_args.appendAssumeCapacity(arg);
    }

    if (!has_args) {
        var buf: [1024]u8 = undefined;
        var stderr_writer = fs.File.stderr().writer(&buf);
        const stderr = &stderr_writer.interface;
        try stderr.writeAll("Error: IPC command requires arguments\n");
        try stderr.writeAll("Usage: dykwabi ipc <command> [args...]\n");
        try stderr.flush();
        process.exit(1);
    }

    // Insert "call" if first arg isn't "call"
    if (first_arg) |first| {
        if (!mem.eql(u8, first, "call")) {
            try ipc_args.insert(allocator, 4, "call");
        }
    }

    var child = newProcess(allocator, ipc_args.items, .Inherit);
    const term = try child.spawnAndWait();
    if (term != .Exited or term.Exited != 0) {
        std.log.err("Error running IPC command", .{});
        process.exit(1);
    }
}
